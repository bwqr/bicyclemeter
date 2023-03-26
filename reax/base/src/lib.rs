use std::{any::Any, sync::RwLock};

use once_cell::sync::OnceCell;

#[derive(Debug)]
pub struct Config {
    pub storage_dir: String,
}

struct Runtime {
    types: anymap::Map<dyn Any + Sync + Send>,
}

static RUNTIME: OnceCell<RwLock<Runtime>> = OnceCell::new();

pub fn init() {
    RUNTIME
        .set(RwLock::new(Runtime {
            types: anymap::Map::new(),
        }))
        .map_err(|_| "Failed to set runtime")
        .unwrap();
}

pub fn get<T: Clone + Send + Sync + 'static>() -> T {
    let runtime = RUNTIME.get().unwrap().read().unwrap();

    runtime.types.get::<T>().map(|value| value.clone()).unwrap()
}

pub fn put<T: Send + Sync + 'static>(value: T) {
    RUNTIME.get().unwrap().write().unwrap().types.insert(value);
}
