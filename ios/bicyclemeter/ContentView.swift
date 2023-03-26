import SwiftUI
import CoreLocation
import CoreBluetooth

class LocationManager : NSObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager
    private var trackSpeed = false

    init(_ manager: CLLocationManager) {
        self.manager = manager
        super.init()
        manager.delegate = self
    }

    func startSpeedTracking() {
        trackSpeed = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            break
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            break
        default:
            print("\(manager.authorizationStatus)")
        }
    }

    func stopSpeedTracking() {
        trackSpeed = false
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if trackSpeed, case .authorizedWhenInUse = manager.authorizationStatus {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("Received locations", locations.count)
        for location in locations {
            print("Speed \(location.speed)")
        }
    }
}

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
    var locationManager = LocationManager(CLLocationManager())
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
