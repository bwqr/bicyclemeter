use std::{io::Write, sync::Arc};

use base::Config;
use serde::Serialize;

static TRACK_FILE: std::sync::Mutex<Option<std::fs::File>> = std::sync::Mutex::new(None);

#[derive(Debug, Serialize)]
pub enum Error {
    Db,
    Message(String),
}

impl From<sled::Error> for Error {
    fn from(_: sled::Error) -> Self {
        Error::Db
    }
}

pub fn init() {
    log::debug!("storage is initialized");
}

pub fn welcome_shown() -> Result<bool, Error> {
    base::get::<Arc<sled::Db>>()
        .contains_key(b"welcome_shown")
        .map_err(|_| Error::Db)
}

pub fn show_welcome() -> Result<(), Error> {
    let db = base::get::<Arc<sled::Db>>();

    db.insert(b"welcome_shown", b"")?;
    db.flush()?;

    Ok(())
}

pub fn start_track() -> Result<(), Error> {
    let config = base::get::<Arc<Config>>();
    let now = chrono::Utc::now();
    let mut track_file = TRACK_FILE.lock().unwrap();

    if track_file.is_some() {
        return Err(Error::Message("Track is already started".to_string()));
    }

    let file = std::fs::File::create(format!("{}/track_{}", config.storage_dir, now.timestamp()))
        .map_err(|e| Error::Message(format!("{e:?}")))?;

    track_file.replace(file);

    Ok(())
}

pub fn stop_track() -> Result<(), Error> {
    TRACK_FILE.lock().unwrap().take();

    Ok(())
}

pub fn store_track_value(acc_x: f64, acc_y: f64, acc_z: f64) -> Result<(), Error> {
    let lock = TRACK_FILE.lock().unwrap();

    let mut track_file = lock
        .as_ref()
        .ok_or(Error::Message("Track is not started".to_string()))?;

    track_file
        .write(&bincode::serialize(&(acc_x, acc_y, acc_z)).unwrap())
        .map(|_| ())
        .map_err(|e| Error::Message(format!("{e:?}")))
}

pub fn tracks() -> Result<Vec<String>, Error> {
    let config = base::get::<Arc<Config>>();

    Ok(std::fs::read_dir(&config.storage_dir)
        .unwrap()
        .map(|res| res.unwrap().file_name().to_string_lossy().to_string())
        .collect())
}
