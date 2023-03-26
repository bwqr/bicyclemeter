import Serde

enum StorageError : Error {
    case Db
    case Message(String)
    
    static func deserialize(_ deserializer: Deserializer) throws -> StorageError {
        let index = try deserializer.deserialize_variant_index()
        
        switch index {
        case 0: return .Db
        case 1: return .Message(try deserializer.deserialize_str())
        default: throw DeserializationError.invalidInput(issue: "Unknown variant index for StorageError")
        }
    }
}
