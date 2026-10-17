#!/bin/bash
# Fetch the partial AOSP checkout the standalone build compiles against.
# ---------------------------------------------------------------------------
# Creates ../aosp-adbd (relative to this script's adbd-standalone/) with just
# the components CMakeLists.txt references — NOT a full repo/AOSP sync. Each
# component is a shallow-pinned checkout at the revision this build was
# verified against (2025-03 AOSP main); bump the pins deliberately.
#
# Repos fetched (see README "Upstream" for the full table):
#   packages/modules/adb        the daemon itself
#   system/core                 libcutils, libasyncio, diagnose_usb, headers
#   system/libbase              libbase (host property store, files, logging)
#   system/logging              liblog subset (system/logging/liblog)
#   external/protobuf           protobuf 21.12 (protoc + libprotobuf-lite)
#   external/boringssl          TLS/crypto for adbd (pregenerated build files)
#   external/fmtlib             fmt headers (libbase dependency)
#
# Total ~300 MB after checkout. googlesource may need a proxy; export
# https_proxy (and http_proxy) first if direct git fails.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
AOSP="${AOSP_ROOT_DIR:-$HERE/../aosp-adbd}"
mkdir -p "$AOSP"

fetch() {  # fetch <path-in-tree> <url> <pinned-sha>
    local path="$1" url="$2" sha="$3"
    if [ -d "$AOSP/$path/.git" ]; then
        echo "==> $path: exists"
        return
    fi
    echo "==> $path @ ${sha:0:12}"
    git -c advice.detachedHead=false clone -q --no-checkout "$url" "$AOSP/$path"
    git -C "$AOSP/$path" checkout -q "$sha"
}

fetch packages/modules/adb  https://android.googlesource.com/platform/packages/modules/adb  1cf2f017d312f73b3dc53bda85ef2610e35a80e9
fetch system/core           https://android.googlesource.com/platform/system/core           a3b721a32242006b59cb12bd62c9133632af3a2d
fetch system/libbase        https://android.googlesource.com/platform/system/libbase        6d19b5c690fa4220c10e42c2326150bbd4d4b7bb
fetch system/logging        https://android.googlesource.com/platform/system/logging        bcac7c30d88a3773a7c0bc9f5617a23a886331fd
fetch external/protobuf     https://android.googlesource.com/platform/external/protobuf     c8206780937dba60e53ce2fef7cc57c50439c30b
fetch external/boringssl    https://android.googlesource.com/platform/external/boringssl    ff82e866658b678df9ae4aac825828ce45b50209
fetch external/fmtlib       https://android.googlesource.com/platform/external/fmtlib       97ceae9d27415d6444f3e24f491da8ed6902ecfa

echo "==> done: $AOSP"
echo "    build with: cmake -B build-native && cmake --build build-native"
