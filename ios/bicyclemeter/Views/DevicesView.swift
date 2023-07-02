import CoreBluetooth
import SwiftUI


private struct DiscoveredPeripheral: Identifiable {
    let uuid: UUID
    let name: String?
    var state: CBPeripheralState

    static func from(peripheral: CBPeripheral) -> Self {
        return DiscoveredPeripheral(uuid: peripheral.identifier, name: peripheral.name, state: peripheral.state)
    }

    var id: UUID {
        get { self.uuid }
    }
}

struct DevicesView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @State private var savedPeripherals: [(PeripheralKind, DiscoveredPeripheral)] = []
    @State private var selectedPeripheral: DiscoveredPeripheral?
    @State private var discoveredPeripherals: [CBPeripheral] = []
    @State private var scanTask: Task<(), Never>?
    @State private var peripheralsTask: Task<(), Never>?
    @State private var stateTask: Task<(), Never>?

    var body: some View {
        _DevicesView(
            enabled: bluetooth.enabled,
            scanning: self.scanTask != nil,
            savedPeripherals: self.savedPeripherals,
            discoveredPeripherals: self.discoveredPeripherals.map { peripheral in
                DiscoveredPeripheral.from(peripheral: peripheral)
            },
            stopScanning: {
                self.scanTask?.cancel()
                self.scanTask = nil
            },
            scanPeripherals: {
                self.scanTask = Task {
                    self.discoveredPeripherals = []

                    for await peripheral in self.bluetooth.scan() {
                        if !self.discoveredPeripherals.contains(where: { p in p.identifier.uuidString == peripheral.identifier.uuidString }) {
                            self.discoveredPeripherals.append(peripheral)
                        }
                   }

                    self.scanTask = nil
                }
            },
            savePeripheral: { peripheral in self.selectedPeripheral = peripheral },
            connectPeripheral: { peripheral in
                do {
                    try self.bluetooth.connectPeripheral(peripheral.uuid)
                } catch {
                    fatalError("Failed to connect to peripheral, \(error)")
                }
            },
            disconnectPeripheral: { peripheral in
                self.bluetooth.cancelConnection(peripheral.uuid)
            }
        )
        .sheet(
            item: $selectedPeripheral,
            onDismiss: { }
        ) { peripheral in
            _PeripheralConnectingView(
                peripheral: peripheral,
                savePeripheral: { peripheral in
                    self.selectedPeripheral = nil

                    do {
                        try StorageViewModel.savePeripheral(peripheral)
                    } catch {
                        fatalError("Failed to save peripheral \(error)")
                    }
                }
            )
        }
        .onAppear {
            self.peripheralsTask = Task {
                for await result in StorageViewModel.peripherals() {
                    switch result {
                    case .success(let peripherals):
                        self.savedPeripherals = self.bluetooth.retrievePeripherals( peripherals.map { $0.uuid } )
                            .map { p in
                                (peripherals.first(where: { savedPeriph in savedPeriph.uuid == p.identifier })!.kind, DiscoveredPeripheral.from(peripheral: p))
                            }
                    case .failure(let error):
                        fatalError("Failed to fetch peripherals, \(error)")
                    }
                }

                self.peripheralsTask = nil
            }

            self.stateTask = Task {

                for await peripheral in self.bluetooth.states() {
                    if let index = self.discoveredPeripherals.firstIndex(where: { $0.identifier == peripheral.identifier }) {
                        self.discoveredPeripherals.remove(at: index)
                        self.discoveredPeripherals.insert(peripheral, at: index)
                    }

                    if let index = self.savedPeripherals.firstIndex(where: { $0.1.uuid == peripheral.identifier }) {
                        let (kind, _) = self.savedPeripherals.remove(at: index)
                        self.savedPeripherals.insert((kind, DiscoveredPeripheral.from(peripheral: peripheral)), at: index)
                    }

                    if self.selectedPeripheral?.uuid == peripheral.identifier {
                        self.selectedPeripheral = DiscoveredPeripheral.from(peripheral: peripheral)
                    }
                }

                self.stateTask = nil
            }

        }
        .onDisappear {
            self.scanTask?.cancel()
            self.stateTask?.cancel()
            self.peripheralsTask?.cancel()

            self.scanTask = nil
            self.stateTask = nil
            self.peripheralsTask = nil

            for peripheral in self.discoveredPeripherals {
                if !self.savedPeripherals.contains(where: { $0.1.uuid == peripheral.identifier }) &&
                    (peripheral.state == .connected || peripheral.state == .connecting) {
                    self.bluetooth.cancelConnection(peripheral.identifier)
                }
            }
        }
    }
}

private struct _DevicesView: View {
    let enabled: Bool
    let scanning: Bool
    let savedPeripherals: [(PeripheralKind, DiscoveredPeripheral)]
    let discoveredPeripherals: [DiscoveredPeripheral]

    let stopScanning: () -> ()
    let scanPeripherals: () -> ()
    let savePeripheral: (DiscoveredPeripheral) -> ()
    let connectPeripheral: (DiscoveredPeripheral) -> ()
    let disconnectPeripheral: (DiscoveredPeripheral) -> ()

    var body: some View {
        VStack(spacing: 8.0) {
            List {
                if !self.savedPeripherals.isEmpty {
                    Section("Saved Sensors") {
                        ForEach(self.savedPeripherals, id: \.self.1.uuid) { (kind, peripheral) in
                            Button(action: {
                                if peripheral.state == .connected || peripheral.state == .connecting {
                                    self.disconnectPeripheral(peripheral)
                                } else {
                                    self.connectPeripheral(peripheral)
                                }
                            }) {
                                HStack {
                                    Text(peripheral.name ?? "-")
                                    Spacer()
                                    switch peripheral.state {
                                    case .connected:
                                        Text("Connected")
                                            .foregroundColor(.gray)
                                    case .connecting:
                                        Text("Connecting")
                                            .foregroundColor(.gray)
                                    default:
                                        Text("Disconnected")
                                            .foregroundColor(.gray)
                                    }

                                    Text(" - \(kind.toString())")
                                }
                            }
                        }
                    }
                }

                if !self.discoveredPeripherals.isEmpty || self.scanning {
                    Section("Discovered Sensors") {
                        ForEach(self.discoveredPeripherals) { peripheral in
                            let title = peripheral.name ?? "-"

                            Button(action: {
                                self.connectPeripheral(peripheral)
                                self.savePeripheral(peripheral)
                            }) {
                                VStack(alignment: .leading, spacing: 4.0) {
                                    HStack {
                                        Text("\(title)")
                                        Spacer()
                                        if case .connecting = peripheral.state {
                                            Text("Connecting")
                                                .foregroundColor(.gray)
                                        } else if case .connected = peripheral.state {
                                            Text("Connected")
                                                .foregroundColor(.gray)
                                        }
                                    }

                                    Text("\(peripheral.uuid)")
                                        .foregroundColor(.gray)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
            }

            VStack {
                if !self.enabled {
                    Text("Please enable the bluetooth first")
                }

                Button(action: {
                    if self.scanning {
                        self.stopScanning()
                    } else {
                        self.scanPeripherals()
                    }
                }) {
                    Text(self.scanning ? "Stop Scanning" : "Scan Sensors")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(self.enabled ? (self.scanning ? .red : .blue) : .gray)
                .cornerRadius(8)
                .disabled(!self.enabled)
            }
            .padding([.leading, .trailing, .bottom], 18)
        }
        .background(.ultraThickMaterial)
        .navigationTitle("Sensors")
    }
}

private struct _PeripheralConnectingView: View {
    let peripheral: DiscoveredPeripheral
    let savePeripheral: (SavedPeripheral) -> ()

    @State private var selectedKind: PeripheralKind? = .Foot

    var body: some View {
        VStack {
            List {
                Section {
                    HStack {
                        Text("State:")
                        Spacer()

                        switch peripheral.state {
                        case .connected:
                            Text("Connected")
                        case .connecting:
                            Text("Connecting")
                        default:
                            Text("Disconnected")
                        }
                    }
                }
                Section {
                    ForEach(PeripheralKind.allCases) { kind in
                        HStack {
                            Image(systemName: selectedKind == kind ? "circle.inset.filled" : "circle")
                            Text(kind.toString()).tag(kind)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedKind = kind
                        }
                    }
                }
            }

            if case .connected = peripheral.state {
                Button(action: {
                    savePeripheral(SavedPeripheral(
                        kind: self.selectedKind!,
                        uuid: self.peripheral.uuid
                    ))
                }) {
                    Text("Save Peripheral")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(.blue)
                .cornerRadius(8)
                .padding([.leading, .trailing, .bottom], 18)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct DevicesView_Previews: PreviewProvider {
    private static let selectedPeripheral: DiscoveredPeripheral? = DiscoveredPeripheral(
        uuid: UUID(uuidString: "ADFE20F46A11-8C6F-17B6-4756-C6D16E0F133B")!,
        name: "Gyro Sensor",
        state: .connected
    )

    static var previews: some View {
        _DevicesView(
            enabled: false,
            scanning: false,
            savedPeripherals: [
                (
                    .Bicycle,
                    DiscoveredPeripheral(
                        uuid: UUID(uuidString: "4B57DF7D-BBCC-EF74-502B-614F07E6BA0C")!,
                        name: "Accel Sensor",
                        state: .disconnected
                    )
                ),
                (
                    .Foot,
                    DiscoveredPeripheral(
                        uuid: UUID(uuidString: "DDEE7C5D-9D1C-96A5-C5F9-A23E18A5CDEB")!,
                        name: "Gyro Sensors",
                        state: .connected
                    )
                )
            ],
            discoveredPeripherals: [
                DiscoveredPeripheral(
                    uuid: UUID(uuidString: "8C2AD3F6-2983-1A25-A030-3DCC954E4550")!,
                    name: "Gyro Sensor",
                    state: .connecting
                ),
                DiscoveredPeripheral(
                    uuid: UUID(uuidString: "6AAF3F2C-568D-0412-8CCF-BC81C018276B")!,
                    name: "Comm Server",
                    state: .disconnected
                ),
                DiscoveredPeripheral(
                    uuid: UUID(uuidString: "A5F3E877-1D93-BE7C-9021-BD92F888A310")!,
                    name: "My Phone",
                    state: .connecting
                ),
            ],
            stopScanning: { },
            scanPeripherals: { },
            savePeripheral: { _ in },
            connectPeripheral: { _ in },
            disconnectPeripheral: { _ in }
        )
        .sheet(
            item: .constant(nil as DiscoveredPeripheral?),
            onDismiss: { }
        ) { peripheral in
            _PeripheralConnectingView(
                peripheral: peripheral,
                savePeripheral: { _ in }
            )
        }
        .environmentObject(BluetoothManager())
    }
}
