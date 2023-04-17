import SwiftUI

struct CyclingView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @ObservedObject var track = TrackViewModel()
    @State var tasks: [Task<(), Never>] = []
    @State var peripherals: [SavedPeripheral] = []
    @State var rpm: Int32?

    var body: some View {
        NavigationView {
            VStack {
                List(self.peripherals, id: \.self.kind) { peripheral in
                    Text("\(peripheral.uuid) \(peripheral.kind.toString())")
                }

                Text("Merhaba Cycling")
                NavigationLink(destination: DevicesView(), label: {
                    Text("Bluetooth Devices")
                })

                NavigationLink(destination: TrackHistoryView(), label: { Text("Track History") })

                if self.track.tracking {
                    if let info = self.track.info {
                        Text("Accelerometer, \(info.accelerometer.x) \(info.accelerometer.y) \(info.accelerometer.z)")
                        Text("Gyro, \(info.gyro.x) \(info.gyro.y) \(info.gyro.z)")
                        Text("Location, \(info.speed)")
                    }

                    Button(action: {
                        track.stopTrack()
                    }, label: {
                        Text("Stop cycling")
                    })
                } else {
                    Button(action: {
                        track.startTrack()
                    }, label: {
                        Text("Start cycling")
                    })
                }
            }
        }
        .onAppear {
            self.bluetooth.start()

            self.tasks.append(Task {
                for await peripherals in StorageViewModel.peripherals() {
                    switch peripherals {
                    case .success(let p):
                        self.peripherals = p
                    case .failure(let error):
                        fatalError("Failed to fetch peripherals \(error)")
                    }
                }
            })
        }
        .onDisappear {
            for task in self.tasks {
                task.cancel()
            }
        }
    }
}
