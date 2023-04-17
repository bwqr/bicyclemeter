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

    static func savePeripheral(_ peripheral: SavedPeripheral) throws -> () {
        let serializer = BincodeSerializer()
        try peripheral.serialize(serializer: serializer)
        let bytes = serializer.get_bytes()

        let ptr = bytes.withUnsafeBytes { bytes in
            return reax_storage_save_peripheral(bytes.baseAddress!, bytes.count) { bytes, bytesLen in
                let array = Array(UnsafeBufferPointer(start: bytes, count: Int(bytesLen)))

                return UnsafeMutableRawPointer(Unmanaged.passRetained(BincodeDeserializer(input: array)).toOpaque())
            }
        }

        let deserializer = Unmanaged<AnyObject>.fromOpaque(ptr!).takeRetainedValue() as! BincodeDeserializer

        let index = try deserializer.deserialize_variant_index()

        switch index {
        case 0: return ()
        case 1: throw try StorageError.deserialize(deserializer)
        default: throw DeserializationError.invalidInput(issue: "Unknown variant index for StorageError")
        }
    }

    static func peripherals() -> AsyncStream<Result<[SavedPeripheral], StorageError>> {
        return Runtime.runStream { deserializer in
            try deserializeList(deserializer, deserialize: { try SavedPeripheral.deserialize($0) })
        } _: { stream_id in
            reax_storage_peripherals(stream_id)
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

    static func deleteTrack(_ timestamp: Int64) throws -> () {
        let ptr = reax_storage_delete_track(timestamp) { bytes, bytesLen in
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

    static func storeTrackValue(_ track: TrackData) throws -> () {
        let serializer = BincodeSerializer()
        try track.serialize(serializer)
        let bytes = serializer.get_bytes()

        let ptr = bytes.withUnsafeBytes { bytes in
            return reax_storage_store_track_value(bytes.baseAddress!, bytes.count) { bytes, bytesLen in
                let array = Array(UnsafeBufferPointer(start: bytes, count: Int(bytesLen)))

                return UnsafeMutableRawPointer(Unmanaged.passRetained(BincodeDeserializer(input: array)).toOpaque())
            }
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
