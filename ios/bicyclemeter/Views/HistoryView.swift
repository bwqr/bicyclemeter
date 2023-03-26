import SwiftUI

struct HistoryView: View {
    @State var tracks: [String] = []

    var body: some View {
        VStack {
            ForEach(tracks, id: \.self) { track in
                Text(track)
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
