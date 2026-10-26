# syntax=docker/dockerfile:1.7@sha256:a57df69d0ea827fb7266491f2813635de6f17269be881f696fbfdf2d83dda33e
# Multi-architecture index, not an architecture-specific manifest.
ARG RUST_IMAGE=rust:1.97.1-bookworm@sha256:0e2bcaef56d041a486784e54104a81aebe0da44bd03019bd70bc0401e42e4a97
FROM ${RUST_IMAGE} AS base
ARG DEBIAN_SNAPSHOT=20260811T000000Z
RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/* && \
    printf 'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/%s bookworm main\n' "$DEBIAN_SNAPSHOT" > /etc/apt/sources.list

# Download foreign packages rather than executing foreign binaries. These stages
# run natively on either build host. Each dependency closure has its own root.
FROM base AS sysroots
RUN apt-get update && apt-get install -y --no-install-recommends python3 ca-certificates
COPY scripts/make-sysroots /usr/local/bin/
RUN make-sysroots

FROM base AS tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    clang-19 lld-19 llvm-19 llvm-19-tools libclang-rt-19-dev \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
    gcc-x86-64-linux-gnu g++-x86-64-linux-gnu \
    gcc-powerpc64le-linux-gnu g++-powerpc64le-linux-gnu \
    cmake ninja-build make pkg-config nasm python3 file ca-certificates curl xz-utils \
    && rm -rf /var/lib/apt/lists/*
ARG CARGO_XWIN_VERSION=0.23.1
RUN cargo install --locked cargo-xwin --version "$CARGO_XWIN_VERSION" && \
    rm -rf /usr/local/cargo/registry /usr/local/cargo/git
# LLVM's integrated assembler and ld64.lld support both Darwin architectures.
# SDK is checksum-verified. See README licensing requirements before distribution.
ARG MACOS_SDK_VERSION=14.5
ARG MACOS_SDK_SHA256=6e146275d19f027faa2e8354da5e0267513abf013b8f16ad65a231653a2b1c5d
RUN curl -fL --retry 5 "https://github.com/joseluisq/macosx-sdks/releases/download/${MACOS_SDK_VERSION}/MacOSX${MACOS_SDK_VERSION}.sdk.tar.xz" -o /tmp/macos.tar.xz && \
    echo "$MACOS_SDK_SHA256  /tmp/macos.tar.xz" | sha256sum -c - && \
    mkdir -p /opt/sdk && tar -xJf /tmp/macos.tar.xz -C /opt/sdk && \
    mv "/opt/sdk/MacOSX${MACOS_SDK_VERSION}.sdk" /opt/sdk/macos && rm /tmp/macos.tar.xz
RUN rustup target add --toolchain 1.97.1 \
      aarch64-unknown-linux-gnu x86_64-unknown-linux-gnu powerpc64le-unknown-linux-gnu \
      aarch64-apple-darwin x86_64-apple-darwin \
      x86_64-pc-windows-msvc aarch64-pc-windows-msvc && \
    rustup component add --toolchain 1.97.1 rustfmt clippy && \
    dpkg-query -W > /opt/rustxc-packages.txt
COPY --from=sysroots /opt/sysroots /opt/sysroots
COPY scripts/ /opt/rustxc/
RUN /opt/rustxc/configure && mv /opt/rustxc-packages.txt /opt/rustxc/packages.txt
ENV PATH="/opt/rustxc/bin:/usr/lib/llvm-19/bin:${PATH}" \
    MACOSX_DEPLOYMENT_TARGET=11.0 \
    XWIN_CACHE_DIR=/opt/xwin XWIN_ARCH=x86_64,aarch64 \
    XWIN_VERSION=17 XWIN_SDK_VERSION=10.0.26100 XWIN_CRT_VERSION=14.44.17.14
WORKDIR /mnt
ENTRYPOINT ["/opt/rustxc/entrypoint"]
CMD ["bash"]
