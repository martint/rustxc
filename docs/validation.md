# Toolchain validation

The repository's validation contract is the locked native fixture and CMake
probe, run for all seven targets on both container host architectures. Downstream
application builds and application-specific dependency failures belong in the
consuming project's integration tests.

## Coverage

The native fixture compiles and links Rust, C, C++, assembly and bundled zstd C
sources. Non-Windows ARM64 additionally compiles SHA assembly. Windows ARM64 uses
portable SHA and a separate native ARM64 assembly probe: sha2-asm 0.6.4 explicitly
rejects Windows, independently of the assembler's capabilities.

Linux probes ALSA, udev, D-Bus, Wayland, X11/extensions, xkbcommon, EGL and Vulkan
through target pkg-config. Include/library paths must be inside the selected
sysroot. An injected host `.pc` file must remain invisible. CMake probes exercise
target compilers and root-path isolation. Native Linux smoke executables also
run; cross-target executables are inspected rather than executed.

`inspect` reports ELF/Mach-O/PE headers, imported libraries and deployment
requirements, and rejects ELF glibc requirements above the declared baseline.
The smoke driver checks executable architecture and reports representative
zstd/SHA object headers. See the README for the complete invocation.

CI runs the matrix on native AMD64 and ARM64 runners and retains image metadata
and build logs as artifacts. An alternate Rust version exercises installation of
the active toolchain's target standard library. Changes to compiler, SDK,
sysroot or Rust inputs require rerunning this matrix.

## Runtime limits

Compilation and header inspection do not verify GUI/GPU compatibility. Consumers
must test on each deployment OS and architecture, including the declared baseline,
with appropriate graphics drivers and desktop services. Check runtime-loaded
libraries, rendering, shader compilation, X11/Wayland sessions, portal file
dialogs, clipboard, audio and gamepad permissions as applicable. Windows CRT
redistribution and macOS application signing/notarization are separate packaging
requirements. No visible renderer windows or profiler recordings are part of
rustxc's smoke suite.
