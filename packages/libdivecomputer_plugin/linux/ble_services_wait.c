#include "ble_services_wait.h"

#include <stddef.h>

ble_services_wait_result_t ble_services_wait(const ble_services_wait_ops_t* ops,
                                             int64_t timeout_us,
                                             int64_t poll_interval_us) {
    const int64_t deadline = ops->now_us(ops->userdata) + timeout_us;
    for (;;) {
        // Checked first: the link is held for as long as this loop runs, and
        // a download the diver has abandoned has no use for it.
        if (ops->cancelled != NULL && ops->cancelled(ops->userdata)) {
            return BLE_SERVICES_WAIT_CANCELLED;
        }
        if (ops->services_resolved(ops->userdata)) {
            return BLE_SERVICES_WAIT_RESOLVED;
        }
        if (!ops->connected(ops->userdata)) {
            return BLE_SERVICES_WAIT_LINK_DROPPED;
        }
        if (ops->now_us(ops->userdata) >= deadline) {
            return BLE_SERVICES_WAIT_TIMED_OUT;
        }
        ops->sleep_us(ops->userdata, poll_interval_us);
    }
}
