import SwiftUI

struct CyclingView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @EnvironmentObject var track: TrackManager

    @State var tasks: [Task<(), Never>] = []
    @State var rpm: Float32?
    @State var slope: Float32?
    @State var speed: Float32?

    var body: some View {
        _CyclingView(
            tracking: track.tracking,
            rpm: self.rpm,
            slope: self.slope,
            speed: self.speed,
            onToggleCycling: {
                if self.track.tracking {
                    self.track.stop()
                } else {
                    self.startTrackingTask()
                }
            }
        )
        .onAppear {
            self.startScanningTask()

            if self.track.tracking {
                self.startTrackingTask()
            }
        }
        .onDisappear {
            for task in self.tasks {
                task.cancel()
            }
        }
    }

    func startTrackingTask() {
        self.tasks.append(Task {
            for await value in self.track.startOrContinue() {
                switch value {
                case .RPM(let rpm):
                    self.rpm = rpm
                case .Slope(let slope):
                    self.slope = slope
                case .Speed(let speed):
                    self.speed = speed
                }
            }
        })
    }

    func startScanningTask() {
        self.tasks.append(Task {
            for await result in StorageViewModel.peripherals() {
                switch result {
                case .success(let peripherals):
                    self.bluetooth.connectSavedPeripherals(peripherals)
                case .failure(let error):
                    fatalError("Failed to fetch peripherals, \(error)")
                }
            }
        })
    }
}

private struct _CyclingView: View {
    let tracking: Bool
    let rpm: Float32?
    let slope: Float32?
    let speed: Float32?
    let onToggleCycling: () -> ()

    var body: some View {
        VStack {
            HStack {
                Text("RPM \(self.rpm ?? 0)")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Speed \(self.speed ?? 0)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            Button(action: {
                self.onToggleCycling()
            }) {
                Text(self.tracking ? "Stop Cycling" : "Start Cycling")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(self.tracking ? .red : .blue)
            .cornerRadius(8)
        }
        .padding([.leading, .trailing, .bottom], 18)
        .navigationTitle("Cycling")

    }
}

struct CyclincView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            _CyclingView(
                tracking: false,
                rpm: nil,
                slope: nil,
                speed: nil,
                onToggleCycling: { }
            )
        }
    }
}
