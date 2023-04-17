import SwiftUI

struct CyclingView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @EnvironmentObject var track: TrackManager

    @State var tasks: [Task<(), Never>] = []
    @State var peripherals: [SavedPeripheral] = []
    @State var trackingTask: Task<(), Never>?
    @State var rpm: Int32?
    @State var speed: Int32?

    var body: some View {
        _CyclingView(
            tracking: track.tracking,
            rpm: self.rpm,
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
            if self.track.tracking {
                self.startTrackingTask()
            }
        }
        .onDisappear {
            self.trackingTask?.cancel()
            self.trackingTask = nil
        }
    }

    func startTrackingTask() {
        self.trackingTask = Task {
            for await value in self.track.startOrContinue() {
                switch value {
                case .RPM(let rpm):
                    self.rpm = rpm
                }
            }
        }

    }
}

private struct _CyclingView: View {
    let tracking: Bool
    let rpm: Int32?
    let speed: Int32?
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
                tracking: true,
                rpm: nil,
                speed: nil,
                onToggleCycling: { }
            )
        }
    }
}
