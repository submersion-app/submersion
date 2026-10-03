// Regression test for issue #2837: the descriptor catalog must not advertise
// libdivecomputer's raw USB transport.
//
// Every platform builds its model catalog from libdc_descriptor_iterator_next
// (Android through JNI, Darwin, Windows and Linux directly), and each maps a
// raw USB bit to the app's USB tab. Raw USB devices talk through USB control
// transfers (DC_IOCTL_USB_CONTROL_READ/WRITE), which no platform's I/O bridge
// implements, so a model listed under USB for that bit can never download.
//
// The expectations below come from descriptor.c, never from the wrapper, so a
// wrong implementation cannot make its own test pass:
//
//   descriptor.c:365-366  Atomic Aquatics Cobalt, Cobalt 2   DC_TRANSPORT_USB
//   descriptor.c:177      Scubapro G2              DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE
//   descriptor.c:383      Shearwater Perdix 3      DC_TRANSPORT_BLE
//   descriptor.c:109      Suunto Vyper             DC_TRANSPORT_SERIAL

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <libdivecomputer/common.h>

#include "libdc_wrapper.h"

// The catalog transports of the first descriptor with this vendor and product.
static unsigned int catalog_transports(const char *vendor,
                                       const char *product) {
    libdc_descriptor_iterator_t *iter = libdc_descriptor_iterator_new();
    assert(iter != NULL);
    libdc_descriptor_info_t info;
    int found = 0;
    unsigned int transports = 0;
    while (libdc_descriptor_iterator_next(iter, &info) == 0) {
        if (strcmp(info.vendor, vendor) == 0 &&
            strcmp(info.product, product) == 0) {
            transports = info.transports;
            found = 1;
            break;
        }
    }
    libdc_descriptor_iterator_free(iter);
    if (!found) {
        fprintf(stderr, "FAIL: %s %s is not in the catalog\n", vendor, product);
        assert(0);
    }
    return transports;
}

static void test_cobalts_advertise_no_transport(void) {
    assert(catalog_transports("Atomic Aquatics", "Cobalt") == 0);
    assert(catalog_transports("Atomic Aquatics", "Cobalt 2") == 0);
    printf("PASS: test_cobalts_advertise_no_transport\n");
}

static void test_no_descriptor_advertises_raw_usb(void) {
    libdc_descriptor_iterator_t *iter = libdc_descriptor_iterator_new();
    assert(iter != NULL);
    libdc_descriptor_info_t info;
    int count = 0;
    while (libdc_descriptor_iterator_next(iter, &info) == 0) {
        if (info.transports & DC_TRANSPORT_USB) {
            fprintf(stderr, "FAIL: %s %s advertises raw USB\n", info.vendor,
                    info.product);
            assert(0);
        }
        count++;
    }
    libdc_descriptor_iterator_free(iter);
    // A broken iterator that yields nothing would pass the loop above.
    assert(count > 300);
    printf("PASS: test_no_descriptor_advertises_raw_usb\n");
}

static void test_other_transports_are_untouched(void) {
    assert(catalog_transports("Scubapro", "G2") ==
           (DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE));
    assert(catalog_transports("Shearwater", "Perdix 3") == DC_TRANSPORT_BLE);
    assert(catalog_transports("Suunto", "Vyper") == DC_TRANSPORT_SERIAL);
    printf("PASS: test_other_transports_are_untouched\n");
}

int main(void) {
    test_cobalts_advertise_no_transport();
    test_no_descriptor_advertises_raw_usb();
    test_other_transports_are_untouched();
    return 0;
}
