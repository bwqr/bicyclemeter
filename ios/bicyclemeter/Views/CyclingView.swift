import SwiftUI

struct CyclingView: View {
    @ObservedObject var track = TrackViewModel()

    var body: some View {
        NavigationView {
            VStack {
                Text("Merhaba Cycling")

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
    }
}
