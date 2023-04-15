import SwiftUI
import CoreLocation
import CoreBluetooth

struct SafeContainer<T, Content: View> : View {
    @Binding var value: T?

    @ViewBuilder var content: (_ value: Binding<T>) -> Content

    var body: some View {
        if value != nil {
            content(Binding($value)!)
        } else {
            ZStack { }
        }
    }
}

struct ContentView: View {
    @State var showWelcomeView: Bool = false

    var body: some View {
        CyclingView()
            .sheet(isPresented: $showWelcomeView) {
                WelcomeView {
                    do {
                        try StorageViewModel.showWelcome()
                        showWelcomeView = false
                    } catch {
                        fatalError("Unhandled error \(error)")
                    }
                }
            }
            .onAppear {
                do {
                    showWelcomeView = !(try StorageViewModel.welcomeShown())
                } catch {
                    fatalError("Unhandled error \(error)")
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
