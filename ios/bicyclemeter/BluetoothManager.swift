import CoreBluetooth

enum BluetoothError: Error {
    case DeviceNotFound, Message(String)
}

class BluetoothManager: NSObject, ObservableObject {
    private var central: CBCentralManager = CBCentralManager()
    private var valueObserver: AsyncStream<(PeripheralKind, Data)>.Continuation?
    private var stateObservers: [Int:AsyncStream<CBPeripheral>.Continuation] = [:]
    private var scanObservers: [Int:AsyncStream<CBPeripheral>.Continuation] = [:]
    private var notifiedPeripherals: [(PeripheralKind, CBPeripheral)] = []

    @Published private(set) var enabled = false

    override init() {
        super.init()
        self.central.delegate = self
    }

    func states() -> AsyncStream<CBPeripheral> {
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

    func scan() -> AsyncStream<CBPeripheral> {
        self.central.scanForPeripherals(withServices: [CBUUID(string: "FFE0")])

        return AsyncStream { continuation in
            var contKey = 0
            while self.scanObservers.index(forKey: contKey) != nil {
                contKey += 1
            }
            let key = contKey

            continuation.onTermination = { _ in
                self.scanObservers.removeValue(forKey: key)

                if self.scanObservers.isEmpty && self.enabled {
                    self.central.stopScan()
                }
            }

            self.scanObservers[key] = continuation
        }
    }

    func retrievePeripherals(_ uuids: [UUID]) -> [CBPeripheral] {
        return self.central.retrievePeripherals(withIdentifiers: uuids)
    }

    func connectPeripheral(_ uuid: UUID) throws {
        guard let peripheral = self.central.retrievePeripherals(withIdentifiers: [uuid]).first(where: { per in per.identifier == uuid }) else {
            throw BluetoothError.DeviceNotFound
        }

        self.central.connect(peripheral)

        // Notify updated state of the peripheral
        if let peripheral = self.central.retrievePeripherals(withIdentifiers: [uuid]).first {
            for observer in self.stateObservers.values {
                observer.yield(peripheral)
            }
        }
    }

    func cancelConnection(_ uuid: UUID) {
        guard let peripheral = self.central.retrievePeripherals(withIdentifiers: [uuid]).first(where: { per in per.identifier == uuid }) else {
            return
        }

        self.central.cancelPeripheralConnection(peripheral)
    }

    /// Returns an AsyncStream which yields values received from notifiedPeripherals.
    /// It tries to set notifyValue to true if the notifiedPeripherals have the desired services and
    /// characteristics. It also sets it to false when stream ends. This method is not responsible
    /// for connection and discovery of the services and characteristics.
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

    /// This method cancels connection to the connected peripherals and tries to connect
    /// to the given peripherals if bluetooth is enabled. If a peripheral is both given and already
    /// connected, its connection will not be cancelled. This method complements the
    /// ``subscribe()`` method by managing the connections. The discovery of the services
    /// and the characteristics are performed automatically in the peripheral delegate methods
    /// when a peripheral connects automatically. If a desired service and characteristic is found,
    /// the notifyValue is automatically set to true in the peripheral delegate methods.
    func connectToSavedPeripherals(_ savedPeripherals: [SavedPeripheral]) {
        self.notifiedPeripherals = self.central.retrievePeripherals(withIdentifiers: savedPeripherals.map { p in p.uuid })
            .map { peripheral in
                (savedPeripherals.first(where: {p in p.uuid == peripheral.identifier })!.kind, peripheral)
            }

        if !self.enabled {
            return
        }

        for peripheral in self.central.retrieveConnectedPeripherals(withServices: [CBUUID(string: "FFE0")]) {
            if !savedPeripherals.contains(where: { p in p.uuid == peripheral.identifier }),
               peripheral.state == .connected || peripheral.state == .connecting {
                self.central.cancelPeripheralConnection(peripheral)
            }
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

        if self.enabled {
            // Retry connecting to the notified peripherals
            self.connectToSavedPeripherals(self.notifiedPeripherals.map { (k, p) in SavedPeripheral.fromPeripheral(k, p) })
        } else {
            // Finish the observers since bluetooth is not enabled anymore
            for observer in self.scanObservers.values {
                observer.finish()
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("didDiscover \(peripheral.identifier.uuidString)")
        for observer in self.scanObservers.values {
            observer.yield(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("didConnect \(peripheral.identifier.uuidString)")

        peripheral.delegate = self

        for observer in self.stateObservers.values {
            observer.yield(peripheral)
        }

        // Service discovery is automatically performed when a peripheral is connected
        peripheral.discoverServices([CBUUID(string: "FFE0")])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("didFailToConnect \(peripheral.identifier.uuidString) \(String(describing: error))")

        for observer in self.scanObservers.values {
            observer.yield(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("didDisconnect \(peripheral.identifier.uuidString) \(String(describing: error))")

        for observer in self.stateObservers.values {
            observer.yield(peripheral)
        }

        // TODO we may want to reconnect if the disconnected peripheral is a notified one
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
           let observer = self.valueObserver {
            observer.yield((kind, value))
        }
    }
}
