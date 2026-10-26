use sha2::{Digest, Sha256};
unsafe extern "C" {
    fn rustxc_asm() -> i32;
    fn rustxc_c() -> i32;
    fn rustxc_cpp(text: *const std::ffi::c_char) -> i32;
}
#[cfg(target_os = "linux")]
unsafe extern "C" {
    fn rustxc_discovery() -> *mut std::ffi::c_void;
}
fn main() {
    #[cfg(target_os = "linux")]
    std::hint::black_box(rustxc_discovery as unsafe extern "C" fn() -> *mut std::ffi::c_void);
    assert_eq!(unsafe { rustxc_asm() }, 42);
    assert_eq!(unsafe { rustxc_c() }, 8);
    assert_eq!(unsafe { rustxc_cpp(c"rustxc".as_ptr()) }, 6);
    let input = b"native C, C++ and assembly smoke test";
    let compressed = zstd::encode_all(&input[..], 1).unwrap();
    assert_eq!(zstd::decode_all(&compressed[..]).unwrap(), input);
    assert_eq!(
        Sha256::digest(b"abc").as_slice(),
        &[
            0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea, 0x41, 0x41, 0x40, 0xde, 0x5d, 0xae,
            0x22, 0x23, 0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c, 0xb4, 0x10, 0xff, 0x61,
            0xf2, 0x00, 0x15, 0xad
        ]
    );
}
