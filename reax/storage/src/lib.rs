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
        let read_kind = |kind: PeripheralKind| -> Option<SavedPeripheral> {
            if let Ok(Some(ivec)) = db.get(format!(
                "peripheral_{}",
                Into::<&'static str>::into(&kind)
            )) {
                Some(SavedPeripheral {
                    kind,
                    uuid: std::str::from_utf8(&ivec).unwrap().to_string(),
                })
            } else {
                None
            }
        };

        let mut saved_peripherals = vec![];

        if let Some(saved_peripheral) = read_kind(PeripheralKind::Bicycle) {
            saved_peripherals.push(saved_peripheral);
        }
        if let Some(saved_peripheral) = read_kind(PeripheralKind::Foot) {
            saved_peripherals.push(saved_peripheral);
        }

        sender.send_replace(State::Ok(saved_peripherals));
    }

    sender.subscribe()
}

pub fn save_peripheral(peripheral: SavedPeripheral) -> Result<(), Error> {
    let db = base::get::<Arc<sled::Db>>();

    db.insert(
        format!(
            "peripheral_{}",
            Into::<&'static str>::into(&peripheral.kind)
        ),
        peripheral.uuid.as_str(),
    )
    .unwrap();
    db.flush().unwrap();

    SAVED_PERIPHERALS.get().unwrap().send_modify(move |state| {
        if let State::Ok(peripherals) = state {
            if let Some(per) = peripherals.iter_mut().find(|p| p.kind == peripheral.kind) {
                *per = peripheral;
            } else {
                peripherals.push(peripheral);
            }
        }
    });

    Ok(())
}
