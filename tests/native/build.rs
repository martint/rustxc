fn main() {
    let mut c = cc::Build::new();
    if std::env::var("CARGO_CFG_TARGET_OS").unwrap() == "linux" {
        let expected_root =
            std::path::PathBuf::from("/opt/sysroots").join(std::env::var("TARGET").unwrap());
        for library in [
            "alsa",
            "libudev",
            "dbus-1",
            "wayland-client",
            "wayland-cursor",
            "wayland-egl",
            "x11",
            "xcursor",
            "xi",
            "xrandr",
            "xkbcommon",
            "xkbcommon-x11",
            "xcb",
            "egl",
            "vulkan",
        ] {
            let found = pkg_config::Config::new().probe(library).unwrap();
            c.includes(&found.include_paths);
            for path in found.include_paths.iter().chain(found.link_paths.iter()) {
                assert!(
                    path.starts_with(&expected_root),
                    "host path: {}",
                    path.display()
                );
            }
        }
    }
    c.file("native/probe.c").compile("probe_c");

    if std::env::var("CARGO_CFG_TARGET_ENV").unwrap() == "msvc" {
        // cc 1.2.41's clang-cl .S path writes an intermediate beside the source.
        // Drive LLVM's integrated assembler explicitly, keeping source read-only.
        let out = std::path::PathBuf::from(std::env::var_os("OUT_DIR").unwrap());
        let target = std::env::var("TARGET").unwrap();
        let assembler = std::env::var(format!("AS_{}", target.replace('-', "_"))).unwrap();
        let object = out.join("probe_asm.obj");
        assert!(
            std::process::Command::new(assembler)
                .args(["native/probe.S", "-o"])
                .arg(&object)
                .status()
                .unwrap()
                .success()
        );
        assert!(
            std::process::Command::new("llvm-lib")
                .arg(format!("/out:{}", out.join("probe_asm.lib").display()))
                .arg(&object)
                .status()
                .unwrap()
                .success()
        );
        println!("cargo:rustc-link-search=native={}", out.display());
        println!("cargo:rustc-link-lib=static=probe_asm");
    } else {
        cc::Build::new().file("native/probe.S").compile("probe_asm");
    }
    cc::Build::new()
        .cpp(true)
        .file("native/probe.cpp")
        .compile("probe_cpp");
    println!("cargo:rerun-if-changed=native");
}
