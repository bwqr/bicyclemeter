use std::sync::Arc;

use serde::Serialize;

pub mod models;
pub mod track;

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

impl From<std::io::Error> for Error {
    fn from(value: std::io::Error) -> Self {
        Error::Message(format!("IO Error {value:?}"))
    }
}

pub fn init() {
    track::init();
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
