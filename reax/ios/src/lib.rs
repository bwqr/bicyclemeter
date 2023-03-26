use std::{ffi::{c_char, CStr, c_void, c_int, c_uchar}, sync::{Arc, Mutex, mpsc::Sender}, future::Future};

use once_cell::sync::OnceCell;
use serde::Serialize;
use tokio::task::JoinHandle;

mod storage;

static ASYNC_RUNTIME: OnceCell<tokio::runtime::Runtime> = OnceCell::new();
static HANDLER: OnceCell<Mutex<Sender<(i32, bool, Vec<u8>)>>> = OnceCell::new();

#[derive(Serialize)]
enum Message<T: Serialize, E: Serialize> {
    Ok(T),
    Err(E),
    Complete,
}

pub(crate) fn send_stream<T: Serialize, E: Serialize>(stream_id: i32, message: Message<T, E>) {
    let bytes = bincode::serialize(&message).expect("failed to searialize message");

    HANDLER
        .get()
        .unwrap()
        .lock()
        .unwrap()
        .send((stream_id, true, bytes))
        .unwrap();
}

pub(crate) fn send_once<T: Serialize, E: Serialize>(once_id: i32, message: Result<T, E>) {
    let bytes = bincode::serialize(&message).expect("failed to searialize message");

    HANDLER
        .get()
        .unwrap()
        .lock()
        .unwrap()
        .send((once_id, false, bytes))
        .unwrap();
}

pub fn spawn<F>(future: F) -> JoinHandle<F::Output>
where
    F: Future + Send + 'static,
    F::Output: Send + 'static,
{
    ASYNC_RUNTIME.get().unwrap().spawn(future)
}

#[no_mangle]
pub extern "C" fn reax_init(storage_dir: *const c_char) {
    let storage_dir = unsafe { CStr::from_ptr(storage_dir).to_str().unwrap().to_string() };

    std::env::set_var("RUST_LOG", "debug");
    env_logger::init();

    ASYNC_RUNTIME
        .set(
            tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
                .expect("failed to initialize tokio runtime"),
        )
        .expect("failed to set tokio runtime");

    let db = sled::Config::new()
        .flush_every_ms(Some(500))
        .path(format!("{}/app.db", storage_dir))
        .open()
        .unwrap();

    base::init();

    base::put::<Arc<sled::Db>>(Arc::new(db));

    base::put::<Arc<base::Config>>(Arc::new(base::Config {
        storage_dir,
    }));

    ::log::info!("reax runtime is initialized");
}

#[no_mangle]
pub extern fn reax_init_handler(ptr: *const c_void, f: unsafe extern fn(c_int, c_uchar, *const c_uchar, c_int, *const c_void)) {
    let (send, recv) = std::sync::mpsc::channel();

    HANDLER
        .set(Mutex::new(send))
        .map_err(|_| "HandlerError")
        .expect("failed to set handler");

    while let Ok((wait_id, ok, bytes)) = recv.recv() {
        unsafe { f(wait_id, ok as c_uchar, bytes.as_ptr(), bytes.len() as c_int, ptr) }
    }
}

#[no_mangle]
pub extern "C" fn reax_abort(pointer: * mut c_void) {
    let handle = unsafe { Box::from_raw(pointer as * mut tokio::task::JoinHandle<()>) };

    ::log::debug!("received abort, {:p}", handle);

    handle.abort();
}
