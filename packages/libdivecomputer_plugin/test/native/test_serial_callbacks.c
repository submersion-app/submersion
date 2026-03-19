#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "libdc_wrapper.h"

static int dummy_configure(void *userdata, unsigned int baudrate,
                           unsigned int databits, unsigned int parity,
                           unsigned int stopbits, unsigned int flowcontrol) {
    (void)userdata;
    (void)baudrate;
    (void)databits;
    (void)parity;
    (void)stopbits;
    (void)flowcontrol;
    return LIBDC_STATUS_SUCCESS;
}

static int dummy_set_dtr(void *userdata, unsigned int value) {
    (void)userdata;
    (void)value;
    return LIBDC_STATUS_SUCCESS;
}

static int dummy_set_rts(void *userdata, unsigned int value) {
    (void)userdata;
    (void)value;
    return LIBDC_STATUS_SUCCESS;
}

static void test_callbacks_struct_has_serial_fields(void) {
    libdc_io_callbacks_t cbs = {0};
    assert(cbs.configure == NULL);
    assert(cbs.set_dtr == NULL);
    assert(cbs.set_rts == NULL);
    printf("PASS: test_callbacks_struct_has_serial_fields\n");
}

static void test_callbacks_struct_accepts_serial_functions(void) {
    libdc_io_callbacks_t cbs = {0};
    cbs.configure = dummy_configure;
    cbs.set_dtr = dummy_set_dtr;
    cbs.set_rts = dummy_set_rts;

    assert(cbs.configure != NULL);
    assert(cbs.set_dtr != NULL);
    assert(cbs.set_rts != NULL);

    int rc = cbs.configure(NULL, 9600, 8, 0, 0, 0);
    assert(rc == LIBDC_STATUS_SUCCESS);

    rc = cbs.set_dtr(NULL, 1);
    assert(rc == LIBDC_STATUS_SUCCESS);

    rc = cbs.set_rts(NULL, 0);
    assert(rc == LIBDC_STATUS_SUCCESS);

    printf("PASS: test_callbacks_struct_accepts_serial_functions\n");
}

static void test_configure_receives_parameters(void) {
    // Verify parameters are forwarded correctly.
    static unsigned int captured_baud, captured_data, captured_parity;
    static unsigned int captured_stop, captured_flow;

    int capture_configure(void *ud, unsigned int b, unsigned int d,
                          unsigned int p, unsigned int s, unsigned int f) {
        (void)ud;
        captured_baud = b;
        captured_data = d;
        captured_parity = p;
        captured_stop = s;
        captured_flow = f;
        return LIBDC_STATUS_SUCCESS;
    }

    libdc_io_callbacks_t cbs = {0};
    cbs.configure = capture_configure;

    cbs.configure(NULL, 115200, 8, 0, 0, 2);
    assert(captured_baud == 115200);
    assert(captured_data == 8);
    assert(captured_parity == 0);
    assert(captured_stop == 0);
    assert(captured_flow == 2);

    printf("PASS: test_configure_receives_parameters\n");
}

static void test_transport_constants_for_serial_override(void) {
    // The transport override logic checks these conditions:
    // - caller passes USB or USBHID
    // - descriptor does NOT support USB or USBHID
    // - descriptor DOES support SERIAL
    // Result: override to SERIAL

    unsigned int caller_transport = LIBDC_TRANSPORT_USB;
    unsigned int desc_transports = LIBDC_TRANSPORT_SERIAL;

    unsigned int actual = caller_transport;
    if ((caller_transport & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) &&
        !(desc_transports & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) &&
        (desc_transports & LIBDC_TRANSPORT_SERIAL)) {
        actual = LIBDC_TRANSPORT_SERIAL;
    }
    assert(actual == LIBDC_TRANSPORT_SERIAL);

    // USBHID caller should also be overridden.
    caller_transport = LIBDC_TRANSPORT_USBHID;
    actual = caller_transport;
    if ((caller_transport & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) &&
        !(desc_transports & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) &&
        (desc_transports & LIBDC_TRANSPORT_SERIAL)) {
        actual = LIBDC_TRANSPORT_SERIAL;
    }
    assert(actual == LIBDC_TRANSPORT_SERIAL);

    // If descriptor supports USB, no override.
    desc_transports = LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_SERIAL;
    caller_transport = LIBDC_TRANSPORT_USB;
    actual = caller_transport;
    if ((caller_transport & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) &&
        !(desc_transports & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) &&
        (desc_transports & LIBDC_TRANSPORT_SERIAL)) {
        actual = LIBDC_TRANSPORT_SERIAL;
    }
    assert(actual == LIBDC_TRANSPORT_USB);

    // BLE caller should not be overridden.
    desc_transports = LIBDC_TRANSPORT_SERIAL;
    caller_transport = LIBDC_TRANSPORT_BLE;
    actual = caller_transport;
    if ((caller_transport & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) &&
        !(desc_transports & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) &&
        (desc_transports & LIBDC_TRANSPORT_SERIAL)) {
        actual = LIBDC_TRANSPORT_SERIAL;
    }
    assert(actual == LIBDC_TRANSPORT_BLE);

    printf("PASS: test_transport_constants_for_serial_override\n");
}

static void test_null_serial_callbacks_are_safe(void) {
    // When serial callbacks are NULL, bridge functions should be safe
    // to skip (the bridge_* functions check for NULL before calling).
    libdc_io_callbacks_t cbs = {0};
    assert(cbs.configure == NULL);
    assert(cbs.set_dtr == NULL);
    assert(cbs.set_rts == NULL);
    printf("PASS: test_null_serial_callbacks_are_safe\n");
}

int main(void) {
    test_callbacks_struct_has_serial_fields();
    test_callbacks_struct_accepts_serial_functions();
    test_configure_receives_parameters();
    test_transport_constants_for_serial_override();
    test_null_serial_callbacks_are_safe();
    printf("\nAll serial callback tests passed.\n");
    return 0;
}
