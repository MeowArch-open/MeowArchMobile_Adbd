// MeowArchMobile adbd standalone build — system properties shim header.
//
// daemon/property_monitor.h includes <sys/system_properties.h> unguarded.
// That is a bionic-only header; glibc has no equivalent. This header provides
// the (small) API surface adb's daemon actually uses, backed by libbase's
// host-side property implementation (system/libbase/properties.cpp defines
// __system_property_set/get/find/read_callback as weak symbols on
// non-bionic platforms — we link that, so the decls here must match its
// signatures exactly).
//
// __system_property_wait has no host implementation in libbase; our
// system_properties_shim.cpp provides a polling approximation (see there for
// the semantics and why that is good enough for adbd's one use case).
#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct prop_info prop_info;

#define PROP_VALUE_MAX 92

int __system_property_set(const char* name, const char* value);

const prop_info* __system_property_find(const char* name);

void __system_property_read_callback(
        const prop_info* pi,
        void (*callback)(void* cookie, const char* name, const char* value, uint32_t serial),
        void* cookie);

// Wait until the property's serial differs from old_serial (or, when pi is
// null, for any global property change), subject to the relative timeout.
// Returns false on timeout. Bionic signature; polling implementation here.
bool __system_property_wait(const prop_info* pi, uint32_t old_serial, uint32_t* new_serial_ptr,
                            const struct timespec* relative_timeout);

#ifdef __cplusplus
}
#endif
