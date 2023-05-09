use std::sync::Arc;

use base::State;
use models::{PeripheralKind, SavedPeripheral};
use once_cell::sync::OnceCell;
use serde::Serialize;
use tokio::sync::watch::{channel, Sender};

pub mod models;
pub mod track;

static SAVED_PERIPHERALS: OnceCell<Sender<State<Vec<SavedPeripheral>, Error>>> = OnceCell::new();

#[derive(Clone, Debug, Serialize)]
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

    SAVED_PERIPHERALS.set(channel(State::default()).0).unwrap();

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

pub async fn peripherals() -> tokio::sync::watch::Receiver<State<Vec<SavedPeripheral>, Error>> {
    let sender = SAVED_PERIPHERALS.get().unwrap();
    let load = match *sender.borrow() {
        State::Initial | State::Err(_) => true,
        _ => false,
    };

    if load {
        let db = base::get::<Arc<sled::Db>>();

        sender.send_replace(State::Ok(SavedPeripheral::load_all(&db).unwrap()));
    }

    sender.subscribe()
}

pub fn save_peripheral(peripheral: SavedPeripheral) -> Result<(), Error> {
    let db = base::get::<Arc<sled::Db>>();

    let remove_if_equal = |kind: PeripheralKind| -> Result<(), Error> {
        if let Some(p) = SavedPeripheral::load_kind(&db, &kind)? {
            if peripheral.uuid == p.uuid  {
                db.remove(&SavedPeripheral::key_for_kind(&kind))?;
            }
        }

        Ok(())
    };

    remove_if_equal(PeripheralKind::Bicycle).unwrap();
    remove_if_equal(PeripheralKind::Foot).unwrap();

    db.insert(
        SavedPeripheral::key_for_kind(&peripheral.kind),
        peripheral.uuid.as_str(),
    )
    .unwrap();
    db.flush().unwrap();

    SAVED_PERIPHERALS.get().unwrap().send_modify(move |state| {
        *state = State::Ok(SavedPeripheral::load_all(&db).unwrap());
    });

    Ok(())
}
