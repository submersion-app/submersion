#ifndef BLE_SERVICES_WAIT_H_
#define BLE_SERVICES_WAIT_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// The least time worth giving a property read: a D-Bus call timeout is whole
// milliseconds, so less than this left counts as the deadline having passed.
#define BLE_SERVICES_WAIT_MIN_READ_US 1000

// How a wait for BlueZ to finish GATT service discovery ended.
typedef enum {
    BLE_SERVICES_WAIT_RESOLVED = 0,
    BLE_SERVICES_WAIT_CANCELLED,
    BLE_SERVICES_WAIT_LINK_DROPPED,
    BLE_SERVICES_WAIT_TIMED_OUT,
} ble_services_wait_result_t;

// What the wait observes, and how it passes time. Kept free of GLib and D-Bus
// so test/native can drive the loop with a fake clock on any host;
// ble_io_stream.c supplies the BlueZ-backed probes.
typedef struct {
    // Each property read is given |timeout_us|, the time the wait has left
    // (at least BLE_SERVICES_WAIT_MIN_READ_US), and reads as zero if it
    // cannot finish within it.
    // Device1.ServicesResolved: non-zero once discovery is done and the
    // services and characteristics are exported.
    int (*services_resolved)(void* userdata, int64_t timeout_us);
    // Device1.Connected: zero once the link has dropped.
    int (*connected)(void* userdata, int64_t timeout_us);
    // Non-zero once the download has been cancelled. May be NULL.
    int (*cancelled)(void* userdata);
    // Monotonic clock, in microseconds.
    int64_t (*now_us)(void* userdata);
    void (*sleep_us)(void* userdata, int64_t duration_us);
    void* userdata;
} ble_services_wait_ops_t;

// Poll until the services resolve, the link drops, the download is cancelled
// or |timeout_us| passes, sleeping |poll_interval_us| between polls. No read
// or sleep is given more than the time left, so a slow BlueZ cannot carry the
// wait past its deadline; a resolution reported once the deadline has passed
// is a timeout, and so is a read the deadline cut short, not a dropped link.
// A cancellation wins over a resolution seen in the same poll,
// and the link is only probed while the services are still unresolved.
ble_services_wait_result_t ble_services_wait(const ble_services_wait_ops_t* ops,
                                             int64_t timeout_us,
                                             int64_t poll_interval_us);

#ifdef __cplusplus
}
#endif

#endif  // BLE_SERVICES_WAIT_H_
