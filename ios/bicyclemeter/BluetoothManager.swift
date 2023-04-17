import CoreBluetooth

enum BluetoothError: Error {
    case DeviceNotFound, Message(String)
}

class BluetoothManager: NSObject, ObservableObject {
    private var central: CBCentralManager = CBCentralManager()
    private var connectionObservers: [String:CheckedContinuation<Result<CBPeripheralState, BluetoothError>, Never>] = [:]
    private var valueObserver: AsyncStream<(PeripheralKind, Data)>.Continuation?
    private var scanObservers: [Int:AsyncStream<CBPeripheral>.Continuation] = [:]
    private var stateObservers: [Int:AsyncStream<(String, CBPeripheralState)>.Continuation] = [:]
    private var notifiedPeripherals: [(PeripheralKind, CBPeripheral)] = []

    @Published private(set) var enabled = false

    override init() {
        super.init()
        self.central.delegate = self
    }

    func scan() -> AsyncStream<CBPeripheral> {
        self.central.stopScan()
        self.central.scanForPeripherals(withServices: [CBUUID(string: "FFE0")])
        
        return AsyncStream { continuation in
            var contKey = 0
            while self.scanObservers.index(forKey: contKey) != nil {
                contKey += 1
            }
            let key = contKey

            continuation.onTermination = { _ in
                self.scanObservers.removeValue(forKey: key)

                if self.scanObservers.isEmpty {
                    self.central.stopScan()
                }
            }

            self.scanObservers[key] = continuation
        }
    }

    func observeState() -> AsyncStream<(String, CBPeripheralState)> {
        return AsyncStream { continuation in
            var contKey = 0
            while self.stateObservers.index(forKey: contKey) != nil {
                contKey += 1
            }
            let key = contKey

            continuation.onTermination = { _ in
                self.stateObservers.removeValue(forKey: key)
            }

            self.stateObservers[key] = continuation
        }

    }

    func connectPeripheral(_ uuid: String) async -> Result<CBPeripheralState, BluetoothError> {
        for observer in self.stateObservers.values {
            observer.yield((uuid, .connecting))
        }

        return await withCheckedContinuation { continuation in
            guard let peripheral = self.central.retrievePeripherals(withIdentifiers: [UUID(uuidString: uuid)!]).first(where: { per in per.identifier.uuidString == uuid }) else {
                continuation.resume(returning: .failure(.DeviceNotFound))
                return
            }

            self.central.connect(peripheral)
            self.connectionObservers[uuid] = continuation
        }
    }

    func subscribe() -> AsyncStream<(PeripheralKind, Data)> {
        for (_, peripheral) in self.notifiedPeripherals {
            if let service = peripheral.services?.first(where: { s in s.uuid.uuidString == "FFE0" }),
               let characteristic = service.characteristics?.first(where: { c in c.uuid.uuidString == "FFE1" }) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        return AsyncStream { continuation in
            continuation.onTermination = { _ in
                self.valueObserver = nil

                for (_, peripheral) in self.notifiedPeripherals {
                    if let service = peripheral.services?.first(where: { s in s.uuid.uuidString == "FFE0" }),
                       let characteristic = service.characteristics?.first(where: { c in c.uuid.uuidString == "FFE1" }) {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                }
            }

            self.valueObserver = continuation
        }
    }

    func connectSavedPeripherals(_ peripherals: [SavedPeripheral]) {
        for peripheral in self.central.retrieveConnectedPeripherals(withServices: [CBUUID(string: "FFE0")]) {
            if !peripherals.contains(where: { p in p.uuid == peripheral.identifier.uuidString }),
               peripheral.state == .connected || peripheral.state == .connecting {
                self.central.cancelPeripheralConnection(peripheral)
            }
        }

        self.notifiedPeripherals = self.central.retrievePeripherals(withIdentifiers: peripherals.map { p in UUID(uuidString: p.uuid)! })
            .map { peripheral in
                (peripherals.first(where: {p in p.uuid == peripheral.identifier.uuidString })!.kind, peripheral)
            }

        for (_, peripheral) in self.notifiedPeripherals {
            if peripheral.state != .connected && peripheral.state != .connecting {
                self.central.connect(peripheral)
            }
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.enabled = self.central.state == .poweredOn;
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        for observer in self.scanObservers.values {
            observer.yield(peripheral)
        }

        // If this peripheral is a saved peripheral, we directly connect to it
        if self.notifiedPeripherals.contains(where: { (_, p) in p.identifier.uuidString == peripheral.identifier.uuidString }) {
            self.central.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("didConnect \(peripheral.identifier.uuidString)")

        peripheral.delegate = self

        if let continuation = self.connectionObservers.removeValue(forKey: peripheral.identifier.uuidString) {
            continuation.resume(returning: .success(.connected))
        }

        for observer in self.stateObservers.values {
            observer.yield((peripheral.identifier.uuidString, peripheral.state))
        }

        // Service discovery is automatically performed when a peripheral is connected
        peripheral.discoverServices([CBUUID(string: "FFE0")])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("didFailConnect \(peripheral.identifier.uuidString) \(String(describing: error))")

        if let continuation = self.connectionObservers.removeValue(forKey: peripheral.identifier.uuidString) {
            continuation.resume(returning: .failure(.Message(String(describing: error))))
        }

        for observer in self.stateObservers.values {
            observer.yield((peripheral.identifier.uuidString, peripheral.state))
        }

    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("didDisconnect \(peripheral.identifier.uuidString) \(String(describing: error))")

        if let continuation = self.connectionObservers.removeValue(forKey: peripheral.identifier.uuidString) {
            continuation.resume(returning: .success(.disconnected))
        }

        for observer in self.stateObservers.values {
            observer.yield((peripheral.identifier.uuidString, peripheral.state))
        }

        // TODO we may want to reconnect if the disconnected peripheral is a saved one
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("didDiscoverServices \(String(describing: error))")
        // Characteristics discovery is automatically performed when a service with desired uuid is discovered
        if let service = peripheral.services?.first(where: { service in service.uuid.uuidString == "FFE0" }) {
            peripheral.discoverCharacteristics([CBUUID(string: "FFE1")], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("didDiscoverCharacteristicFor \(service.uuid.uuidString) \(String(describing: error))")

        // Subscribing to notification is automatically performed when a characteristic with desired uuid is discovered,
        // the peripheral is a notified peripheral, and there is at least one observer
        if let characteristic = service.characteristics?.first(where: { char in char.uuid.uuidString == "FFE1" }),
           self.notifiedPeripherals.contains(where: { (_, p) in p.identifier.uuidString == peripheral.identifier.uuidString }),
           service.uuid.uuidString == "FFE0",
           self.valueObserver != nil {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("didUpdateValueFor \(characteristic.uuid.uuidString) \(String(describing: error))")

        if let (kind, _) = self.notifiedPeripherals.first(where: { (_, p) in p.identifier.uuidString == peripheral.identifier.uuidString }),
           let value = characteristic.value,
           let observer = self.valueObserver{
                observer.yield((kind, value))
        }
    }
}
