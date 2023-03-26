import SwiftUI

@main
struct bicyclemeterApp: App {
    init() {
        do {
            let appSupportDir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

            Runtime.initialize(storageDir: appSupportDir.path)
            StorageViewModel.initialize()
        } catch {
            print(error)
            fatalError("Unable to create application support directory")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
