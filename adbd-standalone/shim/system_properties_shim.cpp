// MeowArchMobile adbd standalone build — __system_property_wait shim.
//
// libbase's host property store (properties.cpp, non-bionic) defines
// __system_property_set/find/read_callback but NOT __system_property_wait —
// bionic only. The sole adb consumer is PropertyMonitor (daemon/usb.cpp's
// usb_ffs_open_thread), which watches sys.usb.adb.disabled — a property only
// ever set by Android's init.rc. On a glibc host nothing sets it, so the
// monitor just needs to park without burning CPU; if someone *does* change
// the property via adbd's own SetProperty path (libbase store), serials bump
// and the poll picks the change up.
//
// Implementation: poll the property's serial every 250 ms until it differs
// from old_serial, honoring the relative timeout (nullptr = wait forever).
// pi == nullptr (global serial) has no meaningful host equivalent, so it
// degrades to the same 250 ms poll, reporting a changed serial each round —
// PropertyMonitor::Run then re-reads its watched properties, which is exactly
// the behavior a polling monitor would have anyway.
#include <sys/system_properties.h>

#include <errno.h>
#include <thread>
#include <time.h>

#include <atomic>
#include <chrono>

namespace {

constexpr auto kPollInterval = std::chrono::milliseconds(250);

// Monotonic counter standing in for the "global property serial" that bionic
// exposes via __system_property_wait(nullptr, ...). Purely local: bumping it
// just makes PropertyMonitor re-poll its watched properties.
std::atomic<uint32_t> g_global_serial{0};

bool deadline_reached(const struct timespec* relative_timeout,
                      std::chrono::steady_clock::time_point start) {
    if (relative_timeout == nullptr) return false;
    auto elapsed = std::chrono::steady_clock::now() - start;
    auto limit = std::chrono::seconds(relative_timeout->tv_sec) +
                 std::chrono::nanoseconds(relative_timeout->tv_nsec);
    return elapsed >= limit;
}

uint32_t read_serial(const prop_info* pi) {
    uint32_t serial = 0;
    __system_property_read_callback(
            pi,
            [](void* cookie, const char*, const char*, uint32_t serial) {
                *static_cast<uint32_t*>(cookie) = serial;
            },
            &serial);
    return serial;
}

}  // namespace

bool __system_property_wait(const prop_info* pi, uint32_t old_serial, uint32_t* new_serial_ptr,
                            const struct timespec* relative_timeout) {
    auto start = std::chrono::steady_clock::now();

    if (pi == nullptr) {
        // Global wait: report a change every poll so callers re-read state.
        uint32_t next = g_global_serial.fetch_add(1) + 1;
        std::this_thread::sleep_for(kPollInterval);
        *new_serial_ptr = next;
        return true;
    }

    while (true) {
        uint32_t current = read_serial(pi);
        if (current != old_serial) {
            *new_serial_ptr = current;
            return true;
        }
        if (deadline_reached(relative_timeout, start)) {
            *new_serial_ptr = current;
            return false;
        }
        std::this_thread::sleep_for(kPollInterval);
    }
}
