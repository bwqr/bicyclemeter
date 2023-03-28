use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize)]
pub struct TrackData {
    pub acc_x: f64,
    pub acc_y: f64,
    pub acc_z: f64,
    pub gyro_x: f64,
    pub gyro_y: f64,
    pub gyro_z: f64,
    pub speed: f64,
}

#[derive(Deserialize, Serialize)]
pub struct TrackHeader {
    pub version: i32,
    pub timestamp: i64,
}

#[derive(Serialize)]
pub struct Track {
    pub header: TrackHeader,
    pub data: Vec<TrackData>,
}
