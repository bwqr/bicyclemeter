use base::State;
use serde::Serialize;
use storage::Error;
use tokio::task::JoinHandle;

use crate::{deserialize, spawn, Message};

type DeserializeHandler = unsafe extern "C" fn(*const u8, usize) -> *mut u8;

fn send_stream<T: Serialize>(stream_id: i32, message: Message<T, Error>) {
    crate::send_stream(stream_id, message)
}

#[no_mangle]
pub extern "C" fn reax_storage_init() {
    ::storage::init();
}

#[no_mangle]
pub extern "C" fn reax_storage_welcome_shown(f: DeserializeHandler) -> *mut u8 {
    let bytes = bincode::serialize(&::storage::welcome_shown()).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len()) }
}

#[no_mangle]
pub extern "C" fn reax_storage_show_welcome(f: DeserializeHandler) -> *mut u8 {
    let bytes = bincode::serialize(&::storage::show_welcome()).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len()) }
}

#[no_mangle]
pub extern "C" fn reax_storage_start_track(f: DeserializeHandler) -> *mut u8 {
    let bytes = bincode::serialize(&::storage::track::start_track()).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len()) }
}

#[no_mangle]
pub extern "C" fn reax_storage_delete_track(timestamp: i64, f: DeserializeHandler) -> *mut u8 {
    let bytes = bincode::serialize(&::storage::track::delete_track(timestamp)).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len()) }
}

#[no_mangle]
pub extern "C" fn reax_storage_stop_track(f: DeserializeHandler) -> *mut u8 {
    let bytes = bincode::serialize(&::storage::track::stop_track()).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len()) }
}

#[no_mangle]
pub extern "C" fn reax_storage_store_track_value(
    bytes: *const u8,
    size: isize,
    f: DeserializeHandler,
) -> *mut u8 {
    let value = unsafe { deserialize(bytes, size) };

    let bytes = bincode::serialize(&::storage::track::store_track_value(value)).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len()) }
}

#[no_mangle]
pub extern "C" fn reax_storage_tracks(f: DeserializeHandler) -> *mut u8 {
    let bytes = bincode::serialize(&::storage::track::tracks()).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len()) }
}

#[no_mangle]
pub extern "C" fn reax_storage_track(timestamp: i64, f: DeserializeHandler) -> *mut u8 {
    let bytes = bincode::serialize(&::storage::track::track(timestamp)).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len()) }
}

#[no_mangle]
pub extern "C" fn reax_storage_save_peripheral(bytes: *const u8, size: isize, f: DeserializeHandler) -> *mut u8 {
    let value = unsafe { deserialize(bytes, size) };

    let bytes = bincode::serialize(&::storage::save_peripheral(value)).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len()) }
}

#[no_mangle]
pub extern "C" fn reax_storage_peripherals(stream_id: i32) -> * mut JoinHandle<()> {
    let handle = spawn(async move {
        let mut rx = ::storage::peripherals().await;

        match &*rx.borrow() {
            State::Ok(ok) => send_stream(stream_id, Message::Ok(ok)),
            State::Err(e) => send_stream::<Error>(stream_id, Message::Err(e.clone())),
            _ => {},
        };

        while rx.changed().await.is_ok() {
            match &*rx.borrow() {
                State::Ok(ok) => send_stream(stream_id, Message::Ok(ok)),
                State::Err(e) => send_stream::<Error>(stream_id, Message::Err(e.clone())),
                _ => {},
            };
        }

        send_stream::<Vec<storage::models::SavedPeripheral>>(stream_id, Message::Complete);
    });

    Box::into_raw(Box::new(handle))
}
