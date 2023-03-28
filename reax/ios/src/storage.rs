use crate::deserialize;

type DeserializeHandler = unsafe extern "C" fn(*const u8, usize) -> *mut u8;

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
