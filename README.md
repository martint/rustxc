This is a [docker image](https://github.com/martint/rustxc/pkgs/container/rustxc) that contains an environment for cross-compiling Rust projects to the following platforms:
* aarch64-unknown-linux-gnu
* x86_64-unknown-linux-gnu
* powerpc64le-unknown-linux-gnu
* x86_64-apple-darwin
* aarch64-apple-darwin

To use it:

    docker run --mount type=bind,source="$(pwd)",target=/mnt ghcr.io/martint/rustxc:latest \
        cargo build \
          --target powerpc64le-unknown-linux-gnu \
          --target x86_64-unknown-linux-gnu \
          --target aarch64-unknown-linux-gnu \
          --target x86_64-apple-darwin \
          --target aarch64-apple-darwin

To build the image locally:

    docker build . -t rustxc


# Resources

* https://github.com/tpoechtrager/osxcross
* https://dev.to/mbround18/rust-cross-compiling-from-linux-to-mac-on-github-actions-2mj8
* https://github.com/mbround18/setup-osxcross/blob/main/action.yml
* https://burgers.io/cross-compile-rust-from-arm-to-x86-64
* https://stackoverflow.com/questions/41761485/how-to-cross-compile-from-mac-to-linux
* https://github.com/messense/homebrew-macos-cross-toolchains           
