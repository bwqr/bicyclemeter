import CoreMotion
import Serde

let Interval = 1.0 / 2.0

class TrackViewModel: ObservableObject {
    @Published var tracking = false
    
    private let motion = CMMotionManager()
    private var timer: Timer?

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

        self.timer = Timer(timeInterval: Interval, repeats: true) { timer in
            var (acc_x, acc_y, acc_z) = (0.0, 0.0, 0.0)

            if let data = self.motion.accelerometerData {
                acc_x = data.acceleration.x
                acc_y = data.acceleration.y
                acc_z = data.acceleration.z
            }

            do {
                try StorageViewModel.storeTrackValue(acc_x, acc_y, acc_z)
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
        self.tracking = false
        self.timer = nil

        do {
            try StorageViewModel.stopTrack()
        } catch {
            fatalError("Failed to stop track \(error)")
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
}
