# CMake toolchain file: cross-compile adbd-standalone to aarch64 (Arch Linux ARM)
# ---------------------------------------------------------------------------
# Toolchain: system clang 23 targeting aarch64-linux-gnu, against a merged
# sysroot:
#   * aarch64-linux-gnu-gcc (GCC 16.1.0) supplies the glibc 2.44 sysroot base
#     (/usr/aarch64-linux-gnu, copied here — original stays pristine)
#   * Arch Linux ARM aarch64 packages overlay the userland libs and headers
#     adbd links: libc++/libc++abi 23.1.1, libcap, brotli, zstd, lz4
#
# Why libc++ and not the cross-gcc libstdc++: adb's types.h static-asserts
# that Block (and friends) are standard-layout, and libstdc++'s std::unique_ptr
# is not; libc++'s is. Same reason the x86_64 native build links libc++.
# Because the target is Arch Linux ARM (which ships a matching libc++), we can
# link the target's own libc++ from the sysroot rather than dragging in
# libstdc++ at all.
#
# Sysroot layout (sysroot-aarch64/, created by scripts/make-sysroot.sh):
#   include/          glibc + ALARM headers (brotli/, c++/v1, sys/capability.h …)
#   lib/              ld-linux + libc + ALARM .so files
#   usr/lib, lib64/   extra mirrors of lib/ for linker search quirks
#
# protoc: cross builds reuse the host (x86_64) build tree's protoc — the .proto
# files generate identically for both architectures.
#
# Usage:
#   cmake -B build-aarch64 -DCMAKE_TOOLCHAIN_FILE=cmake/aarch64.cmake \
#         -DHOST_PROTOC=/path/to/host/build/protobuf/protoc
#   cmake --build build-aarch64 -j$(nproc)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(TOOLCHAIN_ROOT "${CMAKE_CURRENT_LIST_DIR}/../sysroot-aarch64")

# ---- compiler: clang with the cross-gcc's libgcc/crt/startfiles -----------
# --gcc-toolchain points clang at /usr/aarch64-linux-gnu so it finds GCC's crt
# objects and libgcc; --sysroot then redirects libc/headers to our merged tree.
set(CMAKE_C_COMPILER   clang)
set(CMAKE_CXX_COMPILER clang++)
set(_ADBD_CLANG_FLAGS "--target=aarch64-linux-gnu --gcc-toolchain=/usr --sysroot=${TOOLCHAIN_ROOT}")

set(CMAKE_C_FLAGS_INIT   "${_ADBD_CLANG_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${_ADBD_CLANG_FLAGS} -stdlib=libc++")

# clang's libc++ headers: prefer the sysroot's (ALARM 23.1.1, matches the
# target's libc++.so.1). The -stdlib=libc++ driver flag handles that once
# CMAKE_SYSROOT is understood; keep an explicit hint too in case the driver
# picks host headers of a different version.
set(CMAKE_CXX_FLAGS_INIT "${CMAKE_CXX_FLAGS_INIT} -nostdinc++ -isystem ${TOOLCHAIN_ROOT}/include/c++/v1")

# ---- linker ----------------------------------------------------------------
set(CMAKE_EXE_LINKER_FLAGS_INIT    "${_ADBD_CLANG_FLAGS} -L${TOOLCHAIN_ROOT}/lib")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${_ADBD_CLANG_FLAGS} -L${TOOLCHAIN_ROOT}/lib")

# find_library/ar/ranlib for the target
set(CMAKE_AR           aarch64-linux-gnu-ar)
set(CMAKE_RANLIB       aarch64-linux-gnu-ranlib)
set(CMAKE_FIND_ROOT_PATH "${TOOLCHAIN_ROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# ---- pkg-config must not leak host flags ----------------------------------
set(ENV{PKG_CONFIG_LIBDIR} "${TOOLCHAIN_ROOT}/lib/pkgconfig:${TOOLCHAIN_ROOT}/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${TOOLCHAIN_ROOT}")
