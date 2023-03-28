import CoreLocation
import CoreMotion
import Serde

let Interval = 1.0 / 2.0

class TrackViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var tracking = false
    @Published var info: TrackData?
    
    private let motion = CMMotionManager()
    private let location = CLLocationManager()
    private var timer: Timer?

    override init() {
        super.init()

        location.delegate = self
    }

    func startTrack() {
        do {
            try StorageViewModel.startTrack()
        } catch {
            fatalError("Failed to start track \(error)")
        }

        if self.motion.isAccelerometerAvailable {
            self.motion.accelerometerUpdateInterval = Interval
            self.motion.startAccelerometerUpdates()
        }

        if self.motion.isGyroAvailable {
            self.motion.gyroUpdateInterval = Interval
            self.motion.startGyroUpdates()
        }

        self.startLocation()

        self.timer = Timer(timeInterval: Interval, repeats: true) { timer in
            var track_data = TrackData(
                accelerometer: Vec3(x: 0.0, y: 0.0, z: 0.0),
                gyro: Vec3(x: 0.0, y: 0.0, z: 0.0),
                speed: 0.0
            )

            if let data = self.motion.accelerometerData {
                track_data.accelerometer = Vec3(x: data.acceleration.x, y: data.acceleration.y, z: data.acceleration.z)
            }

            if let data = self.motion.gyroData {
                track_data.gyro = Vec3(x: data.rotationRate.x, y: data.rotationRate.y, z: data.rotationRate.z)
            }

            if let data = self.location.location {
                track_data.speed = data.speed
            }

            self.info = track_data

            do {
                try StorageViewModel.storeTrackValue(track_data)
            } catch {
                fatalError("Failed to store track value \(error)")
            }
        }

        RunLoop.current.add(self.timer!, forMode: .default)

        self.tracking = true
    }

    func stopTrack() {
        if let timer = self.timer {
            timer.invalidate()
        }

        self.motion.stopAccelerometerUpdates()
        self.motion.stopGyroUpdates()
        self.location.stopUpdatingLocation();
        self.tracking = false
        self.timer = nil
        self.info = nil

        do {
            try StorageViewModel.stopTrack()
        } catch {
            fatalError("Failed to stop track \(error)")
        }
    }

    func startLocation() {
        self.location.desiredAccuracy = kCLLocationAccuracyBest
        
        switch self.location.authorizationStatus {
        case .notDetermined:
            self.location.requestWhenInUseAuthorization()
            break
        case .authorizedWhenInUse, .authorizedAlways:
            self.location.startUpdatingLocation()
            break
        default:
            print("Unhandled location authorizationStatus \(self.location.authorizationStatus)")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if self.tracking {
            self.startLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            print("\(location.coordinate)")
        }
    }

    static func tracks() throws -> [String] {
        let ptr = reax_storage_tracks { bytes, bytesLen in
            let array = Array(UnsafeBufferPointer(start: bytes, count: Int(bytesLen)))

            return UnsafeMutableRawPointer(Unmanaged.passRetained(BincodeDeserializer(input: array)).toOpaque())
        }

        let deserializer = Unmanaged<AnyObject>.fromOpaque(ptr!).takeRetainedValue() as! BincodeDeserializer

        let index = try deserializer.deserialize_variant_index()

        switch index {
        case 0: return try deserializeList(deserializer, deserialize: { try $0.deserialize_str() })
        case 1: throw try StorageError.deserialize(deserializer)
        default: throw DeserializationError.invalidInput(issue: "Unknown variant index for StorageError")
        }
    }

    static func track(timestamp: Int64) throws -> Track {
        let ptr = reax_storage_track(timestamp) { bytes, bytesLen in
            let array = Array(UnsafeBufferPointer(start: bytes, count: Int(bytesLen)))

            return UnsafeMutableRawPointer(Unmanaged.passRetained(BincodeDeserializer(input: array)).toOpaque())
        }

        let deserializer = Unmanaged<AnyObject>.fromOpaque(ptr!).takeRetainedValue() as! BincodeDeserializer

        let index = try deserializer.deserialize_variant_index()

        switch index {
        case 0: return try Track.deserialize(deserializer)
        case 1: throw try StorageError.deserialize(deserializer)
        default: throw DeserializationError.invalidInput(issue: "Unknown variant index for StorageError")
        }
    }
}
