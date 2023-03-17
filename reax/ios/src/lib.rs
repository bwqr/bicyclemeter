use std::ffi::{c_char, CString};

#[no_mangle]
pub extern "C" fn reax_init() {
    println!("Hello world");
}

#[no_mangle]
pub extern "C" fn reax_message() -> * const c_char {
    let message = Box::new(CString::new("Hello, world mu acaba!").unwrap());
    let ptr = message.as_ptr().clone();
    Box::leak(message);

    ptr
}
