#include "ble_services_wait.h"

#include <stddef.h>

// Time left before |deadline|, or zero once too little remains for a read
// (see BLE_SERVICES_WAIT_MIN_READ_US).
static int64_t time_left(const ble_services_wait_ops_t* ops, int64_t deadline) {
    const int64_t left = deadline - ops->now_us(ops->userdata);
    return left < BLE_SERVICES_WAIT_MIN_READ_US ? 0 : left;
}

static int is_cancelled(const ble_services_wait_ops_t* ops) {
    return ops->cancelled != NULL && ops->cancelled(ops->userdata);
}

ble_services_wait_result_t ble_services_wait(const ble_services_wait_ops_t* ops,
                                             int64_t timeout_us,
                                             int64_t poll_interval_us) {
    const int64_t deadline = ops->now_us(ops->userdata) + timeout_us;
    for (;;) {
        // Checked first: the link is held for as long as this loop runs, and
        // a download the diver has abandoned has no use for it.
        if (is_cancelled(ops)) return BLE_SERVICES_WAIT_CANCELLED;

        int64_t left = time_left(ops, deadline);
        if (left == 0) return BLE_SERVICES_WAIT_TIMED_OUT;
        if (ops->services_resolved(ops->userdata, left)) {
            // A cancel that landed while the read was in flight still wins.
            if (is_cancelled(ops)) return BLE_SERVICES_WAIT_CANCELLED;
            // Only a resolution seen before the deadline counts.
            return deadline - ops->now_us(ops->userdata) > 0
                       ? BLE_SERVICES_WAIT_RESOLVED
                       : BLE_SERVICES_WAIT_TIMED_OUT;
        }

        left = time_left(ops, deadline);
        if (left == 0) return BLE_SERVICES_WAIT_TIMED_OUT;
        if (!ops->connected(ops->userdata, left)) {
            // A read the deadline cut short says nothing about the link.
            return time_left(ops, deadline) == 0
                       ? BLE_SERVICES_WAIT_TIMED_OUT
                       : BLE_SERVICES_WAIT_LINK_DROPPED;
        }

        left = time_left(ops, deadline);
        if (left == 0) return BLE_SERVICES_WAIT_TIMED_OUT;
        ops->sleep_us(ops->userdata,
                      poll_interval_us < left ? poll_interval_us : left);
    }
}
