import SwiftUI
import CoreLocation
import CoreBluetooth

struct ContentView: View {
    let bluetooth = BluetoothManager()
    @ObservedObject var track: TrackManager

    init() {
        self.track = TrackManager(bluetooth: self.bluetooth)
    }

    @State var showWelcomeView: Bool = false

    var body: some View {
        _ContentView(tracking: $track.tracking)
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
            do {
                showWelcomeView = !(try StorageViewModel.welcomeShown())
            } catch {
                fatalError("Unhandled error \(error)")
            }
        }
    }
}

private struct _ContentView: View {
    @Binding var tracking: Bool

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
            .navigationTitle("Bicyclemeter")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        _ContentView(tracking: .constant(true))
            .environmentObject(BluetoothManager())
    }
}
