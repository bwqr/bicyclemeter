import SwiftUI

struct TrackHistoryView: View {
    @State var tracks: [String] = []

    var body: some View {
        VStack {
            List(tracks, id: \.self) { track in
                NavigationLink(destination: TrackView(timestamp: Int64(track)!), label: {
                    Text(track)
                })
            }
        }.onAppear {
            do {
                tracks = try TrackViewModel.tracks()
            } catch {
                fatalError("Failed to fetch tracks \(error)")
            }
        }
    }
}
