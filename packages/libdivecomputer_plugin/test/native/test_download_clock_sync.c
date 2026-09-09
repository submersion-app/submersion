// Pins the clock sync step that runs after a successful download (issue
// #1216). The real dc_device_timesync dispatcher and the real dc_datetime
// helpers are linked in; the device is built by hand around a fake vtable so
// the test can see exactly what timesync received without scripting a whole
// device protocol.
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <libdivecomputer/common.h>
#include <libdivecomputer/datetime.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/device.h>

#include "device-private.h"
#include "libdc_wrapper.h"

static int g_timesync_calls = 0;
static dc_datetime_t g_received;
static dc_status_t g_timesync_result = DC_STATUS_SUCCESS;

static dc_status_t fake_timesync(dc_device_t *device,
                                 const dc_datetime_t *datetime) {
    (void)device;
    g_timesync_calls++;
    g_received = *datetime;
    return g_timesync_result;
}

static const dc_device_vtable_t vtable_with_timesync = {
    sizeof(dc_device_t), DC_FAMILY_NULL,
    NULL, NULL, NULL, NULL, NULL, fake_timesync, NULL,
};

static const dc_device_vtable_t vtable_without_timesync = {
    sizeof(dc_device_t), DC_FAMILY_NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
};

static char g_last_log[256];
static int g_last_level = 0;

static void capture_log(int level, const char *message, void *userdata) {
    (void)userdata;
    g_last_level = level;
    strncpy(g_last_log, message, sizeof(g_last_log) - 1);
    g_last_log[sizeof(g_last_log) - 1] = '\0';
}

static void reset(void) {
    g_timesync_calls = 0;
    memset(&g_received, 0, sizeof(g_received));
    g_timesync_result = DC_STATUS_SUCCESS;
    g_last_log[0] = '\0';
    g_last_level = 0;
}

static dc_device_t make_device(const dc_device_vtable_t *vtable) {
    dc_device_t device;
    memset(&device, 0, sizeof(device));
    device.vtable = vtable;
    return device;
}

static void test_not_requested_never_touches_the_device(void) {
    reset();
    dc_device_t device = make_device(&vtable_with_timesync);
    assert(libdc_sync_device_clock(&device, 0, 1) ==
           LIBDC_CLOCK_SYNC_NOT_REQUESTED);
    assert(g_timesync_calls == 0);
    printf("PASS: test_not_requested_never_touches_the_device\n");
}

static void test_failed_download_skips_the_sync(void) {
    reset();
    dc_device_t device = make_device(&vtable_with_timesync);
    assert(libdc_sync_device_clock(&device, 1, 0) ==
           LIBDC_CLOCK_SYNC_NOT_REQUESTED);
    assert(g_timesync_calls == 0);
    printf("PASS: test_failed_download_skips_the_sync\n");
}

static void test_synced_sends_host_local_time_with_offset(void) {
    reset();
    dc_device_t device = make_device(&vtable_with_timesync);
    dc_datetime_t before;
    dc_datetime_t after;
    assert(dc_datetime_localtime(&before, dc_datetime_now()) != NULL);
    libdc_clock_sync_status_t status =
        libdc_sync_device_clock(&device, 1, 1);
    assert(dc_datetime_localtime(&after, dc_datetime_now()) != NULL);

    assert(status == LIBDC_CLOCK_SYNC_SYNCED);
    assert(g_timesync_calls == 1);
    // The real clock cannot be pinned, so bracket it between two readings.
    dc_ticks_t received = dc_datetime_mktime(&g_received);
    assert(received >= dc_datetime_mktime(&before));
    assert(received <= dc_datetime_mktime(&after));
    // The host offset travels with the time so each backend can convert.
    assert(g_received.timezone != DC_TIMEZONE_NONE);
    assert(g_received.timezone == before.timezone);
    printf("PASS: test_synced_sends_host_local_time_with_offset\n");
}

static void test_backend_without_timesync_is_unsupported(void) {
    reset();
    dc_device_t device = make_device(&vtable_without_timesync);
    assert(libdc_sync_device_clock(&device, 1, 1) ==
           LIBDC_CLOCK_SYNC_UNSUPPORTED);
    // Expected for most models, so it must not log as a warning.
    assert(g_last_log[0] == '\0');
    printf("PASS: test_backend_without_timesync_is_unsupported\n");
}

static void test_backend_error_is_failed_and_logged(void) {
    reset();
    g_timesync_result = DC_STATUS_IO;
    dc_device_t device = make_device(&vtable_with_timesync);
    assert(libdc_sync_device_clock(&device, 1, 1) ==
           LIBDC_CLOCK_SYNC_FAILED);
    assert(g_last_level == 2);  // DC_LOGLEVEL_WARNING
    assert(strstr(g_last_log, "Clock sync failed") != NULL);
    printf("PASS: test_backend_error_is_failed_and_logged\n");
}

int main(void) {
    libdc_set_log_callback(capture_log, NULL);
    test_not_requested_never_touches_the_device();
    test_failed_download_skips_the_sync();
    test_synced_sends_host_local_time_with_offset();
    test_backend_without_timesync_is_unsupported();
    test_backend_error_is_failed_and_logged();
    libdc_set_log_callback(NULL, NULL);
    printf("All clock sync tests passed.\n");
    return 0;
}
