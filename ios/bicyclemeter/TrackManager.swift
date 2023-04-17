import CoreLocation

enum TrackValue {
    case RPM(Int32)
}

class TrackManager: ObservableObject {
    @Published var tracking: Bool = false

    private let bluetooth: BluetoothManager

    private var location: CLLocationManager!
    private var stream: AsyncStream<TrackValue>?
    private var continuation: AsyncStream<TrackValue>.Continuation?

    init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
    }

    func startOrContinue() -> AsyncStream<TrackValue> {
        if self.location == nil {
            self.location = CLLocationManager()
        }

        if let stream = self.stream {
            return stream
        }

        let stream = AsyncStream<TrackValue> { continuation in
            self.continuation = continuation
        }

        self.stream = stream
        self.tracking = true

        return stream
    }

    func stop() {
        if let continuation = self.continuation {
            continuation.finish()
        }

        self.stream = nil
        self.continuation = nil
        self.location = nil
        self.tracking = false
    }
}
