import SwiftUI
import CoreLocation
import CoreBluetooth

struct ContentView: View {
    let bluetooth = BluetoothManager()

    @ObservedObject var track: TrackManager
    @State var showWelcomeView: Bool = false
    @State var connectionTask: Task<(), Never>?

    init() {
        self.track = TrackManager(bluetooth: self.bluetooth)
    }

    var body: some View {
        _ContentView(tracking: track.tracking)
        .sheet(isPresented: $showWelcomeView) {
            WelcomeView {
                do {
                    try StorageViewModel.showWelcome()
                    showWelcomeView = false
                } catch {
                    fatalError("Unhandled error \(error)")
                }
            }
        }
        .environmentObject(self.bluetooth)
        .environmentObject(self.track)
        .onAppear {
            self.connectionTask = Task {
                for await result in StorageViewModel.peripherals() {
                    switch result {
                    case .success(let peripherals):
                        self.bluetooth.connectToSavedPeripherals(peripherals)
                    case .failure(let error):
                        fatalError("Failed to fetch peripherals, \(error)")
                    }
                }

                self.connectionTask = nil
            }

            do {
                showWelcomeView = !(try StorageViewModel.welcomeShown())
            } catch {
                fatalError("Unhandled error \(error)")
            }
        }
        .onDisappear {
            self.connectionTask?.cancel()
            self.connectionTask = nil
        }
    }
}

private struct _ContentView: View {
    let tracking: Bool

    var body: some View {
        NavigationView {
            VStack {
                List {
                    HStack {
                        Image(systemName: "externaldrive")
                        NavigationLink(destination: DevicesView()) {
                            Text("Manage Sensors")
                        }
                    }

                    HStack {
                        Image(systemName: "list.bullet")
                        NavigationLink(destination: TrackHistoryView()) {
                            Text("Track History")
                        }
                    }
                }

                NavigationLink(destination: CyclingView()) {
                    HStack {
                        Image(systemName: "bicycle")
                            .foregroundColor(.white)

                        Text(tracking ? "Continue Cycling" : "Cycle")
                            .foregroundColor(.white)
                    }
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(tracking ? .green : .blue)
                .cornerRadius(8)
                .padding([.leading, .trailing, .bottom], 18)
            }
            .background(.ultraThickMaterial)
            .navigationTitle("Bicyclemeter")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        _ContentView(tracking: true)
            .environmentObject(BluetoothManager())
            .environmentObject(TrackManager(bluetooth: BluetoothManager()))
    }
}
