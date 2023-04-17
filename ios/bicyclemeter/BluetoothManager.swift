import CoreBluetooth
import Serde

struct BluetoothError: Error {
    let message: String
}

enum ConnectionState {
    case Disconnected, Connected, Connecting, Failed(BluetoothError)
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
        try serializer.increase_container_depth()
        try serializer.serialize_variant_index(value: self.rawValue)
        try serializer.decrease_container_depth()
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

struct DiscoveredPeripheral: Comparable, Identifiable {
    static func == (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        lhs.uuid == rhs.uuid
    }

    static func < (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        lhs.uuid < rhs.uuid
    }

    let uuid: String
    let name: String?
    var state: ConnectionState

    init(uuid: String, name: String?, state: ConnectionState) {
        self.uuid = uuid
        self.name = name
        self.state = state
    }

    init(uuid: String, name: String?) {
        self.init(uuid: uuid, name: name, state: .Disconnected)
    }

    var id: String {
        get { self.uuid }
    }
}

class BluetoothManager: NSObject, ObservableObject {
    private var central: CBCentralManager!
    private var peripherals: [String:CBPeripheral] = [:]
    private var connectionObservers: [String:AsyncStream<ConnectionState>.Continuation] = [:]


    @Published var enabled = false
    @Published var scanning = false
    @Published var discoveredPeripherals: [String:DiscoveredPeripheral] = [:]

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
        self.discoveredPeripherals = [:]
        self.peripherals = [:]

        self.scanning = true
        self.central.scanForPeripherals(withServices: nil)
    }

    func connectPeripheral(_ uuid: String) -> AsyncStream<ConnectionState> {
        self.discoveredPeripherals[uuid]?.state = .Connecting

        self.central.connect(self.peripherals[uuid]!)

        return AsyncStream { continuation in
            self.connectionObservers[uuid] = continuation

            continuation.yield(.Connecting)

            continuation.onTermination = { _ in
                self.connectionObservers.removeValue(forKey: uuid)
            }
        }
    }

    func cancelConnection(_ uuid: String) {
        self.discoveredPeripherals[uuid]?.state = .Disconnected

        if let peripheral = self.peripherals[uuid] {
            self.central.cancelPeripheralConnection(peripheral)
        }

        if let callback = self.connectionObservers[uuid] {
            callback.yield(.Disconnected)
            callback.finish()
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.enabled = self.central.state == .poweredOn;
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.discoveredPeripherals[peripheral.identifier.uuidString] = DiscoveredPeripheral(
            uuid: peripheral.identifier.uuidString,
            name: peripheral.name
        )
        self.peripherals[peripheral.identifier.uuidString] = peripheral
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.discoveredPeripherals[peripheral.identifier.uuidString]?.state = .Connected
        if let continuation = self.connectionObservers[peripheral.identifier.uuidString] {
            continuation.yield(.Connected)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.discoveredPeripherals[peripheral.identifier.uuidString]?.state = .Failed(BluetoothError(message: String(describing: error)))

        if let continuation = self.connectionObservers[peripheral.identifier.uuidString] {
            continuation.yield(.Failed(BluetoothError(message: String(describing: error))))
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.discoveredPeripherals[peripheral.identifier.uuidString]?.state = .Disconnected

        if let continuation = self.connectionObservers[peripheral.identifier.uuidString] {
            continuation.yield(.Disconnected)
            continuation.finish()
        }
    }
}
