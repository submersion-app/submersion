// Pins how the Windows Bluetooth download picks and repeats its routes
// (issue #4094). A Shearwater Petrel 2 on Windows 10 was found over
// Bluetooth LE and then failed in service discovery: twice with
// 0x8007003A, once with Unreachable after nine seconds. Qt's WinRT backend,
// which Subsurface downloads Shearwaters through on Windows, keeps retrying
// an unpaired device's discovery for 20 seconds; the Petrel 2 also has a
// Bluetooth Classic radio that Windows can reach over RFCOMM. The policy is
// free of WinRT so it can run here.
#include <assert.h>
#include <stdio.h>

#include <cstdint>
#include <string>

#include "bluetooth_route_policy.h"

extern "C" {
#include "libdc_wrapper.h"
}

using libdivecomputer_plugin::BleConnectFailure;
using libdivecomputer_plugin::ClassicRouteFirst;
using libdivecomputer_plugin::ClassifyDualModeFailure;
using libdivecomputer_plugin::FormatBluetoothAddress;
using libdivecomputer_plugin::IsDualModeBluetooth;
using libdivecomputer_plugin::IsTransientConnectFailure;
using libdivecomputer_plugin::ShouldRetryConnect;
using libdivecomputer_plugin::kConnectRetryDelayMs;
using libdivecomputer_plugin::kConnectRetryWindowMs;

// HRESULT_FROM_WIN32(ERROR_BAD_NET_RESP), the code in the reporter's log.
static const int32_t kBadNetResp = static_cast<int32_t>(0x8007003A);
// E_ILLEGAL_METHOD_CALL, which Qt treats as "not reachable at the moment".
static const int32_t kIllegalMethodCall = static_cast<int32_t>(0x8000000E);

static void test_transient_failures(void) {
    // The link dropped or never settled: worth another attempt.
    assert(IsTransientConnectFailure(BleConnectFailure::kUnreachable, 0));
    assert(IsTransientConnectFailure(BleConnectFailure::kOther, kBadNetResp));
    assert(IsTransientConnectFailure(BleConnectFailure::kOther,
                                     kIllegalMethodCall));
    // Pairing is a setting, not a moment: repeating cannot change it.
    assert(!IsTransientConnectFailure(BleConnectFailure::kPairingRequired, 0));
    // No LE record will not appear by asking again within seconds.
    assert(!IsTransientConnectFailure(BleConnectFailure::kNoLeDevice, 0));
    // An unrecognised throw, and a protocol error, are not retried.
    assert(!IsTransientConnectFailure(BleConnectFailure::kOther,
                                      static_cast<int32_t>(0x80650001)));
    assert(!IsTransientConnectFailure(BleConnectFailure::kOther, 0));
    assert(!IsTransientConnectFailure(BleConnectFailure::kNone, 0));
    printf("PASS: test_transient_failures\n");
}

static void test_retry_window(void) {
    // Qt's kMaxConnectTimeout.
    assert(kConnectRetryWindowMs == 20000);
    assert(kConnectRetryDelayMs > 0 && kConnectRetryDelayMs < 2000);
    assert(ShouldRetryConnect(BleConnectFailure::kUnreachable, 0, 0));
    assert(ShouldRetryConnect(BleConnectFailure::kOther, kBadNetResp, 9000));
    // The next attempt would start after the window closes.
    assert(!ShouldRetryConnect(BleConnectFailure::kUnreachable, 0,
                               kConnectRetryWindowMs - kConnectRetryDelayMs));
    assert(!ShouldRetryConnect(BleConnectFailure::kUnreachable, 0,
                               kConnectRetryWindowMs));
    // A failure that is not transient is never retried, however early.
    assert(!ShouldRetryConnect(BleConnectFailure::kPairingRequired, 0, 0));
    printf("PASS: test_retry_window\n");
}

static void test_dual_mode(void) {
    // libdc's descriptor lists the Petrel 2 as Classic and LE.
    assert(IsDualModeBluetooth(LIBDC_TRANSPORT_BLUETOOTH | LIBDC_TRANSPORT_BLE));
    // The Petrel 3, Perdix 2 and Teric are LE only.
    assert(!IsDualModeBluetooth(LIBDC_TRANSPORT_BLE));
    // A Classic-only computer never reaches the BLE download path.
    assert(!IsDualModeBluetooth(LIBDC_TRANSPORT_BLUETOOTH));
    assert(!IsDualModeBluetooth(LIBDC_TRANSPORT_SERIAL | LIBDC_TRANSPORT_BLE));
    printf("PASS: test_dual_mode\n");
}

static void test_route_order(void) {
    // Paired in Windows as a Classic device: that is the route Windows set
    // up, so it goes first instead of after the LE retry window.
    assert(ClassicRouteFirst(true, true));
    // Not paired: LE first, as every LE-only computer does.
    assert(!ClassicRouteFirst(true, false));
    // Never Classic for an LE-only computer, paired or not.
    assert(!ClassicRouteFirst(false, true));
    assert(!ClassicRouteFirst(false, false));
    printf("PASS: test_route_order\n");
}

static void test_dual_mode_failure_advice(void) {
    // Neither route connected and Windows has no Classic pairing: pairing it
    // is the one step that opens the Classic route, whatever LE said.
    assert(ClassifyDualModeFailure(BleConnectFailure::kOther, false) ==
           BleConnectFailure::kPairingRequired);
    assert(ClassifyDualModeFailure(BleConnectFailure::kNoLeDevice, false) ==
           BleConnectFailure::kPairingRequired);
    assert(ClassifyDualModeFailure(BleConnectFailure::kUnreachable, false) ==
           BleConnectFailure::kPairingRequired);
    // Already paired: telling the diver to pair it would be no help, and
    // "remove it from Bluetooth settings" (ble_device_not_found) would undo
    // the pairing the Classic route needs. The computer did not answer.
    assert(ClassifyDualModeFailure(BleConnectFailure::kOther, true) ==
           BleConnectFailure::kUnreachable);
    assert(ClassifyDualModeFailure(BleConnectFailure::kNoLeDevice, true) ==
           BleConnectFailure::kUnreachable);
    // LE itself asked for pairing: that stays the advice.
    assert(ClassifyDualModeFailure(BleConnectFailure::kPairingRequired, true) ==
           BleConnectFailure::kPairingRequired);
    printf("PASS: test_dual_mode_failure_advice\n");
}

static void test_address_format(void) {
    // The reporter's Petrel 2, as ble_scanner.cc and the debug log spell it.
    assert(FormatBluetoothAddress(0x0013439776F7ULL) == "0013439776F7");
    assert(FormatBluetoothAddress(0) == "000000000000");
    printf("PASS: test_address_format\n");
}

int main(void) {
    test_transient_failures();
    test_retry_window();
    test_dual_mode();
    test_route_order();
    test_dual_mode_failure_advice();
    test_address_format();
    printf("All bluetooth route policy tests passed.\n");
    return 0;
}
