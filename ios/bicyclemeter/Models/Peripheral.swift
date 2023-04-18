import CoreBluetooth
import Serde

enum PeripheralKind: UInt32, CaseIterable, Identifiable {
    var id: UInt32 {
        get { self.rawValue }
    }

    case Foot = 0, Bicycle

    static func deserialize(_ deserializer: Deserializer) throws -> Self {
        switch try deserializer.deserialize_variant_index() {
        case 0: return .Foot
        case 1: return .Bicycle
        default: throw DeserializationError.invalidInput(issue: "Unknown variant index for PeripheralKind")
        }
    }

    func serialize(serializer: Serializer) throws {
        try serializer.serialize_variant_index(value: self.rawValue)
    }

    func toString() -> String {
        switch self {
        case .Foot:
            return "Foot"
        case .Bicycle:
            return "Bicycle"
        }
    }
}

struct SavedPeripheral {
    let kind: PeripheralKind
    let uuid: UUID

    static func fromPeripheral(_ kind: PeripheralKind, _ peripheral: CBPeripheral) -> Self {
        return SavedPeripheral(kind: kind, uuid: peripheral.identifier)
    }

    static func deserialize(_ deserializer: Deserializer) throws -> Self {
        try deserializer.increase_container_depth()
        let peripheral = SavedPeripheral(
            kind: try PeripheralKind.deserialize(deserializer),
            uuid: try UUID(uuidString: deserializer.deserialize_str())!
        )
        try deserializer.decrease_container_depth()

        return peripheral
    }

    func serialize(serializer: Serializer) throws {
        try serializer.increase_container_depth()
        try self.kind.serialize(serializer: serializer)
        try serializer.serialize_str(value: self.uuid.uuidString)
        try serializer.decrease_container_depth()
    }
}
