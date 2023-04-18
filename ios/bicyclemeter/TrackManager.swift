import CoreLocation

enum TrackValue {
    case RPM(Float32)
    case Slope(Float32)
    case Speed(Float32)
}

class TrackManager: ObservableObject {
    @Published var tracking: Bool = false

    private let bluetooth: BluetoothManager

    private var location: CLLocationManager?
    private var continuations: [Int:AsyncStream<TrackValue>.Continuation] = [:]
    private var observerTask: Task<(), Never>?
    private var timer: Timer?
    private var accel: Vec3<Double>?
    private var gyro: Vec3<Double>?

    init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
    }

    func startOrContinue() -> AsyncStream<TrackValue> {

        if !self.tracking {
            do {
                try StorageViewModel.startTrack()
            } catch {
                fatalError("Failed to start track \(error)")
            }

            self.location = CLLocationManager()

            self.timer = Timer(timeInterval: 0.5, repeats: true) { _ in
                do {
                    try StorageViewModel.storeTrackValue(
                        TrackData(
                            accelerometer: self.accel ?? Vec3(x: 0.0, y: 0.0, z: 0.0),
                            gyro: self.gyro ?? Vec3(x: 0.0, y: 0.0, z: 0.0),
                            speed: 0.0
                        )
                    )

                    self.accel = nil
                    self.gyro = nil
                } catch {
                    fatalError("Failed to store track value \(error)")
                }
            }

            self.observerTask = Task {
                for await (kind, data) in self.bluetooth.subscribe() {
                    if data.count != 13 {
                        print("Received data does not have enough bytes, \(data.count)")
                        continue
                    }
                    switch kind {
                    case .Bicycle:
                        // We only want the accel values when the kind is .Bicycle
                        // to obtain slope
                        self.accel = Vec3(
                            x: Double(Int16(data[0]) << 8 + Int16(data[1])),
                            y: Double(Int16(data[2]) << 8 + Int16(data[3])),
                            z: Double(Int16(data[4]) << 8 + Int16(data[5]))
                        )
                    case .Foot:
                        // We only want the gyro values when the kind is .Foot
                        // to obtain RPM
                        self.gyro = Vec3(
                            x: Double(Int16(data[6]) << 8 + Int16(data[7])),
                            y: Double(Int16(data[8]) << 8 + Int16(data[9])),
                            z: Double(Int16(data[10]) << 8 + Int16(data[11]))
                        )
                    }
                }
            }
        }

        self.tracking = true

        return AsyncStream<TrackValue> { continuation in
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

        self.continuations = [:]
        self.location = nil
        self.observerTask = nil
        self.timer = nil

        do {
            try StorageViewModel.stopTrack()
        } catch {
            fatalError("Failed to stop track \(error)")
        }

        self.tracking = false
    }
}
