import CoreMotion
import Serde

struct Vec3<T> {
    let x: T
    let y: T
    let z: T
}

struct TrackData {
    public var accelerometer: Vec3<Double>
    public var gyro: Vec3<Double>
    public var speed: Double

    static func deserialize(_ deserializer: Deserializer) throws -> TrackData {
        try deserializer.increase_container_depth()
        let data = TrackData(
            accelerometer: Vec3(x: try deserializer.deserialize_f64(), y: try deserializer.deserialize_f64(), z: try deserializer.deserialize_f64()),
            gyro: Vec3(x: try deserializer.deserialize_f64(), y: try deserializer.deserialize_f64(), z: try deserializer.deserialize_f64()),
            speed: try deserializer.deserialize_f64()
        )

        try deserializer.decrease_container_depth()

        return data
    }

    func serialize(_ serializer: Serializer) throws {
        try serializer.increase_container_depth()
        try serializer.serialize_f64(value: self.accelerometer.x)
        try serializer.serialize_f64(value: self.accelerometer.y)
        try serializer.serialize_f64(value: self.accelerometer.z)
        try serializer.serialize_f64(value: self.gyro.x)
        try serializer.serialize_f64(value: self.gyro.y)
        try serializer.serialize_f64(value: self.gyro.z)
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
    let data: [TrackData]

    static func deserialize(_ deserializer: Deserializer) throws -> Track {
        try deserializer.increase_container_depth()

        let track = Track(header: try TrackHeader.deserialize(deserializer), data: try deserializeList(deserializer, deserialize: {
            try TrackData.deserialize($0)
        }))

        try deserializer.decrease_container_depth()

        return track
    }
}
