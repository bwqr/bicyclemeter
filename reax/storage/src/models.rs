use serde::{Deserialize, Serialize};
use sled::Error;

#[derive(Debug, Deserialize, Serialize)]
pub struct TrackPoint {
    pub rpm: f64,
    pub slope: f64,
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
    pub points: Vec<TrackPoint>,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
pub enum PeripheralKind {
    Foot,
    Bicycle,
}

impl Into<&'static str> for &PeripheralKind {
    fn into(self) -> &'static str {
        match self {
            PeripheralKind::Foot => "Foot",
            PeripheralKind::Bicycle => "Bicycle",
        }
    }
}

#[derive(Debug, Deserialize, Serialize)]
pub struct SavedPeripheral {
    pub kind: PeripheralKind,
    pub uuid: String,
}

impl SavedPeripheral {
    pub fn key_for_kind(kind: &PeripheralKind) -> String {
        format!("peripheral_{}", Into::<&'static str>::into(kind))
    }

    pub fn load_all(db: &sled::Db) -> Result<Vec<SavedPeripheral>, Error> {
        let mut peripherals = vec![];

        if let Some(p) = Self::load_kind(db, &PeripheralKind::Foot)? {
            peripherals.push(p);
        }

        if let Some(p) = Self::load_kind(db, &PeripheralKind::Bicycle)? {
            peripherals.push(p);
        }

        Ok(peripherals)
    }

    pub fn load_kind(
        db: &sled::Db,
        kind: &PeripheralKind,
    ) -> Result<Option<SavedPeripheral>, Error> {
        db.get(Self::key_for_kind(&kind))
            .map(|opt| {
                opt.map(|ivec| SavedPeripheral {
                    kind: kind.clone(),
                    uuid: std::str::from_utf8(&ivec).unwrap().to_string(),
                })
            })
    }
}
