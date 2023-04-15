import CoreBluetooth

struct BluetoothError: Error {
    let message: String
}

enum ConnectionState {
    case Disconnected, Connected, Connecting, Failed(BluetoothError)
}

enum PeripheralKind {
    case Foot, Bicylce
}

struct Peripheral {
    let kind: PeripheralKind
    let peripheral: CBPeripheral
}

struct DiscoveredPeripheral: Comparable, Identifiable {
    static func < (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        lhs.uuid < rhs.uuid
    }

    let uuid: String
    let name: String?

    var id: String {
        get { self.uuid }
    }
}

class BluetoothManager: NSObject, ObservableObject {
    private var central: CBCentralManager!
    private var peripherals: [String:CBPeripheral] = [:]
    private var waitingConnections: [String:(ConnectionState) -> ()] = [:]


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

    func connectPeripheral(_ uuid: String) async -> ConnectionState {
        self.central.connect(self.peripherals[uuid]!)

        return await withCheckedContinuation { continuation in
            self.waitingConnections[uuid] = { state in
                continuation.resume(returning: state)
            }
        }
    }

    func cancelConnection(_ uuid: String) {
        if let peripheral = self.peripherals[uuid] {
            self.central.cancelPeripheralConnection(peripheral)
        }

        if let callback = self.waitingConnections[uuid] {
            callback(.Disconnected)
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
        if let callback = self.waitingConnections[peripheral.identifier.uuidString] {
            callback(.Connected)

            self.waitingConnections.removeValue(forKey: peripheral.identifier.uuidString)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let callback = self.waitingConnections[peripheral.identifier.uuidString] {
            callback(.Failed(BluetoothError(message: String(describing: error))))

            self.waitingConnections.removeValue(forKey: peripheral.identifier.uuidString)
        }
    }
}
