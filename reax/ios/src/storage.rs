use std::ffi::{c_int, c_uchar, c_double};

use crate::spawn;

type DeserializeHandler = unsafe extern "C" fn(*const c_uchar, c_int) -> *mut c_uchar;

#[no_mangle]
pub extern "C" fn reax_storage_init() {
    ::storage::init();
}

#[no_mangle]
pub extern "C" fn reax_storage_welcome_shown(f: DeserializeHandler) -> *mut c_uchar {
    let bytes = bincode::serialize(&::storage::welcome_shown()).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len() as c_int) }
}

#[no_mangle]
pub extern "C" fn reax_storage_show_welcome(f: DeserializeHandler) -> *mut c_uchar {
    let bytes = bincode::serialize(&::storage::show_welcome()).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len() as c_int) }
}

#[no_mangle]
pub extern "C" fn reax_storage_start_track(f: DeserializeHandler) -> *mut c_uchar {
    let bytes = bincode::serialize(&::storage::start_track()).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len() as c_int) }
}

#[no_mangle]
pub extern "C" fn reax_storage_stop_track(f: DeserializeHandler) -> *mut c_uchar {
    let bytes = bincode::serialize(&::storage::stop_track()).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len() as c_int) }
}

#[no_mangle]
pub extern "C" fn reax_storage_store_track_value(acc_x: c_double, acc_y: c_double, acc_z: c_double, f: DeserializeHandler) -> *mut c_uchar {
    let bytes = bincode::serialize(&::storage::store_track_value(acc_x, acc_y, acc_z)).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len() as c_int) }
}

#[no_mangle]
pub extern "C" fn reax_storage_tracks(f: DeserializeHandler) -> *mut c_uchar {
    let bytes = bincode::serialize(&::storage::tracks()).unwrap();

    unsafe { f(bytes.as_ptr(), bytes.len() as c_int) }
}
