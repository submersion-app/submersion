// Integration test for the USB HID descriptor queries against the REAL
// libdivecomputer descriptor table (issue #1271).
//
// A USB HID dive computer is identified by the vendor and product id of the
// device that is plugged in, and libdivecomputer already owns that mapping:
// dc_filter_uwatec and dc_filter_suunto hold the id tables, reachable through
// the public dc_descriptor_filter(). libdc_usbhid_match asks libdivecomputer
// the question rather than copying the tables into plugin code, so hardware
// added upstream is picked up by a submodule bump alone.
//
// Every vendor/product id below comes from descriptor.c, never from the
// wrapper implementation, so a wrong implementation cannot make its own test
// pass:
//
//   dc_filter_uwatec, descriptor.c:666-671
//     {0x2e6c, 0x3201} G2, G2 TEK
//     {0x2e6c, 0x3211} G2 Console
//     {0x2e6c, 0x4201} G2 HUD
//     {0xc251, 0x2006} Aladin Square
//
//   dc_filter_suunto, descriptor.c:697-702
//     {0x1493, 0x0030} EON Steel
//     {0x1493, 0x0033} EON Core
//     {0x1493, 0x0035} D5
//     {0x1493, 0x0036} EON Steel Black

#include <assert.h>
#include <stdio.h>

#include <libdivecomputer/common.h>

#include "libdc_wrapper.h"

static void expect_match(const char *vendor, const char *product,
                         unsigned int model, unsigned short vid,
                         unsigned short pid) {
    if (!libdc_usbhid_match(vendor, product, model, vid, pid)) {
        fprintf(stderr, "FAIL: %s %s (0x%02x) rejected %04x:%04x\n", vendor,
                product, model, vid, pid);
        assert(0);
    }
}

static void expect_no_match(const char *vendor, const char *product,
                            unsigned int model, unsigned short vid,
                            unsigned short pid) {
    if (libdc_usbhid_match(vendor, product, model, vid, pid)) {
        fprintf(stderr, "FAIL: %s %s (0x%02x) accepted %04x:%04x\n", vendor,
                product, model, vid, pid);
        assert(0);
    }
}

// The device from the issue report. Its descriptor row carries
// DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE, so the USB HID bit must be visible
// and the serial bit must not: the download path uses exactly this to decide
// whether to look for a HID device before probing serial ports.
static void test_g2_tek_declares_usbhid_not_serial(void) {
    unsigned int transports =
        libdc_descriptor_transports("Scubapro", "G2 TEK", 0x31);
    assert((transports & LIBDC_TRANSPORT_USBHID) != 0);
    assert((transports & LIBDC_TRANSPORT_BLE) != 0);
    assert((transports & LIBDC_TRANSPORT_SERIAL) == 0);
    assert((transports & LIBDC_TRANSPORT_USB) == 0);
    printf("PASS: test_g2_tek_declares_usbhid_not_serial\n");
}

static void test_scubapro_ids_match_their_models(void) {
    expect_match("Scubapro", "G2 TEK", 0x31, 0x2e6c, 0x3201);
    expect_match("Scubapro", "G2", 0x32, 0x2e6c, 0x3201);
    expect_match("Scubapro", "G2 Console", 0x32, 0x2e6c, 0x3211);
    expect_match("Scubapro", "G2 HUD", 0x42, 0x2e6c, 0x4201);
    expect_match("Scubapro", "Aladin Square", 0x22, 0xc251, 0x2006);
    printf("PASS: test_scubapro_ids_match_their_models\n");
}

// The Suunto EON Steel family is the hardware behind issue #143, where showing
// a USB HID computer under USB with no HID transport behind it dead-ended the
// download. It comes back with this change, so it is tested alongside.
static void test_suunto_ids_match_their_models(void) {
    expect_match("Suunto", "EON Steel", 0, 0x1493, 0x0030);
    expect_match("Suunto", "EON Core", 1, 0x1493, 0x0033);
    expect_match("Suunto", "D5", 2, 0x1493, 0x0035);
    expect_match("Suunto", "EON Steel Black", 3, 0x1493, 0x0036);
    printf("PASS: test_suunto_ids_match_their_models\n");
}

// A HID device from another vendor must not be handed to this model's driver.
// Both vendors share the plugged-in HID bus, so the download path sees every
// HID device on the machine and relies entirely on this rejection.
static void test_foreign_vendor_ids_are_rejected(void) {
    expect_no_match("Scubapro", "G2 TEK", 0x31, 0x1493, 0x0035);
    expect_no_match("Suunto", "D5", 2, 0x2e6c, 0x3201);
    expect_no_match("Scubapro", "G2 TEK", 0x31, 0x0403, 0xf460);
    printf("PASS: test_foreign_vendor_ids_are_rejected\n");
}

// A descriptor that does not declare DC_TRANSPORT_USBHID must reject every id,
// including ids that belong to real HID dive computers. This has to be decided
// from the transport bitmask: dc_filter_shearwater has no USB HID branch and
// falls through to "accept", so asking the filter alone would say yes.
static void test_non_hid_models_reject_every_id(void) {
    expect_no_match("Shearwater", "Perdix", 5, 0x2e6c, 0x3201);
    expect_no_match("Shearwater", "Perdix", 5, 0x1493, 0x0030);
    expect_no_match("Mares", "Puck Pro", 0x18, 0x2e6c, 0x3201);
    printf("PASS: test_non_hid_models_reject_every_id\n");
}

static void test_unknown_model_has_no_transports(void) {
    assert(libdc_descriptor_transports("Nobody", "Nothing", 0x99) == 0);
    expect_no_match("Nobody", "Nothing", 0x99, 0x2e6c, 0x3201);
    printf("PASS: test_unknown_model_has_no_transports\n");
}

// A null vendor or product must not crash the enumeration; the download path
// passes strings straight through from the Pigeon layer.
static void test_null_arguments_are_safe(void) {
    assert(libdc_descriptor_transports(NULL, "G2 TEK", 0x31) == 0);
    assert(libdc_descriptor_transports("Scubapro", NULL, 0x31) == 0);
    assert(libdc_usbhid_match(NULL, NULL, 0x31, 0x2e6c, 0x3201) == 0);
    printf("PASS: test_null_arguments_are_safe\n");
}

// The wrapper redeclares libdivecomputer's transport bits so a platform backend
// does not have to include its headers, and DescriptorTransportMapping.swift
// redeclares them again so it compiles standalone. Neither copy is checked
// against the original by its own tests, so a renumbered dc_transport_t would
// leave every one of them passing while the mapping read the wrong bits.
//
// This is the link where both are in scope. Same reasoning as the flow-control
// pin in test_serial_callbacks.c, which exists because those constants really
// had been transcribed the wrong way round (issue #1155).
static void test_wrapper_transport_bits_match_libdivecomputer(void) {
    assert(LIBDC_TRANSPORT_SERIAL == DC_TRANSPORT_SERIAL);
    assert(LIBDC_TRANSPORT_USB == DC_TRANSPORT_USB);
    assert(LIBDC_TRANSPORT_USBHID == DC_TRANSPORT_USBHID);
    assert(LIBDC_TRANSPORT_IRDA == DC_TRANSPORT_IRDA);
    assert(LIBDC_TRANSPORT_BLUETOOTH == DC_TRANSPORT_BLUETOOTH);
    assert(LIBDC_TRANSPORT_BLE == DC_TRANSPORT_BLE);

    // Pinned against literals as well, so the values the Swift copy mirrors are
    // asserted here and not just asserted to equal each other.
    assert(LIBDC_TRANSPORT_SERIAL == (1 << 0));
    assert(LIBDC_TRANSPORT_USB == (1 << 1));
    assert(LIBDC_TRANSPORT_USBHID == (1 << 2));
    assert(LIBDC_TRANSPORT_IRDA == (1 << 3));
    assert(LIBDC_TRANSPORT_BLUETOOTH == (1 << 4));
    assert(LIBDC_TRANSPORT_BLE == (1 << 5));
    printf("PASS: test_wrapper_transport_bits_match_libdivecomputer\n");
}

int main(void) {
    test_wrapper_transport_bits_match_libdivecomputer();
    test_g2_tek_declares_usbhid_not_serial();
    test_scubapro_ids_match_their_models();
    test_suunto_ids_match_their_models();
    test_foreign_vendor_ids_are_rejected();
    test_non_hid_models_reject_every_id();
    test_unknown_model_has_no_transports();
    test_null_arguments_are_safe();
    printf("All USB HID descriptor tests passed\n");
    return 0;
}
