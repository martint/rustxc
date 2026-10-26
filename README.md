# rustxc

Cross-compile Rust applications and native dependencies from Linux ARM64 or
AMD64 containers. Targets:

* `aarch64-unknown-linux-gnu`
* `x86_64-unknown-linux-gnu`
* `powerpc64le-unknown-linux-gnu`
* `aarch64-apple-darwin`
* `x86_64-apple-darwin`
* `x86_64-pc-windows-msvc`
* `aarch64-pc-windows-msvc`

Build locally with `docker build -t rustxc:local .`. The image contains GCC/G++,
binutils, LLVM 19/Clang/lld (including integrated assemblers, `llvm-lib`, `llvm-rc`,
and executable inspection tools), CMake, Ninja, NASM and target pkg-config wrappers.
`build-target` installs the target standard library for the **active** Rust
version, then uses Cargo, or cargo-xwin for MSVC. Rust 1.97.1, rustfmt, clippy and all seven target
standard libraries are preinstalled. Other `rust-toolchain.toml` versions and
`RUSTUP_TOOLCHAIN` overrides work through rustup; first use needs network access.
Use an image digest rather than `latest` for reproducible project builds.

## Build a project

Mount your project at `/mnt`. Source can be mounted read-only when Cargo outputs
are stored separately. Do not mount a host `CARGO_HOME`, which could replace the
image's Cargo configuration/tools.

```sh
docker build -t rustxc:local .
mkdir -p /tmp/rustxc-build
# Run from your Rust project's directory:
docker run --rm -v "$PWD:/mnt:ro" -v /tmp/rustxc-build:/build \
  -e CARGO_TARGET_DIR=/build/target rustxc:local \
  build-target aarch64-unknown-linux-gnu --locked --release
```

Replace the target with any target listed above. Cargo package, binary and feature
selection flags can follow `--release`, for example `-p my-package --bin my-app`.
For either Windows target, persist the SDK/CRT download cache in a named volume:

```sh
docker run --rm -v "$PWD:/mnt:ro" -v /tmp/rustxc-build:/build \
  -v rustxc-xwin:/opt/xwin -e CARGO_TARGET_DIR=/build/target rustxc:local \
  build-target aarch64-pc-windows-msvc --locked --release
```

Executables are in `/tmp/rustxc-build/target/<target>/release/` (`.exe` on
Windows). `cargo xwin build --locked --release --target <MSVC target> ...` is
also supported. Plain `cargo build` works for Linux/macOS after installing the
active toolchain's target with rustup. Windows requires cargo-xwin.

## Native libraries and baselines

Linux baseline: **Debian 12, glibc 2.36**, Linux kernel 4.18 or newer
(the selected deployment baseline). Each target gets its own Debian dependency
closure under `/opt/sysroots/<target>`. Compiler wrappers pass an explicit
sysroot and clear ambient header/library search variables. Target-qualified
pkg-config wrappers replace both `PKG_CONFIG_LIBDIR` and `PKG_CONFIG_PATH`, set
`PKG_CONFIG_SYSROOT_DIR`, and never search host `.pc` files. Clang/lld use GCC runtime and C++ support selected
explicitly from inside the target sysroot; GCC cross compilers and binutils are also available.
Do not pass host `-I`/`-L` paths or override the supplied target compilers.

The sysroots include ALSA, udev, D-Bus, Wayland client/cursor/EGL, X11/XCB and
extensions, xkbcommon (including X11), EGL/OpenGL and Vulkan headers/import libraries.
These support common desktop audio, gamepad, windowing and clipboard dependencies.
Additional native dependencies must be built for the target and its deployment
baseline; host installations cannot substitute for target libraries.

Linux system libraries remain **external at runtime**, including glibc, libgcc,
libstdc++ when used, ALSA, udev, Wayland, X11/XCB extensions, xkbcommon, and the
Vulkan/EGL/OpenGL loader and suitable GPU drivers. Some are loaded with dlopen
and do not appear in ELF `NEEDED`. A working desktop session, audio device/server,
udev device access, an XDG desktop portal with a file chooser backend, and
`libdbus-1.so.3` are runtime requirements for applications that use them. Portal-based file dialogs
need a desktop portal backend implementing the file chooser interface; applications
may also require tools such as Zenity for fallback dialogs. Libraries loaded with
`dlopen` must be checked separately from ELF `NEEDED`. Sysroot drivers are not
application redistribution assets.
`inspect` reports ELF machine, NEEDED and symbol versions and rejects glibc
requirements newer than 2.36. The baseline is for the binary's dependency ABI;
packaging newer replacement libraries can raise it.

macOS baseline: **11.0 for both architectures**, SDK 14.5. Both Rust and native
compiler invocations use `MACOSX_DEPLOYMENT_TARGET=11.0`; Clang's integrated
assembler and ld64.lld produce Mach-O without a host Apple toolchain. Apple
frameworks, libSystem and libc++ remain OS dependencies. No third-party macOS
libraries are bundled. Target pkg-config intentionally has no host fallback.
Inspect `LC_BUILD_VERSION`/`LC_VERSION_MIN_MACOSX` and load commands before
shipping. SDK availability does not establish an application's minimum runtime OS;
GPU/backend checks on the baseline OS are still required.

Windows uses cargo-xwin 0.23.1, LLVM 19, Windows SDK **10.0.26100**, CRT
**14.44.17.14**, desktop variant, both architectures. cargo-xwin sets clang-cl,
lld-link, llvm-lib and CMake toolchain paths for the target. SDK/CRT are downloaded
on first use into `/opt/xwin`; preserve that directory in a named volume.
They are not baked into the published image. The package manifest URL and actual
SHA-256 are pinned in `prepare-xwin`; a populated cache with other or unknown
inputs is rejected. Use a fresh named volume when updating pins. The SDK version is a build input,
not a promise that the application runs on every Windows version. Validate on
Windows 10/11 with appropriate graphics drivers; imported DLLs and the selected
CRT linkage determine deployment needs. Dynamic CRT builds need the matching
Microsoft Visual C++ Redistributable; inspect PE imports.

## SDK licenses

Downloading an SDK is not a grant to redistribute it. cargo-xwin use accepts the
[Microsoft SDK/Visual Studio terms](https://go.microsoft.com/fwlink/?LinkId=2086102).
Only components designated redistributable under the applicable terms may be
shipped with an application; keep SDK headers, import libraries and download
caches out of distributed application bundles and public images. Read the
[xwin licensing notes](https://github.com/Jake-Shadle/xwin#licenses).

The macOS SDK remains subject to the
[Apple Xcode and Apple SDKs agreement](https://www.apple.com/legal/sla/docs/xcode.pdf).
The agreement restricts Apple Software use to Apple-branded products running
macOS and limits redistribution. A third-party archive or private storage does
not grant additional SDK rights. The default build retains rustxc's existing
SDK-in-image model; publishers must establish their right to use and redistribute
that SDK before publishing an image. rustxc grants no rights to these SDKs.

## Validation and updates

Run the native fixture on either host architecture:

```sh
mkdir -p /tmp/rustxc-smoke
docker run --rm -v "$PWD/tests:/tests:ro" -v /tmp/rustxc-smoke:/evidence -e RUSTXC_EVIDENCE_DIR=/evidence rustxc:local /opt/rustxc/smoke aarch64-unknown-linux-gnu x86_64-unknown-linux-gnu powerpc64le-unknown-linux-gnu aarch64-apple-darwin x86_64-apple-darwin x86_64-pc-windows-msvc aarch64-pc-windows-msvc > /tmp/rustxc-smoke/smoke.log 2>&1
```

The locked fixture compiles and links Rust, C, C++, portable assembly, zstd and
Linux pkg-config-discovered libraries. It tests CMake root-path isolation and
rejects host include/library paths. Non-Windows ARM64 also compiles SHA assembly;
Windows ARM64 uses portable SHA plus a separate native assembly probe because
`sha2-asm` 0.6.4 does not support Windows.

CI runs these smoke builds on native AMD64 and ARM64 runners before
multi-architecture publication. Downstream application integration tests belong
in the consuming project's CI, using a pinned rustxc image digest. Successful
compilation does not verify GUI, GPU, clipboard, file dialogs, audio or gamepads.
Those need platform runtime checks; no renderer windows are launched by the
smoke scripts.

Updates are reviewed changes to Dockerfile pins: resolve the Rust **index** digest
(`docker buildx imagetools inspect rust:<version>-bookworm`), advance the Debian
snapshot, verify the SDK archive checksum, update cargo-xwin and Microsoft SDK/CRT
versions together (including the immutable package manifest URL/checksum in
`prepare-xwin` and its channel descriptor), and regenerate the fixture lockfile when needed. Re-run both
host matrices and downstream integration builds, inspect ABI requirements, and record image
digests. `/opt/rustxc/packages.txt` and each sysroot's `packages.txt` record package
versions. Rustup and Microsoft's service metadata are online services; archive
approved toolchains/SDK caches for offline rebuilds. Monthly/manual builds reuse
pins rather than silently following `rust:latest` or moving SDK branches.

The **Docker** workflow supports manual dispatch, monthly rebuilds and pushes to
master; it publishes AMD64+ARM64 `latest` and commit tags and signs the index digest.

See [toolchain validation scope](docs/validation.md).
