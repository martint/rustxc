# Build the Mac OS X toolchain
FROM rust:latest AS osxcross

ARG MACOS_X_SDK_VERSION=14.5
RUN <<END
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -yq \
           curl \
           clang \
           git \
           wget \
           make \
           cmake \
           libssl-dev \
           zlib1g-dev \
           xz-utils
  git clone https://github.com/tpoechtrager/osxcross
  wget -nc "https://github.com/joseluisq/macosx-sdks/releases/download/$MACOS_X_SDK_VERSION/MacOSX$MACOS_X_SDK_VERSION.sdk.tar.xz" -O "osxcross/tarballs/MacOSX$MACOS_X_SDK_VERSION.sdk.tar.xz"
  UNATTENDED=1 TARGET_DIR=/toolchain/macos bash osxcross/build.sh
END

# Install toolchains for linux on various CPUs
FROM rust:latest

RUN <<END
  apt update
  apt install -yq \
      clang \
      gcc-aarch64-linux-gnu \
      gcc-x86-64-linux-gnu \
      gcc-powerpc64le-linux-gnu
  apt clean
END
COPY --from=osxcross /toolchain /toolchain

RUN <<END
  rustup target add \
      aarch64-unknown-linux-gnu \
      x86_64-unknown-linux-gnu \
      powerpc64le-unknown-linux-gnu \
      aarch64-apple-darwin \
      x86_64-apple-darwin
END

RUN <<EOF
  mkdir /.cargo
  cat > /.cargo/config.toml <<- CARGO
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"

[target.x86_64-unknown-linux-gnu]
linker = "x86_64-linux-gnu-gcc"

[target.powerpc64le-unknown-linux-gnu]
linker = "powerpc64le-linux-gnu-gcc"

[target.x86_64-apple-darwin]
linker = "$(basename $(find /toolchain -name 'x86_64-apple-darwin*-clang'))"

[target.aarch64-apple-darwin]
linker = "$(basename $(find /toolchain -name 'aarch64-apple-darwin*-clang'))"
CARGO
EOF

ENV PATH="$PATH:/toolchain/macos/bin"
WORKDIR /mnt
