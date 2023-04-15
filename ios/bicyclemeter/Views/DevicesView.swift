import CoreBluetooth
import SwiftUI

class BluetootManager2: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager
    private var peripheral: CBPeripheral?
    @Published var connected: Bool = false

    init(_ central: CBCentralManager) {
        self.central = central
        super.init()
        central.delegate = self
    }

    func scanPeripherals() {
        if case .poweredOn = self.central.state {
            self.central.scanForPeripherals(withServices: nil)
        } else {
            print("Please open the bluetooth first")
        }
    }

    func disconnect() {
        if let peripheral = self.peripheral {
            self.central.cancelPeripheralConnection(peripheral)
        }
    }

    func connect(_ peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self

        self.central.stopScan()
        self.central.connect(peripheral)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("\(central.state)")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.identifier.uuidString == "30F46A11-8C6F-17B6-4756-C6D16E0F133B" {
            print("Found the device")

            self.peripheral = peripheral
            peripheral.delegate = self

            self.central.stopScan()
            self.central.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to the device")
        self.connected = true
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from the device")
        self.connected = false
        self.peripheral = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Discovered services")
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
            print(hex(service.uuid.data))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("Character for service \(service.uuid)")

        if service.uuid.uuidString == "FFE0" {
            print("Found desired service")
            for character in service.characteristics ?? [] {
                if character.uuid.uuidString == "FFE1" {
                    print("Found desired characteristic")
                    if character.properties.contains(.broadcast) {
                        print("Character contains the prop broadcast")
                    }
                    if character.properties.contains(.read) {
                        print("Character contains the prop read")
                    }
                    if character.properties.contains(.write) {
                        print("Character contains the prop write")
                    }
                    if character.properties.contains(.notify) {
                        print("Character contains the prop notify")
                    }
                    self.peripheral?.setNotifyValue(true, for: character)
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Characteristic is updated")
        if let value = characteristic.value {
            print(String(decoding: value, as: UTF8.self))
        }
    }
}

struct DevicesView: View {
    @ObservedObject var bluetooth: BluetoothManager
    @State var selectedPeripheral: DiscoveredPeripheral?
    @State var connectionState: ConnectionState = .Disconnected

    var body: some View {
        _DevicesView(
            enabled: $bluetooth.enabled,
            scanning: $bluetooth.scanning,
            discoveredPeripherals: $bluetooth.discoveredPeripherals,
            stopScanning: { self.bluetooth.stopScanning() },
            scanPeripherals: { self.bluetooth.scanPeripherals() },
            connectPeripheral: { peripheral in
                self.selectedPeripheral = peripheral
                self.connectionState = .Connecting
                Task {
                    self.connectionState = await self.bluetooth.connectPeripheral(peripheral.uuid)
                }
            }
        )
        .sheet(
            item: $selectedPeripheral,
            onDismiss: {
                if let selected = self.selectedPeripheral {
                    self.bluetooth.cancelConnection(selected.uuid)
                }

                self.selectedPeripheral = nil
            }
        ) { peripheral in
            SafeContainer(value: $selectedPeripheral) { selectedPeripheral in
                _PeripheralConnectingView(
                    connectionState: $connectionState,
                    savePeripheral: {
                        self.selectedPeripheral = nil
                    }
                )
            }
        }
        .onAppear {
            self.bluetooth.start()
        }
        .onDisappear {
            self.bluetooth.stopScanning()
        }
    }
}

private struct _DevicesView: View {
    @Binding var enabled: Bool
    @Binding var scanning: Bool
    @Binding var discoveredPeripherals: [String:DiscoveredPeripheral]

    let stopScanning: () -> ()
    let scanPeripherals: () -> ()
    let connectPeripheral: (DiscoveredPeripheral) -> ()

    var body: some View {
        VStack(spacing: 8.0) {
            List(self.discoveredPeripherals.values.sorted(by: <), id: \.self.uuid) { peripheral in
                let title = peripheral.name ?? "-"

                Button(action: {
                    self.connectPeripheral(peripheral)
                }) {
                    VStack(alignment: .leading, spacing: 4.0) {
                        Text("\(title)")

                        Text("\(peripheral.uuid)")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    }
                }
            }

            VStack {
                if !self.enabled {
                    Text("Please enable the bluetooth first")
                }

                if self.scanning {
                    Button(action: {
                        self.stopScanning()
                    }) {
                        Text("Stop Scanning")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(.red)
                    .cornerRadius(8)
                } else {
                    Button(action: {
                        self.scanPeripherals()
                    }) {
                        Text("Scan Peripherals")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(self.enabled ? .blue : .gray)
                    .cornerRadius(8)
                    .disabled(!self.enabled)
                }
            }
            .padding([.leading, .trailing, .bottom], 18)
        }
    }
}

private struct _PeripheralConnectingView: View {
    @Binding var connectionState: ConnectionState

    let savePeripheral: () -> ()

    var body: some View {
        switch connectionState {
        case .Connected:
            VStack {
                Text("Connected")

                Button(action: { savePeripheral() }) {
                    Text("Save the peripheral")
                }
            }
        case .Connecting:
            Text("Connecting")
        case .Failed(let reason):
            Text("Failed to connect \(reason.message)")
        case .Disconnected:
            Text("Disconnected")
        }
    }
}

struct DevicesView_Previews: PreviewProvider {
    static let selectedPeripheral: DiscoveredPeripheral? = nil

    static var previews: some View {
        _DevicesView(
            enabled: .constant(false),
            scanning: .constant(false),
            discoveredPeripherals: .constant([
                "BT05": DiscoveredPeripheral(uuid: "ADFE20F46A11-8C6F-17B6-4756-C6D16E0F133B", name: "Gyro Sensor"),
                "iPad": DiscoveredPeripheral(uuid: "8C7F30F46A11-8C6F-17B6-4756-C6D16E0F133B", name: "Comm Server"),
                "iPhone": DiscoveredPeripheral(uuid: "C7D2430F46A11-8C6F-17B6-4756-C6D16E0F133B", name: "My Phone"),
            ]),
            stopScanning: { },
            scanPeripherals: { },
            connectPeripheral: { _ in }
        )
        .sheet(
            item: .constant(Self.selectedPeripheral),
            onDismiss: { }
        ) { _ in
            _PeripheralConnectingView(
                connectionState: .constant(.Connected),
                savePeripheral: { }
            )
        }
    }
}

private func hex(_ data: Data) -> String {
    return data.reduce(into: "") { result, byte in
        result.append(String(byte >> 4, radix: 16))
        result.append(String(byte & 0x0f, radix: 16))
    }
}
