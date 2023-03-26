import Serde

class StorageViewModel {
    static func initialize() {
        reax_storage_init();
    }

    static func welcomeShown() throws -> Bool {
        let ptr = reax_storage_welcome_shown { bytes, bytesLen in
            let array = Array(UnsafeBufferPointer(start: bytes, count: Int(bytesLen)))

            return UnsafeMutableRawPointer(Unmanaged.passRetained(BincodeDeserializer(input: array)).toOpaque())
        }

        let deserializer = Unmanaged<AnyObject>.fromOpaque(ptr!).takeRetainedValue() as! BincodeDeserializer

        let index = try deserializer.deserialize_variant_index()

        switch index {
        case 0: return try deserializer.deserialize_bool()
        case 1: throw try StorageError.deserialize(deserializer)
        default: throw DeserializationError.invalidInput(issue: "Unknown variant index for StorageError")
        }
    }

    static func showWelcome() throws -> () {
        let ptr = reax_storage_show_welcome { bytes, bytesLen in
            let array = Array(UnsafeBufferPointer(start: bytes, count: Int(bytesLen)))

            return UnsafeMutableRawPointer(Unmanaged.passRetained(BincodeDeserializer(input: array)).toOpaque())
        }

        let deserializer = Unmanaged<AnyObject>.fromOpaque(ptr!).takeRetainedValue() as! BincodeDeserializer

        let index = try deserializer.deserialize_variant_index()

        switch index {
        case 0: return ()
        case 1: throw try StorageError.deserialize(deserializer)
        default: throw DeserializationError.invalidInput(issue: "Unknown variant index for StorageError")
        }
    }

    static func startTrack() throws -> () {
        let ptr = reax_storage_start_track { bytes, bytesLen in
            let array = Array(UnsafeBufferPointer(start: bytes, count: Int(bytesLen)))

            return UnsafeMutableRawPointer(Unmanaged.passRetained(BincodeDeserializer(input: array)).toOpaque())
        }

        let deserializer = Unmanaged<AnyObject>.fromOpaque(ptr!).takeRetainedValue() as! BincodeDeserializer

        let index = try deserializer.deserialize_variant_index()

        switch index {
        case 0: return ()
        case 1: throw try StorageError.deserialize(deserializer)
        default: throw DeserializationError.invalidInput(issue: "Unknown variant index for StorageError")
        }
    }

    static func stopTrack() throws -> () {
        let ptr = reax_storage_stop_track { bytes, bytesLen in
            let array = Array(UnsafeBufferPointer(start: bytes, count: Int(bytesLen)))

            return UnsafeMutableRawPointer(Unmanaged.passRetained(BincodeDeserializer(input: array)).toOpaque())
        }

        let deserializer = Unmanaged<AnyObject>.fromOpaque(ptr!).takeRetainedValue() as! BincodeDeserializer

        let index = try deserializer.deserialize_variant_index()

        switch index {
        case 0: return ()
        case 1: throw try StorageError.deserialize(deserializer)
        default: throw DeserializationError.invalidInput(issue: "Unknown variant index for StorageError")
        }
    }

    static func storeTrackValue(_ acc_x: Double, _ acc_y: Double, _ acc_z: Double) throws -> () {
        let ptr = reax_storage_store_track_value(acc_x, acc_y, acc_z) { bytes, bytesLen in
            let array = Array(UnsafeBufferPointer(start: bytes, count: Int(bytesLen)))

            return UnsafeMutableRawPointer(Unmanaged.passRetained(BincodeDeserializer(input: array)).toOpaque())
        }

        let deserializer = Unmanaged<AnyObject>.fromOpaque(ptr!).takeRetainedValue() as! BincodeDeserializer

        let index = try deserializer.deserialize_variant_index()

        switch index {
        case 0: return ()
        case 1: throw try StorageError.deserialize(deserializer)
        default: throw DeserializationError.invalidInput(issue: "Unknown variant index for StorageError")
        }
    }
}
