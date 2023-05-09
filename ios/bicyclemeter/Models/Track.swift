import CoreMotion
import Serde

struct Vec3<T> {
    let x: T
    let y: T
    let z: T
}

struct TrackPoint {
    public var rpm: Double
    public var slope: Double
    public var speed: Double

    static func deserialize(_ deserializer: Deserializer) throws -> TrackPoint {
        try deserializer.increase_container_depth()
        let data = TrackPoint(
            rpm: try deserializer.deserialize_f64(),
            slope: try deserializer.deserialize_f64(),
            speed: try deserializer.deserialize_f64()
        )

        try deserializer.decrease_container_depth()

        return data
    }

    func serialize(_ serializer: Serializer) throws {
        try serializer.increase_container_depth()
        try serializer.serialize_f64(value: self.rpm)
        try serializer.serialize_f64(value: self.slope)
        try serializer.serialize_f64(value: self.speed)
        try serializer.decrease_container_depth()
    }
}

struct TrackHeader {
    let version: Int32
    let timestamp: Int64

    static func deserialize(_ deserializer: Deserializer) throws -> TrackHeader {
        try deserializer.increase_container_depth()

        let header = TrackHeader(version: try deserializer.deserialize_i32(), timestamp: try deserializer.deserialize_i64())

        try deserializer.decrease_container_depth()

        return header
    }
}

struct Track {
    let header: TrackHeader
    let points: [TrackPoint]

    static func deserialize(_ deserializer: Deserializer) throws -> Track {
        try deserializer.increase_container_depth()

        let track = Track(header: try TrackHeader.deserialize(deserializer), points: try deserializeList(deserializer, deserialize: {
            try TrackPoint.deserialize($0)
        }))

        try deserializer.decrease_container_depth()

        return track
    }
}
