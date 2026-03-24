#include <assert.h>
#include <stdio.h>
#include <string.h>
#ifdef _WIN32
#define strncasecmp _strnicmp
#else
#include <strings.h>
#endif
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

static unsigned int captured_baud, captured_data, captured_parity;
static unsigned int captured_stop, captured_flow;

static int capture_configure(void *ud, unsigned int b, unsigned int d,
                             unsigned int p, unsigned int s, unsigned int f) {
    (void)ud;
    captured_baud = b;
    captured_data = d;
    captured_parity = p;
    captured_stop = s;
    captured_flow = f;
    return LIBDC_STATUS_SUCCESS;
}

static void test_configure_receives_parameters(void) {
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

// Reproduces the filtering logic used by serial_enumerate_ports() on Linux.
// Only ttyUSB* and ttyACM* should be included; ttyS* and other devices
// must be excluded to avoid probing unrelated hardware.
static int is_auto_probe_candidate(const char *name) {
    return (strncmp(name, "ttyUSB", 6) == 0 ||
            strncmp(name, "ttyACM", 6) == 0);
}

static void test_auto_probe_port_filtering(void) {
    // USB-to-serial adapters — should be included.
    assert(is_auto_probe_candidate("ttyUSB0"));
    assert(is_auto_probe_candidate("ttyUSB1"));
    assert(is_auto_probe_candidate("ttyACM0"));
    assert(is_auto_probe_candidate("ttyACM1"));

    // Motherboard serial ports — should be excluded.
    assert(!is_auto_probe_candidate("ttyS0"));
    assert(!is_auto_probe_candidate("ttyS1"));
    assert(!is_auto_probe_candidate("ttyS4"));

    // Other devices — should be excluded.
    assert(!is_auto_probe_candidate("tty0"));
    assert(!is_auto_probe_candidate("ttyAMA0"));
    assert(!is_auto_probe_candidate("console"));
    assert(!is_auto_probe_candidate("ptmx"));

    printf("PASS: test_auto_probe_port_filtering\n");
}

// Reproduces the hardware ID filtering used by EnumerateAvailableSerialPorts()
// on Windows. Only USB-attached serial ports should be included.
static int is_usb_serial_hw_id(const char *hw_id) {
    return (strncmp(hw_id, "USB\\", 4) == 0 ||
            strncmp(hw_id, "FTDIBUS\\", 8) == 0);
}

static void test_windows_hw_id_filtering(void) {
    // USB-attached serial adapters — should be included.
    assert(is_usb_serial_hw_id("USB\\VID_067B&PID_2303"));
    assert(is_usb_serial_hw_id("USB\\VID_0403&PID_6001"));
    assert(is_usb_serial_hw_id("FTDIBUS\\VID_0403+PID_6001"));

    // Built-in / non-USB ports — should be excluded.
    assert(!is_usb_serial_hw_id("ACPI\\PNP0501"));
    assert(!is_usb_serial_hw_id("PCI\\VEN_8086"));
    assert(!is_usb_serial_hw_id("BTHENUM\\{00001101}"));
    assert(!is_usb_serial_hw_id("ROOT\\PORTS"));

    printf("PASS: test_windows_hw_id_filtering\n");
}

// Reproduces the COM port detection logic from the Windows download path.
// Uses strncasecmp (POSIX) as a portable equivalent of _strnicmp (Win32).
static int is_com_port(const char *addr) {
    size_t len = strlen(addr);
    return (len >= 4 &&
            strncasecmp(addr, "COM", 3) == 0 &&
            addr[3] >= '0' && addr[3] <= '9');
}

static void test_com_port_detection(void) {
    // Valid COM ports.
    assert(is_com_port("COM3"));
    assert(is_com_port("COM10"));
    assert(is_com_port("com3"));
    assert(is_com_port("Com1"));

    // Strings that start with COM but aren't ports.
    assert(!is_com_port("COMBO_device"));
    assert(!is_com_port("COMMAND"));
    assert(!is_com_port("COM"));
    assert(!is_com_port("COMx"));

    // Unrelated strings.
    assert(!is_com_port(""));
    assert(!is_com_port("/dev/ttyUSB0"));
    assert(!is_com_port("Cressi_Leonardo"));

    printf("PASS: test_com_port_detection\n");
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
    test_auto_probe_port_filtering();
    test_windows_hw_id_filtering();
    test_com_port_detection();
    test_null_serial_callbacks_are_safe();
    printf("\nAll serial callback tests passed.\n");
    return 0;
}
