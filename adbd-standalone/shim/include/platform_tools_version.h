// MeowArchMobile adbd standalone build — platform_tools_version stub.
//
// AOSP's build stamps adb binaries with the platform-tools version and the
// build number via a soong genrule ("platform_tools_version") plus
// libbuildversion. Neither is reachable from a standalone build; provide a
// tiny equivalent so that adb.cpp's adb_version() links and reports a sane
// string instead of a soong placeholder.
#pragma once

#define PLATFORM_TOOLS_VERSION "34.0.5"
