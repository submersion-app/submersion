// Pins how the Linux BLE transport waits for BlueZ to finish GATT service
// discovery (issue #4575). Device1.Connect returns once the LE link is up,
// before the services are exported, so enumerating characteristics straight
// after it found none and every download failed. The wait loop is free of
// GLib so it runs here; ble_io_stream.c supplies the D-Bus probes.
#include <assert.h>
#include <stdint.h>
#include <stdio.h>

#include "ble_services_wait.h"

#define POLL_US 100000
#define TIMEOUT_US 30000000

// A scripted device: each value is the number of sleeps after which that
// probe starts reporting true (or, for the link, false). -1 means never.
typedef struct {
    int64_t now_us;
    int sleeps;
    int resolve_after;
    int drop_after;
    int cancel_after;
    int connected_probes;
} FakeDevice;

static int reached(int after, int sleeps) {
    return after >= 0 && sleeps >= after;
}

static int fake_services_resolved(void* userdata) {
    const FakeDevice* d = (const FakeDevice*)userdata;
    return reached(d->resolve_after, d->sleeps);
}

static int fake_connected(void* userdata) {
    FakeDevice* d = (FakeDevice*)userdata;
    d->connected_probes++;
    return !reached(d->drop_after, d->sleeps);
}

static int fake_cancelled(void* userdata) {
    const FakeDevice* d = (const FakeDevice*)userdata;
    return reached(d->cancel_after, d->sleeps);
}

static int64_t fake_now_us(void* userdata) {
    return ((const FakeDevice*)userdata)->now_us;
}

static void fake_sleep_us(void* userdata, int64_t duration_us) {
    FakeDevice* d = (FakeDevice*)userdata;
    d->now_us += duration_us;
    d->sleeps++;
}

static FakeDevice fake_device(void) {
    FakeDevice d = {0};
    d.now_us = 5000000;  // Any start: only differences matter.
    d.resolve_after = -1;
    d.drop_after = -1;
    d.cancel_after = -1;
    return d;
}

static ble_services_wait_result_t run(FakeDevice* d) {
    const ble_services_wait_ops_t ops = {
        fake_services_resolved, fake_connected, fake_cancelled,
        fake_now_us,            fake_sleep_us,  d,
    };
    return ble_services_wait(&ops, TIMEOUT_US, POLL_US);
}

// A cached GATT database is exported before Connect returns: no delay, and
// the link is not probed at all.
static void test_already_resolved_returns_without_waiting(void) {
    FakeDevice d = fake_device();
    d.resolve_after = 0;
    assert(run(&d) == BLE_SERVICES_WAIT_RESOLVED);
    assert(d.sleeps == 0);
    assert(d.connected_probes == 0);
    printf("PASS: test_already_resolved_returns_without_waiting\n");
}

// The Perdix 2 in #4575 resolved about two seconds after Connect returned.
static void test_resolves_after_discovery(void) {
    FakeDevice d = fake_device();
    d.resolve_after = 20;
    assert(run(&d) == BLE_SERVICES_WAIT_RESOLVED);
    assert(d.sleeps == 20);
    printf("PASS: test_resolves_after_discovery\n");
}

static void test_link_drop_ends_the_wait(void) {
    FakeDevice d = fake_device();
    d.drop_after = 3;
    assert(run(&d) == BLE_SERVICES_WAIT_LINK_DROPPED);
    assert(d.sleeps == 3);
    printf("PASS: test_link_drop_ends_the_wait\n");
}

// A link that stays up but never finishes discovery gives up at the deadline,
// not before it and not a poll interval after it.
static void test_stall_times_out_at_the_deadline(void) {
    FakeDevice d = fake_device();
    const int64_t start = d.now_us;
    assert(run(&d) == BLE_SERVICES_WAIT_TIMED_OUT);
    assert(d.now_us - start == TIMEOUT_US);
    assert(d.sleeps == TIMEOUT_US / POLL_US);
    printf("PASS: test_stall_times_out_at_the_deadline\n");
}

// Cancel must end the wait promptly: the link is held up for as long as the
// thread keeps waiting, and a retry would race it for the shared stream.
static void test_cancel_ends_the_wait(void) {
    FakeDevice d = fake_device();
    d.cancel_after = 4;
    assert(run(&d) == BLE_SERVICES_WAIT_CANCELLED);
    assert(d.sleeps == 4);
    printf("PASS: test_cancel_ends_the_wait\n");
}

// A download the diver abandoned is not resumed just because discovery
// finished in the same poll.
static void test_cancel_wins_over_resolution(void) {
    FakeDevice d = fake_device();
    d.cancel_after = 2;
    d.resolve_after = 2;
    assert(run(&d) == BLE_SERVICES_WAIT_CANCELLED);
    printf("PASS: test_cancel_wins_over_resolution\n");
}

// Not every caller can cancel; a NULL check is allowed.
static void test_cancel_check_is_optional(void) {
    FakeDevice d = fake_device();
    d.resolve_after = 1;
    const ble_services_wait_ops_t ops = {
        fake_services_resolved, fake_connected, NULL,
        fake_now_us,            fake_sleep_us,  &d,
    };
    assert(ble_services_wait(&ops, TIMEOUT_US, POLL_US) ==
           BLE_SERVICES_WAIT_RESOLVED);
    printf("PASS: test_cancel_check_is_optional\n");
}

int main(void) {
    test_already_resolved_returns_without_waiting();
    test_resolves_after_discovery();
    test_link_drop_ends_the_wait();
    test_stall_times_out_at_the_deadline();
    test_cancel_ends_the_wait();
    test_cancel_wins_over_resolution();
    test_cancel_check_is_optional();
    printf("All ble_services_wait tests passed.\n");
    return 0;
}
