// Pins how the Windows BLE transport classifies a failed connect (issue
// #4094). Every Windows failure used to reach the diver as the same
// "Failed to connect to device", so a report could say nothing about which
// step broke. The classifier is free of WinRT so it can run here; the
// GattCommunicationStatus values it mirrors are pinned against the real
// enum by static_assert in windows/ble_io_stream.cc.
#include <assert.h>
#include <stdio.h>

#include <cstdint>
#include <string>

#include "ble_connect_failure.h"

using libdivecomputer_plugin::BleConnectFailure;
using libdivecomputer_plugin::BleConnectFailureCode;
using libdivecomputer_plugin::BleConnectFailureMessage;
using libdivecomputer_plugin::ClassifyDiscoveryAccess;
using libdivecomputer_plugin::ClassifyGattStatus;
using libdivecomputer_plugin::ClassifyHresult;
namespace gatt_status = libdivecomputer_plugin::gatt_status;

static bool Contains(const std::string& haystack, const std::string& needle) {
    return haystack.find(needle) != std::string::npos;
}

// Values from windows.devices.bluetooth.genericattributeprofile.idl. If these
// drift, every GATT status lands in the wrong advice.
static void test_gatt_status_values_match_winrt(void) {
    assert(gatt_status::kSuccess == 0);
    assert(gatt_status::kUnreachable == 1);
    assert(gatt_status::kProtocolError == 2);
    assert(gatt_status::kAccessDenied == 3);
    printf("PASS: test_gatt_status_values_match_winrt\n");
}

static void test_gatt_status_classification(void) {
    // AccessDenied is Windows' own pairing state, not the computer's answer.
    assert(ClassifyGattStatus(gatt_status::kAccessDenied) ==
           BleConnectFailure::kPairingRequired);
    assert(ClassifyGattStatus(gatt_status::kUnreachable) ==
           BleConnectFailure::kUnreachable);
    // The computer answered with an ATT error: nothing the diver can switch.
    assert(ClassifyGattStatus(gatt_status::kProtocolError) ==
           BleConnectFailure::kOther);
    assert(ClassifyGattStatus(42) == BleConnectFailure::kOther);
    printf("PASS: test_gatt_status_classification\n");
}

static void test_hresult_classification(void) {
    // E_ACCESSDENIED.
    assert(ClassifyHresult(static_cast<int32_t>(0x80070005)) ==
           BleConnectFailure::kPairingRequired);
    // E_BLUETOOTH_ATT_INSUFFICIENT_AUTHENTICATION, _AUTHORIZATION and
    // _ENCRYPTION: the computer wants an encrypted, paired link.
    assert(ClassifyHresult(static_cast<int32_t>(0x80650005)) ==
           BleConnectFailure::kPairingRequired);
    assert(ClassifyHresult(static_cast<int32_t>(0x80650008)) ==
           BleConnectFailure::kPairingRequired);
    assert(ClassifyHresult(static_cast<int32_t>(0x8065000F)) ==
           BleConnectFailure::kPairingRequired);
    // HRESULT_FROM_WIN32(ERROR_DEVICE_NOT_CONNECTED) and (ERROR_TIMEOUT).
    assert(ClassifyHresult(static_cast<int32_t>(0x8007048F)) ==
           BleConnectFailure::kUnreachable);
    assert(ClassifyHresult(static_cast<int32_t>(0x800705B4)) ==
           BleConnectFailure::kUnreachable);
    // E_BLUETOOTH_ATT_INVALID_HANDLE: the computer refused, no advice fits.
    assert(ClassifyHresult(static_cast<int32_t>(0x80650001)) ==
           BleConnectFailure::kOther);
    // RO_E_CLOSED, "The object has been closed".
    assert(ClassifyHresult(static_cast<int32_t>(0x80000013)) ==
           BleConnectFailure::kOther);
    printf("PASS: test_hresult_classification\n");
}

static void test_discovery_access_classification(void) {
    // An unpaired machine: every service refuses its characteristics.
    assert(ClassifyDiscoveryAccess(3, 3) ==
           BleConnectFailure::kPairingRequired);
    // Some services listed fine, so the refusals are not the reason.
    assert(ClassifyDiscoveryAccess(3, 1) == BleConnectFailure::kOther);
    assert(ClassifyDiscoveryAccess(3, 0) == BleConnectFailure::kOther);
    // No services at all is not a pairing problem either.
    assert(ClassifyDiscoveryAccess(0, 0) == BleConnectFailure::kOther);
    printf("PASS: test_discovery_access_classification\n");
}

// The codes are what DownloadStepWidget._localizedError switches on.
static void test_error_codes(void) {
    assert(std::string(BleConnectFailureCode(
               BleConnectFailure::kNoLeDevice)) == "ble_device_not_found");
    assert(std::string(BleConnectFailureCode(
               BleConnectFailure::kPairingRequired)) == "pairing_required");
    assert(std::string(BleConnectFailureCode(
               BleConnectFailure::kUnreachable)) == "device_unreachable");
    assert(std::string(BleConnectFailureCode(BleConnectFailure::kOther)) ==
           "connect_failed");
    // Nothing recorded must still read as a connect failure, not as success.
    assert(std::string(BleConnectFailureCode(BleConnectFailure::kNone)) ==
           "connect_failed");
    printf("PASS: test_error_codes\n");
}

// The Dart layer shows the native message only for connect_failed, under its
// own "Could not connect to dive computer" sentence as "Diagnostic details
// (share with developers)", so that message is the step that broke and
// nothing that repeats the sentence above it.
static void test_unclassified_message_is_the_detail(void) {
    const std::string detail =
        "Service discovery failed: protocol error; the computer refused the "
        "request";
    assert(BleConnectFailureMessage(BleConnectFailure::kOther, detail) ==
           detail);
    printf("PASS: test_unclassified_message_is_the_detail\n");
}

static void test_message_without_detail(void) {
    assert(BleConnectFailureMessage(BleConnectFailure::kOther, "") ==
           "Failed to connect to device");
    assert(BleConnectFailureMessage(BleConnectFailure::kNone, "") ==
           "Failed to connect to device");
    printf("PASS: test_message_without_detail\n");
}

// Classified codes are localized in Dart, but the native message is what
// lands in the debug log a diver attaches, so it still names the cause.
static void test_classified_messages_name_the_cause(void) {
    const std::string not_found = BleConnectFailureMessage(
        BleConnectFailure::kNoLeDevice, "No Bluetooth LE device for 0013437214EE");
    assert(Contains(not_found, "Bluetooth LE"));
    assert(Contains(not_found, "0013437214EE"));

    const std::string pairing =
        BleConnectFailureMessage(BleConnectFailure::kPairingRequired, "");
    assert(Contains(pairing, "pair"));

    const std::string unreachable =
        BleConnectFailureMessage(BleConnectFailure::kUnreachable, "");
    assert(Contains(unreachable, "did not answer"));
    printf("PASS: test_classified_messages_name_the_cause\n");
}

int main(void) {
    test_gatt_status_values_match_winrt();
    test_gatt_status_classification();
    test_hresult_classification();
    test_discovery_access_classification();
    test_error_codes();
    test_unclassified_message_is_the_detail();
    test_message_without_detail();
    test_classified_messages_name_the_cause();
    printf("All BLE connect failure tests passed.\n");
    return 0;
}
