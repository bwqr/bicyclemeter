import CoreMotion
import Serde

struct Vec3<T: FloatingPoint> {
    let x: T
    let y: T
    let z: T

    func len() -> T {
        sqrt(x * x + y * y + z * z)
    }

    func scale(sc: T) -> Vec3<T> {
        return Vec3(x: x * sc, y: y * sc, z: z * sc)
    }

    func norm() -> Vec3<T> {
        let len = self.len()

        return Vec3(x: x / len, y: y / len, z: z / len)
    }

    func cross(vec: Vec3<T>) -> Vec3<T> {
        return Vec3(x: self.y * vec.z - self.z * vec.y, y: self.z * vec.x - self.x * vec.z, z: self.x * vec.y - self.y * vec.x)
    }

    func dot(vec: Vec3<T>) -> T {
        return x * vec.x + y * vec.y + z * vec.z
    }

    func project(vec: Vec3<T>) -> Vec3<T> {
        let unit = vec.norm()
        return unit.scale(sc: unit.dot(vec: self))
    }
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
