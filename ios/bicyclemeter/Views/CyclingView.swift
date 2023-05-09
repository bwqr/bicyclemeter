import SwiftUI

struct CyclingView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @EnvironmentObject var track: TrackManager

    @State var tasks: [Task<(), Never>] = []
    @State var optionalTrackPoint: OptionalTrackPoint = OptionalTrackPoint()

    var body: some View {
        _CyclingView(
            tracking: self.track.tracking,
            rpmHistory: self.track.history.map { $0.rpm },
            slopeHistory: self.track.history.map { $0.slope },
            speedHistory: self.track.history.map { $0.speed },
            rpm: self.optionalTrackPoint.rpm,
            slope: self.optionalTrackPoint.slope,
            speed: self.optionalTrackPoint.speed,
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
            for task in self.tasks {
                task.cancel()
            }
        }
    }

    func startTrackingTask() {
        self.tasks.append(Task {
            for await value in self.track.startOrContinue() {
                self.optionalTrackPoint = value
            }
        })
    }
}

private struct HistogramTitle: View {
    let title: String
    let value: Double?

    var body: some View {
        HStack {
            Text(title)
                .padding(EdgeInsets(top: 4.0, leading: 8.0, bottom: 4.0, trailing: 8.0))
                .background(.green)
                .foregroundColor(.white)
                .cornerRadius(8.0)
                .font(.headline)
            Spacer()
            Text("\(self.value.map { $0.formatted() } ?? "-")")
        }
        .padding(EdgeInsets(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 8.0))
    }
}

private struct _CyclingView: View {
    let tracking: Bool
    let rpmHistory: [Double]
    let slopeHistory: [Double]
    let speedHistory: [Double]
    let rpm: Double?
    let slope: Double?
    let speed: Double?
    let onToggleCycling: () -> ()

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 48.0) {
                    VStack {
                        HistogramTitle(title: "RPM", value: self.rpm)
                            .zIndex(10.0)
                        HistoryChartView(maxPoints: 10.0, range: (0.0, 60.0), points: rpmHistory)
                            .frame(height: 120.0)
                    }
                    .clipped()

                    VStack {
                        HistogramTitle(title: "Slope", value: self.slope)
                            .zIndex(10.0)
                        HistoryChartView(maxPoints: 10.0, range: (-90.0, 90.0), points: slopeHistory)
                            .frame(height: 120.0)
                    }
                    .clipped()

                    VStack {
                        HistogramTitle(title: "Speed", value: self.speed)
                            .zIndex(10.0)
                        HistoryChartView(maxPoints: 10.0, range: (0.0, 90.0), points: speedHistory)
                            .frame(height: 120.0)
                    }
                    .clipped()
                }
                .padding(EdgeInsets(top: 0.0, leading: 8.0, bottom: 0.0, trailing: 0.0))
            }

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
            .padding([.leading, .trailing, .bottom], 18)
        }
        .navigationTitle("Cycling")
    }
}

struct CyclincView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            _CyclingView(
                tracking: false,
                rpmHistory: [80.0, 100.0, 86.0, 96.0, 95.0, 90.0, 82.0, 95.0, 0.0, 32.0, 30.0],
                slopeHistory: [-42.0, 41.0, 40.0, 10.0, 45.0],
                speedHistory: [42.0, 41.0, 40.0, 10.0, 45.0],
                rpm: nil,
                slope: nil,
                speed: nil,
                onToggleCycling: { }
            )
        }
    }
}
