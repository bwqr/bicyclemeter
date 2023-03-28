use std::{io::Write, sync::Arc};

use base::Config;

use crate::{Error, models::{Track, TrackHeader, TrackData}};

const FILE_SCHEME_VERSION: i32 = 1;

static TRACK_FILE: std::sync::Mutex<Option<(std::fs::File, i64)>> = std::sync::Mutex::new(None);

pub fn init() {
    let config = base::get::<Arc<Config>>();

    match std::fs::create_dir(format!("{}/tracks", config.storage_dir)) {
        Ok(_) => {},
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {},
        e => e.unwrap(),
    }

    if let Ok(track_file) = std::fs::File::open(format!("{}/active_track", config.storage_dir)) {
        log::debug!("found an old active_track, moving it into its own file");

        let (_, timestamp) = bincode::deserialize_from::<_, (i32, i64)>(&track_file).unwrap();

        drop(track_file);

        std::fs::rename(
            format!("{}/active_track", config.storage_dir),
            format!("{}/tracks/{}", config.storage_dir, timestamp),
        )
        .unwrap();
    }
}

pub fn start_track() -> Result<(), Error> {
    let config = base::get::<Arc<Config>>();
    let timestamp = chrono::Utc::now().timestamp();
    let mut track_file = TRACK_FILE.lock().unwrap();

    if track_file.is_some() {
        return Err(Error::Message("Track is already started".to_string()));
    }

    let mut file = std::fs::File::create(format!("{}/active_track", config.storage_dir))?;

    file.write(&bincode::serialize(&FILE_SCHEME_VERSION).unwrap())?;
    file.write(&bincode::serialize(&timestamp).unwrap())?;

    track_file.replace((file, timestamp));

    Ok(())
}

pub fn stop_track() -> Result<(), Error> {
    if let Some((track_file, timestamp)) = TRACK_FILE.lock().unwrap().take() {
        drop(track_file);

        let config = base::get::<Arc<Config>>();

        std::fs::rename(
            format!("{}/active_track", config.storage_dir),
            format!("{}/tracks/{}", config.storage_dir, timestamp),
        )?;
    }

    Ok(())
}

pub fn delete_track(timestampt: i64) -> Result<(), Error> {
    let config = base::get::<Arc<Config>>();

    std::fs::remove_file(format!("{}/tracks/{}", config.storage_dir, timestampt))
        .map_err(|e| Error::Message(format!("IO error {e:?}")))
}

pub fn store_track_value(track_data: TrackData) -> Result<(), Error> {
    let lock = TRACK_FILE.lock().unwrap();

    log::debug!("received track_data {track_data:?}");

    let mut track_file = &lock
        .as_ref()
        .ok_or(Error::Message("Track is not started".to_string()))?
        .0;

    track_file
        .write(&bincode::serialize(&bincode::serialize(&track_data).unwrap()).unwrap())
        .map(|_| ())
        .map_err(|e| Error::Message(format!("{e:?}")))
}

pub fn tracks() -> Result<Vec<String>, Error> {
    let config = base::get::<Arc<Config>>();

    Ok(std::fs::read_dir(&format!("{}/tracks", config.storage_dir))
        .unwrap()
        .map(|res| res.unwrap().file_name().to_string_lossy().to_string())
        .collect())
}

pub fn track(timestamp: i64) -> Result<Track, Error> {
    let config = base::get::<Arc<Config>>();

    let file = std::fs::File::open(format!("{}/tracks/{}", config.storage_dir, timestamp))?;
    let header = bincode::deserialize_from::<_, TrackHeader>(&file).unwrap();
    let mut track_data = Vec::new();

    while let Ok(data) = bincode::deserialize_from::<_, TrackData>(&file) {
        track_data.push(data);
    }

    Ok(Track { header, data: track_data })
}
