import SwiftUI

struct TrackView: View {
    let timestamp: Int64
    @State var track: Track?

    init(timestamp: Int64) {
        self.timestamp = timestamp
    }

    var body: some View {
        VStack {
            if let t = track {
                Button(action: {
                    do {
                        try StorageViewModel.deleteTrack(timestamp)
                    } catch {
                        fatalError("Failed to delete track \(error)")
                    }
                }, label: {
                    Text("Delete the Track")
                })

                Text("\(t.header.version) \(t.header.timestamp) \(t.data.count)")

                ForEach(t.data, id: \.self.speed) { data in
                    Text("\(data.speed)")
                }

            }
        }
            .onAppear {
                do {
                    self.track = try TrackViewModel.track(timestamp: timestamp)
                } catch {
                    fatalError("Failed to fetch track \(error)")
                }
            }
    }
}
