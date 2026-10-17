# MeowArchMobile_Adbd

[![build](https://github.com/MeowArch-open/MeowArchMobile_Adbd/actions/workflows/build.yml/badge.svg)](https://github.com/MeowArch-open/MeowArchMobile_Adbd/actions/workflows/build.yml)

AOSP's **adbd** rebuilt as a native glibc binary for **Arch Linux ARM
(aarch64)** — TCP adb plus USB (FunctionFS), no Android userland, no soong.

See [`adbd-standalone/`](adbd-standalone/) for the build, packaging, and
upstream licensing details.

## Quick start (on the device)

    pacman -U adbd-meowarch-*.pkg.tar.zst
    sudo systemctl enable --now adbd
    adb connect <device>:5555

## Build (from a full AOSP-less checkout)

    cd adbd-standalone
    ./scripts/fetch-aosp.sh         # pinned partial AOSP sources (~300 MB)
    cmake -B build-native && cmake --build build-native -j$(nproc)
    ./scripts/make-sysroot.sh       # ALARM cross sysroot
    cmake -B build-aarch64 -DCMAKE_TOOLCHAIN_FILE=cmake/aarch64.cmake \
          -DHOST_PROTOC=$PWD/build-native/protobuf/protoc
    cmake --build build-aarch64 -j$(nproc)
    CARCH=aarch64 makepkg -f

CI builds and smoke-tests both native x86_64 and cross aarch64 on every push.

## License

Project glue (CMake, shims, patches, packaging) is GPL-3.0 — see
[LICENSE](LICENSE). The AOSP sources it builds remain under their upstream
licenses (Apache-2.0 unless noted in `adbd-standalone/README.md`).
