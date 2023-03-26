import SwiftUI

struct WelcomeView: View {
    let onClose: () -> ()

    init(onClose: @escaping () -> ()) {
        self.onClose = onClose
    }

    var body: some View {
            VStack {
                Text("Welcome to Bicyclemeter")
                Text("You can track your performance and analyze them")
                Text("Choose the Start Cycling to start tracking the performance metrics")
                Text("Or choose Show Previous Tracks to analyze previously recorded performance metrics")

                Button(action: { onClose() }, label: { Text("Start Tracking") })
        }
    }
}
