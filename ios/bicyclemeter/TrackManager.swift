import CoreLocation

enum TrackValue {
    case RPM(Float32)
    case Slope(Float32)
    case Speed(Float32)
}

class TrackManager: ObservableObject {
    @Published var tracking: Bool = false

    private let bluetooth: BluetoothManager

    private var location: CLLocationManager!
    private var continuations: [Int:AsyncStream<TrackValue>.Continuation] = [:]
    private var observerTask: Task<(), Never>?

    init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
    }

    func startOrContinue() -> AsyncStream<TrackValue> {
        if self.location == nil {
            self.location = CLLocationManager()
        }

        if self.observerTask == nil {
            self.observerTask = Task {
                for await res in self.bluetooth.subscribe() {
                    var value = TrackValue.RPM(0)
                    switch res.0 {
                    case .Bicycle:
                        value = .Slope(Float32.random(in: 0.0...1024.0))
                    case .Foot:
                        value = .RPM(Float32.random(in: 0.0...1024.0))
                    }

                    for cont in self.continuations.values {
                        cont.yield(value)
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
        self.observerTask?.cancel()

        self.continuations = [:]
        self.location = nil
        self.tracking = false
        self.observerTask = nil
    }
}
