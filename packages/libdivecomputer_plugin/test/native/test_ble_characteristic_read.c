// Pins the shared decoding of libdivecomputer's BLE characteristic read
// ioctl (issue #422). Every platform BLE bridge routes the request through
// these two helpers, so the wire format is checked here once against the
// real libdivecomputer macros rather than four times against copies.
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <libdivecomputer/ble.h>
#include <libdivecomputer/ioctl.h>

#include "libdc_wrapper.h"

// 6E400003-B5A3-F393-E0A9-E50E24DC10B8, the first Cressi version field.
static const unsigned char kCressiVersionUuid[16] = {
    0x6E, 0x40, 0x00, 0x03, 0xB5, 0xA3, 0xF3, 0x93,
    0xE0, 0xA9, 0xE5, 0x0E, 0x24, 0xDC, 0x10, 0xB8,
};

static void test_request_constant_matches_libdivecomputer(void) {
    assert(LIBDC_IOCTL_BLE_CHARACTERISTIC_READ ==
           (unsigned int)DC_IOCTL_BLE_CHARACTERISTIC_READ);
    assert(LIBDC_BLE_UUID_STRING_SIZE == DC_BLE_UUID_SIZE);
    printf("PASS: test_request_constant_matches_libdivecomputer\n");
}

static void test_decodes_uuid_and_value_size(void) {
    unsigned char request[16 + 5] = {0};
    memcpy(request, kCressiVersionUuid, 16);
    char uuid[LIBDC_BLE_UUID_STRING_SIZE];
    size_t value_size = 0;
    assert(libdc_ble_characteristic_read_decode(
               DC_IOCTL_BLE_CHARACTERISTIC_READ, request, sizeof(request),
               uuid, &value_size) == LIBDC_BLE_CHAR_READ_OK);
    assert(strcmp(uuid, "6e400003-b5a3-f393-e0a9-e50e24dc10b8") == 0);
    assert(value_size == 5);
    printf("PASS: test_decodes_uuid_and_value_size\n");
}

static void test_other_requests_are_not_this(void) {
    unsigned char request[16 + 2] = {0};
    char uuid[LIBDC_BLE_UUID_STRING_SIZE];
    size_t value_size = 99;
    // The WRITE twin shares type and number; only the direction differs.
    assert(libdc_ble_characteristic_read_decode(
               DC_IOCTL_BLE_CHARACTERISTIC_WRITE, request, sizeof(request),
               uuid, &value_size) == LIBDC_BLE_CHAR_READ_NOT_THIS);
    assert(libdc_ble_characteristic_read_decode(
               DC_IOCTL_BLE_GET_NAME, request, sizeof(request),
               uuid, &value_size) == LIBDC_BLE_CHAR_READ_NOT_THIS);
    assert(value_size == 99);  // untouched
    printf("PASS: test_other_requests_are_not_this\n");
}

static void test_request_without_room_for_a_value_is_invalid(void) {
    unsigned char request[16] = {0};
    char uuid[LIBDC_BLE_UUID_STRING_SIZE];
    size_t value_size = 0;
    assert(libdc_ble_characteristic_read_decode(
               DC_IOCTL_BLE_CHARACTERISTIC_READ, request, 16,
               uuid, &value_size) == LIBDC_BLE_CHAR_READ_INVALID);
    assert(libdc_ble_characteristic_read_decode(
               DC_IOCTL_BLE_CHARACTERISTIC_READ, NULL, 21,
               uuid, &value_size) == LIBDC_BLE_CHAR_READ_INVALID);
    printf("PASS: test_request_without_room_for_a_value_is_invalid\n");
}

static void test_fill_copies_exact_value_after_the_uuid(void) {
    unsigned char request[16 + 5];
    memcpy(request, kCressiVersionUuid, 16);
    memset(request + 16, 0, 5);
    const unsigned char value[5] = {0x01, 0x02, 0x03, 0x04, 0x04};
    assert(libdc_ble_characteristic_read_fill(request, sizeof(request),
                                              value, 5) ==
           LIBDC_STATUS_SUCCESS);
    assert(memcmp(request, kCressiVersionUuid, 16) == 0);  // UUID intact
    assert(memcmp(request + 16, value, 5) == 0);
    printf("PASS: test_fill_copies_exact_value_after_the_uuid\n");
}

static void test_fill_truncates_a_longer_value(void) {
    unsigned char request[16 + 2] = {0};
    const unsigned char value[4] = {0xAA, 0xBB, 0xCC, 0xDD};
    assert(libdc_ble_characteristic_read_fill(request, sizeof(request),
                                              value, 4) ==
           LIBDC_STATUS_SUCCESS);
    assert(request[16] == 0xAA && request[17] == 0xBB);
    printf("PASS: test_fill_truncates_a_longer_value\n");
}

// A short value would leave libdivecomputer's pre-zeroed tail in place and
// be parsed as serial 0 / model 0. Refuse it instead (Review Focus 2).
static void test_fill_rejects_a_shorter_value(void) {
    unsigned char request[16 + 5] = {0};
    const unsigned char value[3] = {0x01, 0x02, 0x03};
    assert(libdc_ble_characteristic_read_fill(request, sizeof(request),
                                              value, 3) ==
           LIBDC_STATUS_DATAFORMAT);
    assert(libdc_ble_characteristic_read_fill(request, sizeof(request),
                                              NULL, 0) ==
           LIBDC_STATUS_DATAFORMAT);
    assert(libdc_ble_characteristic_read_fill(NULL, 21, value, 3) ==
           LIBDC_STATUS_INVALIDARGS);
    printf("PASS: test_fill_rejects_a_shorter_value\n");
}

int main(void) {
    test_request_constant_matches_libdivecomputer();
    test_decodes_uuid_and_value_size();
    test_other_requests_are_not_this();
    test_request_without_room_for_a_value_is_invalid();
    test_fill_copies_exact_value_after_the_uuid();
    test_fill_truncates_a_longer_value();
    test_fill_rejects_a_shorter_value();
    printf("All BLE characteristic read tests passed.\n");
    return 0;
}
