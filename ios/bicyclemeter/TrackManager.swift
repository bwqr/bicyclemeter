import CoreLocation

enum TrackValue {
    case RPM(Int32)
}

class TrackManager: ObservableObject {
    @Published var tracking: Bool = false

    private let bluetooth: BluetoothManager

    private var location: CLLocationManager!
    private var continuations: [Int:AsyncStream<TrackValue>.Continuation] = [:]
    private var peripheralsTask: Task<(), Never>?
    private var timer: Timer?

    init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
    }

    func startOrContinue() -> AsyncStream<TrackValue> {
        if self.location == nil {
            self.location = CLLocationManager()
        }

        self.timer = Timer(timeInterval: 2.0, repeats: true) { _ in
            for cont in self.continuations.values {
                cont.yield(.RPM(Int32.random(in: 0...1024)))
            }
        }
        RunLoop.current.add(self.timer!, forMode: .default)

        if self.peripheralsTask == nil {
            self.peripheralsTask = Task {
                var previousPeriphs: [SavedPeripheral] = []

                for await result in StorageViewModel.peripherals() {
                    for prev in previousPeriphs {
                        self.bluetooth.cancelConnection(prev.uuid)
                    }

                    switch result {
                    case .success(let peripherals):
                        previousPeriphs = peripherals

                        for periph in peripherals {
                            if case .failure(let error) =  await self.bluetooth.connectPeripheral(periph.uuid) {
                                print("Failed to connect to peripheral \(periph.uuid) in TrackManager, \(error)")
                            }
                        }
                    case .failure(let error):
                        fatalError("Failed to fetch peripherals \(error)")
                    }
                }
            }
        }

        self.tracking = true

        return AsyncStream<TrackValue> { continuation in
            var contKey = 0
            while self.continuations.index(forKey: contKey) != nil {
                contKey += 1
            }
            let key = contKey

            continuation.onTermination = { _ in
                self.continuations.removeValue(forKey: key)
            }

            self.continuations[key] = continuation
        }
    }

    func stop() {
        for cont in self.continuations.values {
            cont.finish()
        }
        self.peripheralsTask?.cancel()
        self.timer?.invalidate()

        self.continuations = [:]
        self.location = nil
        self.tracking = false
        self.peripheralsTask = nil
        self.timer = nil
    }
}
