import SwiftUI

struct CyclingView: View {
    @ObservedObject var track = TrackViewModel()

    var body: some View {
        NavigationView {
            VStack {
                Text("Merhaba Cycling")

                NavigationLink(destination: HistoryView(), label: { Text("Track History") })

                Button(action: {
                    if self.track.tracking {
                        track.stopTrack()
                    } else {
                        track.startTrack()
                    }
                }, label: {
                    if self.track.tracking {
                        Text("Stop cycling")
                    } else {
                        Text("Start cycling")
                    }
                })
            }
        }
    }
}
