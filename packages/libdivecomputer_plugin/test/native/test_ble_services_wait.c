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
// A property read takes probe_cost_us; one given less time than that times
// out, which reads as false, the way a D-Bus Get past its timeout does.
typedef struct {
    int64_t now_us;
    int sleeps;
    int resolve_after;
    int drop_after;
    int cancel_after;
    int connected_probes;
    int64_t probe_cost_us;
    int64_t start_us;
    int64_t timeout_us;
    int probe_overran;
    // When set, ServicesResolved answers TRUE only after its read has run
    // past the time it was given, the way a reply can land just after a
    // D-Bus timeout would have fired.
    int resolve_late;
    // When set, the diver cancels while the ServicesResolved read is in
    // flight, and that read then answers TRUE.
    int cancel_during_resolved_read;
} FakeDevice;

static int reached(int after, int sleeps) {
    return after >= 0 && sleeps >= after;
}

// Spend one read's time; FALSE when the read times out first. Flags a read
// handed more time than the wait has left, or less than the millisecond a
// D-Bus timeout can express.
static int fake_read(FakeDevice* d, int64_t timeout_us) {
    if (d->now_us + timeout_us > d->start_us + d->timeout_us) {
        d->probe_overran = 1;
    }
    if (timeout_us < BLE_SERVICES_WAIT_MIN_READ_US) d->probe_overran = 1;
    if (d->probe_cost_us > timeout_us) {
        d->now_us += timeout_us;
        return 0;
    }
    d->now_us += d->probe_cost_us;
    return 1;
}

static int fake_services_resolved(void* userdata, int64_t timeout_us) {
    FakeDevice* d = (FakeDevice*)userdata;
    if (d->resolve_late) {
        d->now_us += timeout_us + 1;
        return 1;
    }
    if (d->cancel_during_resolved_read) {
        d->cancel_after = 0;
        return 1;
    }
    return fake_read(d, timeout_us) && reached(d->resolve_after, d->sleeps);
}

static int fake_connected(void* userdata, int64_t timeout_us) {
    FakeDevice* d = (FakeDevice*)userdata;
    d->connected_probes++;
    return fake_read(d, timeout_us) && !reached(d->drop_after, d->sleeps);
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
    d.start_us = d.now_us;
    d.timeout_us = TIMEOUT_US;
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
    assert(!d.probe_overran);
    printf("PASS: test_stall_times_out_at_the_deadline\n");
}

// A slow BlueZ cannot carry the wait past its deadline: every read gets at
// most the time left. The read the deadline cuts short says nothing about the
// link, so the wait reports a timeout rather than a dropped link.
static void test_slow_reads_stop_at_the_deadline(void) {
    FakeDevice d = fake_device();
    d.probe_cost_us = 3000000;
    const int64_t start = d.now_us;
    assert(run(&d) == BLE_SERVICES_WAIT_TIMED_OUT);
    assert(d.now_us - start == TIMEOUT_US);
    assert(!d.probe_overran);
    printf("PASS: test_slow_reads_stop_at_the_deadline\n");
}

// Discovery finishing only after the deadline is not reported as success.
static void test_resolution_after_the_deadline_is_a_timeout(void) {
    FakeDevice d = fake_device();
    d.probe_cost_us = 3000000;
    d.resolve_after = 5;  // Five polls of 6.1 s each end past 30 s.
    assert(run(&d) == BLE_SERVICES_WAIT_TIMED_OUT);
    assert(!d.probe_overran);
    printf("PASS: test_resolution_after_the_deadline_is_a_timeout\n");
}

// A TRUE that only arrives once the deadline has passed is not success, even
// when the read itself overran the time it was given.
static void test_late_true_is_a_timeout(void) {
    FakeDevice d = fake_device();
    d.resolve_late = 1;
    d.timeout_us = 2000;
    const ble_services_wait_ops_t ops = {
        fake_services_resolved, fake_connected, fake_cancelled,
        fake_now_us,            fake_sleep_us,  &d,
    };
    assert(ble_services_wait(&ops, d.timeout_us, POLL_US) ==
           BLE_SERVICES_WAIT_TIMED_OUT);
    printf("PASS: test_late_true_is_a_timeout\n");
}

// Under a millisecond left is too little for a D-Bus read, whose timeout is
// whole milliseconds: the wait ends there instead of handing a read more time
// than remains, and does not call the cut-short read a dropped link.
static void test_sub_millisecond_remainder_is_a_timeout(void) {
    FakeDevice d = fake_device();
    d.timeout_us = 1500;
    const ble_services_wait_ops_t ops = {
        fake_services_resolved, fake_connected, fake_cancelled,
        fake_now_us,            fake_sleep_us,  &d,
    };
    assert(ble_services_wait(&ops, d.timeout_us, 1000) ==
           BLE_SERVICES_WAIT_TIMED_OUT);
    assert(d.sleeps == 1);
    assert(d.connected_probes == 1);
    assert(!d.probe_overran);
    printf("PASS: test_sub_millisecond_remainder_is_a_timeout\n");
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

// A cancel that lands while the ServicesResolved read is in flight still
// wins when that read answers TRUE.
static void test_cancel_during_the_read_wins(void) {
    FakeDevice d = fake_device();
    d.cancel_during_resolved_read = 1;
    assert(run(&d) == BLE_SERVICES_WAIT_CANCELLED);
    printf("PASS: test_cancel_during_the_read_wins\n");
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
    test_slow_reads_stop_at_the_deadline();
    test_resolution_after_the_deadline_is_a_timeout();
    test_late_true_is_a_timeout();
    test_sub_millisecond_remainder_is_a_timeout();
    test_cancel_ends_the_wait();
    test_cancel_wins_over_resolution();
    test_cancel_during_the_read_wins();
    test_cancel_check_is_optional();
    printf("All ble_services_wait tests passed.\n");
    return 0;
}
