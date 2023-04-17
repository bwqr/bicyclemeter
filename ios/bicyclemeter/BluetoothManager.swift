import CoreBluetooth
import Serde

enum BluetoothError: Error {
    case DeviceNotFound, Message(String)
}

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
    let uuid: String

    static func deserialize(_ deserializer: Deserializer) throws -> Self {
        try deserializer.increase_container_depth()
        let peripheral = SavedPeripheral(kind: try PeripheralKind.deserialize(deserializer), uuid: try deserializer.deserialize_str())
        try deserializer.decrease_container_depth()

        return peripheral
    }

    func serialize(serializer: Serializer) throws {
        try serializer.increase_container_depth()
        try self.kind.serialize(serializer: serializer)
        try serializer.serialize_str(value: self.uuid)
        try serializer.decrease_container_depth()
    }
}

class BluetoothManager: NSObject, ObservableObject {
    private var central: CBCentralManager!
    private var connectionObservers: [String:CheckedContinuation<Result<CBPeripheralState, BluetoothError>, Never>] = [:]

    @Published private(set) var peripherals: [CBPeripheral] = []

    @Published var enabled = false
    @Published var scanning = false

    func start() {
        if self.central != nil {
            return
        }

        self.central = CBCentralManager()
        self.central.delegate = self
        self.scanning = self.central.isScanning
    }

    func stopScanning() {
        self.central.stopScan()
        self.scanning = false
    }

    func scanPeripherals() {
        self.peripherals = []

        self.scanning = true
        self.central.scanForPeripherals(withServices: nil)
    }

    func connectPeripheral(_ uuid: String) async -> Result<CBPeripheralState, BluetoothError> {
        return await withCheckedContinuation { continuation in
            guard let peripheral = self.peripherals.first(where: { per in per.identifier.uuidString == uuid }) else {
                continuation.resume(returning: .failure(.DeviceNotFound))
                return
            }

            self.central.connect(peripheral)
            self.connectionObservers[uuid] = continuation
        }
    }

    func cancelConnection(_ uuid: String) {
        if let peripheral = self.peripherals.first(where: { per in per.identifier.uuidString == uuid }) {
            self.central.cancelPeripheralConnection(peripheral)
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.enabled = self.central.state == .poweredOn;
        self.scanning = self.central.isScanning
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !self.peripherals.contains(where: { per in per.identifier.uuidString == peripheral.identifier.uuidString }) {
            self.peripherals.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.objectWillChange.send()

        if let continuation = self.connectionObservers.removeValue(forKey: peripheral.identifier.uuidString) {
            continuation.resume(returning: .success(.connected))
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.objectWillChange.send()

        if let continuation = self.connectionObservers.removeValue(forKey: peripheral.identifier.uuidString) {
            continuation.resume(returning: .failure(.Message(String(describing: error))))
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.objectWillChange.send()

        if let continuation = self.connectionObservers.removeValue(forKey: peripheral.identifier.uuidString) {
            continuation.resume(returning: .success(.disconnected))
        }
    }
}
