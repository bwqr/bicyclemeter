import CoreLocation

let FORWARD = Vec3(x: 0.0, y: -1.0, z: 0.0)
let DOWN = Vec3(x: 0.0, y: 0.0, z: 1.0)
let TILT = FORWARD.cross(vec: DOWN)
let G = 1.0

struct OptionalTrackPoint {
    public var rpm: Double? = nil
    public var slope: Double? = nil
    public var speed: Double? = nil

    func trackPoint() -> TrackPoint {
        TrackPoint(
            rpm: self.rpm ?? 0.0,
            slope: self.slope ?? 0.0,
            speed: self.speed ?? 0.0
        )
    }
}

class TrackPointHistory {
    private static let MAX_HISTORY = 60
    static let MAX_WINDOW = 1

    var points: [TrackPoint] = []
    private var windowedPoints: [TrackPoint] = []

    func update(_ optionalTrackPoint: OptionalTrackPoint) -> Bool {
        self.windowedPoints.append(TrackPoint(
            rpm: optionalTrackPoint.rpm ?? self.windowedPoints.last?.rpm ?? 0.0,
            slope: optionalTrackPoint.slope ?? self.windowedPoints.last?.slope ?? 0.0,
            speed: optionalTrackPoint.speed ?? self.windowedPoints.last?.speed ?? 0.0
        ))

        if self.windowedPoints.count < Self.MAX_WINDOW {
            return false
        }

        if self.points.count >= Self.MAX_HISTORY {
            self.points.removeFirst()
        }

        var overallPoint = self.windowedPoints.reduce(TrackPoint(rpm: 0.0, slope: 0.0, speed: 0.0)) { overall, current in
            TrackPoint(rpm: overall.rpm + current.rpm, slope: overall.slope + current.slope, speed: overall.speed + current.speed)
        }
        overallPoint.rpm /= Double(self.windowedPoints.count)
        overallPoint.slope /= Double(self.windowedPoints.count)
        overallPoint.speed /= Double(self.windowedPoints.count)
        self.points.append(overallPoint)

        self.windowedPoints = []

        return true
    }
}

class TrackManager: NSObject, ObservableObject {
    @Published var tracking: Bool = false
    var history: [TrackPoint] {
        get {
            self.trackPointHistory.points
        }
    }

    private let bluetooth: BluetoothManager

    private var location: CLLocationManager?
    private var continuations: [Int:AsyncStream<OptionalTrackPoint>.Continuation] = [:]
    private var observerTask: Task<(), Never>?
    private var timer: Timer?

    private var optionalTrackPoint = OptionalTrackPoint()
    private var trackPointHistory = TrackPointHistory()

    init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
    }

    func startOrContinue() -> AsyncStream<OptionalTrackPoint> {

        if !self.tracking {
            self.tracking = true
            self.trackPointHistory = TrackPointHistory()

            do {
                try TrackViewModel.startTrack()
            } catch {
                fatalError("Failed to start track \(error)")
            }

            self.startLocation()

            self.timer = Timer(timeInterval: 0.5, repeats: true) { _ in
                do {
                    try TrackViewModel.storeTrackPoint(self.optionalTrackPoint.trackPoint())

                    if self.trackPointHistory.update(self.optionalTrackPoint) {
                        self.objectWillChange.send()
                    }

                    for cont in self.continuations.values {
                        cont.yield(self.optionalTrackPoint)
                    }

                    self.optionalTrackPoint = OptionalTrackPoint()
                } catch {
                    fatalError("Failed to store track value \(error)")
                }
            }
            RunLoop.current.add(self.timer!, forMode: .default)

            self.observerTask = Task {
                for await (kind, data) in self.bluetooth.subscribe() {
                    if data.count != 8 {
                        print("Received data does not have enough bytes, \(data.count)")
                        continue
                    }
                    switch kind {
                    case .Bicycle:
                        // We only want the accel values when the kind is .Bicycle
                        // to obtain slope
                        let accel = Vec3(
                            x: Double(Int16(data[0]) << 8 + Int16(data[1])) / 1000.0,
                            y: Double(Int16(data[2]) << 8 + Int16(data[3])) / 1000.0,
                            z: Double(Int16(data[4]) << 8 + Int16(data[5])) / 1000.0
                        )

                        let accel_tilt = accel.project(vec: TILT)
                        let accel_forward = accel.project(vec: FORWARD)
                        let accel_down = accel.project(vec: DOWN)

                        let gf_len = abs(G - accel_tilt.len() - accel_down.len())
                        // assume that vec and gf always have the same direction
                        let gf = accel_forward.norm().scale(sc: gf_len)
                        let slope = atan2(gf.dot(vec: FORWARD.norm()), accel_down.dot(vec: DOWN.norm())) * 180.0 / Double.pi
                        self.optionalTrackPoint.slope = min(max(slope, -90.0), 90.0)
                    case .Foot:
                        // We only want the gyro values when the kind is .Foot
                        // to obtain RPM
                        let angVel = Double(UInt16(data[6]) << 8 + UInt16(data[7])) / 100.0

                        self.optionalTrackPoint.rpm = angVel * 60.0 / 360.0
                    }
                }
            }
        }

        return AsyncStream<OptionalTrackPoint> { continuation in
            var contKey = 0
            while self.continuations.index(forKey: contKey) != nil {
                contKey += 1
            }
            let key = contKey

            continuation.onTermination = { _ in
                self.continuations.removeValue(forKey: key)
            }

            self.continuations[key] = continuation
        }
    }

    func stop() {
        for cont in self.continuations.values {
            cont.finish()
        }
        self.observerTask?.cancel()
        self.timer?.invalidate()
        self.location?.stopUpdatingLocation();

        self.continuations = [:]
        self.location = nil
        self.observerTask = nil
        self.timer = nil

        do {
            try TrackViewModel.stopTrack()
        } catch {
            fatalError("Failed to stop track \(error)")
        }

        self.tracking = false
    }

    func startLocation() {
        let location = self.location ?? CLLocationManager()
        location.delegate = self
        self.location = location

        location.desiredAccuracy = kCLLocationAccuracyBest

        switch location.authorizationStatus {
        case .notDetermined:
            location.requestWhenInUseAuthorization()
            break
        case .authorizedWhenInUse, .authorizedAlways:
            location.startUpdatingLocation()
            break
        default:
            print("Unhandled location authorizationStatus \(location.authorizationStatus)")
        }
     }
}

extension TrackManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if self.tracking {
            self.startLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let speed = locations.last?.speed, speed != -1.0 {
            self.optionalTrackPoint.speed = speed
        }
    }
}
