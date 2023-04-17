import CoreBluetooth
import SwiftUI


private struct DiscoveredPeripheral: Identifiable {
    let uuid: String
    let name: String?
    var state: CBPeripheralState

    var id: String {
        get { self.uuid }
    }
}

struct DevicesView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @State private var selectedPeripheral: DiscoveredPeripheral?
    @State private var tasks: [Task<(), Never>] = []
    @State private var discoveredPeripherals: [DiscoveredPeripheral] = []
    @State private var scanTask: Task<(), Never>?
    @State private var stateTask: Task<(), Never>?

    var body: some View {
        _DevicesView(
            enabled: bluetooth.enabled,
            scanning: self.scanTask != nil,
            discoveredPeripherals: self.discoveredPeripherals,
            stopScanning: {
                self.scanTask?.cancel()
                self.scanTask = nil
            },
            scanPeripherals: {
                self.scanTask = Task {
                    self.discoveredPeripherals = []

                    for await peripheral in self.bluetooth.scan() {
                        if !self.discoveredPeripherals.contains(where: { p in p.uuid == peripheral.identifier.uuidString }) {
                            self.discoveredPeripherals.append(
                                DiscoveredPeripheral(
                                    uuid: peripheral.identifier.uuidString,
                                    name: peripheral.name,
                                    state: peripheral.state
                                )
                            )
                        }
                    }
                }
            },
            connectPeripheral: { peripheral in
                self.selectedPeripheral = peripheral
                self.tasks.append(Task {
                    switch await self.bluetooth.connectPeripheral(peripheral.uuid) {
                    case .success(let state):
                        self.selectedPeripheral?.state = state
                    case .failure(let error):
                        fatalError("Failed to connect to peripheral, \(error)")
                    }
                })
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
            self.stateTask = Task {
                for await (uuid, state) in self.bluetooth.observeState() {
                    if let index = self.discoveredPeripherals.firstIndex(where: { p in p.uuid == uuid }) {
                        self.discoveredPeripherals[index].state = state
                    }
                }
            }
        }
        .onDisappear {
            self.scanTask?.cancel()
            self.stateTask?.cancel()

            self.scanTask = nil
            self.stateTask = nil

            for task in tasks {
                task.cancel()
            }
        }
    }
}

private struct _DevicesView: View {
    let enabled: Bool
    let scanning: Bool
    let discoveredPeripherals: [DiscoveredPeripheral]

    let stopScanning: () -> ()
    let scanPeripherals: () -> ()
    let connectPeripheral: (DiscoveredPeripheral) -> ()

    var body: some View {
        VStack(spacing: 8.0) {
            List(self.discoveredPeripherals) { peripheral in
                let title = peripheral.name ?? "-"

                Button(action: {
                    self.connectPeripheral(peripheral)
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
                    Text(self.scanning ? "Stop Scanning" : "Scan Peripherals")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(self.enabled ? (self.scanning ? .red : .blue) : .gray)
                .cornerRadius(8)
            }
            .padding([.leading, .trailing, .bottom], 18)
        }
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
        uuid: "ADFE20F46A11-8C6F-17B6-4756-C6D16E0F133B",
        name: "Gyro Sensor",
        state: .connected
    )

    static var previews: some View {
        _DevicesView(
            enabled: false,
            scanning: false,
            discoveredPeripherals: [
                DiscoveredPeripheral(
                    uuid: "ADFE20F46A11-8C6F-17B6-4756-C6D16E0F133B",
                    name: "Gyro Sensor",
                    state: .connecting
                ),
                DiscoveredPeripheral(
                    uuid: "8C7F30F46A11-8C6F-17B6-4756-C6D16E0F133B",
                    name: "Comm Server",
                    state: .disconnected
                ),
                DiscoveredPeripheral(
                    uuid: "C7D2430F46A11-8C6F-17B6-4756-C6D16E0F133B",
                    name: "My Phone",
                    state: .connecting
                ),
            ],
            stopScanning: { },
            scanPeripherals: { },
            connectPeripheral: { _ in }
        )
        .sheet(
            item: .constant(Self.selectedPeripheral),
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

private func hex(_ data: Data) -> String {
    return data.reduce(into: "") { result, byte in
        result.append(String(byte >> 4, radix: 16))
        result.append(String(byte & 0x0f, radix: 16))
    }
}
