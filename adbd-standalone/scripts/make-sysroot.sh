#!/bin/bash
# Assemble the aarch64 cross sysroot for adbd-standalone.
# ---------------------------------------------------------------------------
# Produces sysroot-aarch64/ next to this script by merging:
#   1. /usr/aarch64-linux-gnu      (cross-gcc: glibc headers/libs, crt)
#   2. Arch Linux ARM aarch64 packages from a mirror:
#        libc++, libc++abi  (adbd requires libc++ — Block's standard-layout
#                            asserts fail with libstdc++'s unique_ptr)
#        libcap, brotli, zstd, lz4
# The mirror must serve versions matching the target system: the binary links
# libc++.so.1 / libbrotli*.so.1 / libzstd.so.1 / liblz4.so.1 / libcap.so.2,
# all of which ship with Arch Linux ARM proper.
#
# Layout produced:
#   include/   glibc + ALARM headers (ALARM files added non-clobbering)
#   lib/       ld-linux, libc, and all ALARM .so files (primary link dir)
#   usr/, lib64/  mirrors for pkg-config and driver search quirks
#   lib/pkgconfig/  hand-written .pc files (the ALARM pkgs ship none in a
#                   form usable cross; version pins below must match the
#                   downloaded package versions)
#
# Usage: ./make-sysroot.sh [mirror-base]
#   mirror-base default: https://mirrors.tuna.tsinghua.edu.cn/archlinuxarm
set -euo pipefail

MIRROR="${1:-https://mirrors.tuna.tsinghua.edu.cn/archlinuxarm}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SYSROOT="$HERE/sysroot-aarch64"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# package = repo/path  (paths may contain ':' epoch)
packages=(
    "core/libcap-2.78-1-aarch64.pkg.tar.xz"
    "core/brotli-1.2.0-1-aarch64.pkg.tar.xz"
    "core/zstd-1.5.7-3-aarch64.pkg.tar.xz"
    "core/lz4-1:1.10.0-2-aarch64.pkg.tar.xz"
    "extra/libc++-23.1.1-1-aarch64.pkg.tar.xz"
    "extra/libc++abi-23.1.1-1-aarch64.pkg.tar.xz"
)

echo "==> base: copying /usr/aarch64-linux-gnu"
rm -rf "$SYSROOT"
cp -a /usr/aarch64-linux-gnu "$SYSROOT"

echo "==> fetching ALARM packages"
mkdir -p "$WORK/root"
for p in "${packages[@]}"; do
    f="$WORK/$(basename "$p" | tr ':' '_')"
    echo "    $p"
    curl -fsSL --retry 3 -o "$f" "$MIRROR/aarch64/$p"
    tar -xf "$f" -C "$WORK/root"
done

echo "==> overlaying ALARM files (headers non-clobbering)"
# userland libs land in usr/lib; glibc headers live in include/ (this is how
# the cross-gcc sysroot is laid out), so also mirror new headers there.
cp -a "$WORK/root/usr/." "$SYSROOT/usr/"
cp -an "$WORK/root/usr/include/." "$SYSROOT/include/" 2>/dev/null || true
mkdir -p "$SYSROOT/include/sys"
cp -an "$WORK/root/usr/include/sys/." "$SYSROOT/include/sys/" 2>/dev/null || true

echo "==> linking ALARM libs into lib/ (primary linker path)"
mkdir -p "$SYSROOT/lib"
for so in libc++ libc++abi libcap libbrotlicommon libbrotlienc libbrotlidec libzstd liblz4; do
    cp -a "$SYSROOT"/usr/lib/${so}.so* "$SYSROOT/lib/" 2>/dev/null || true
done
# lib64 mirror (some linkers/drivers look there first)
ln -sfn lib "$SYSROOT/lib64"

echo "==> writing pkg-config files"
# Written out per-library (mirroring upstream brotli's own .pc files, which
# carry Requires.private chains): a sed-based transform of one template
# misfired here once — the pattern "libbrotlienc" never matches the "-l" flag
# "-lbrotlienc", silently leaving every .pc pointing at the encoder.
mkdir -p "$SYSROOT/lib/pkgconfig"
write_pc() {  # write_pc <name> <description> <version> <libs> [requires]
    local name="$1" desc="$2" ver="$3" libs="$4" req="${5:-}"
    cat > "$SYSROOT/lib/pkgconfig/$name.pc" <<EOF
prefix=/usr
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: $name
Description: $desc
Version: $ver
Libs: -L\${libdir} $libs
Requires.private: $req
Cflags: -I\${includedir}
EOF
}
write_pc libbrotlienc "Brotli encoder library" 1.2.0 "-lbrotlienc" "libbrotlicommon >= 1.2.0"
write_pc libbrotlidec "Brotli decoder library" 1.2.0 "-lbrotlidec" "libbrotlicommon >= 1.2.0"
write_pc libbrotlicommon "Brotli common library" 1.2.0 "-lbrotlicommon"
write_pc libzstd "Zstandard library" 1.5.7 "-lzstd"
write_pc liblz4 "LZ4 lossless compression library" 1.10.0 "-llz4"
write_pc libcap "POSIX capabilities library" 2.78 "-lcap"

echo "==> done: $SYSROOT"
echo "    build with:"
echo "      cmake -B build-aarch64 -DCMAKE_TOOLCHAIN_FILE=cmake/aarch64.cmake \\"
echo "            -DHOST_PROTOC=build-native/protobuf/protoc"
