import SwiftUI
import CoreLocation
import CoreBluetooth

class BluetootManager: NSObject, CBCentralManagerDelegate {
    var central: CBCentralManager

    init(_ central: CBCentralManager) {
        self.central = central
        super.init()
        central.delegate = self
    }

    func scanPeripherals() {
        if case .poweredOn = self.central.state {
            self.central.scanForPeripherals(withServices: nil)
        } else {
            print("Please open the bluetooth first")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("\(central.state)")
    }
}

struct ContentView: View {
    var bluetoothManager = BluetootManager(CBCentralManager())
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
