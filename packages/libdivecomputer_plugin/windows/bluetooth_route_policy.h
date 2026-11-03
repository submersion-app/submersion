#ifndef BLUETOOTH_ROUTE_POLICY_H_
#define BLUETOOTH_ROUTE_POLICY_H_

#include <cstdint>
#include <string>

#include "ble_connect_failure.h"

namespace libdivecomputer_plugin {

// How the Windows Bluetooth download repeats a failed LE connect and when it
// takes the Classic RFCOMM route instead (issue #4094).
//
// A Shearwater Petrel 2 on Windows 10 was found over LE every time, then
// failed in service discovery: twice with 0x8007003A, once with Unreachable
// after nine seconds. The same computer downloads from an iPhone. Qt's WinRT
// backend, the one Subsurface downloads Shearwaters through on Windows, keeps
// asking an unpaired device for its services for 20 seconds rather than
// giving up on the first refusal, and the Petrel 2 is the one Shearwater with
// a Classic radio too, which Windows reaches over RFCOMM.
//
// Free of WinRT so it can be unit tested on any host
// (test/native/test_bluetooth_route_policy.cc).

// How long LE connect and discovery keep being retried: Qt's
// kMaxConnectTimeout (qlowenergycontroller_winrt.cpp).
constexpr int64_t kConnectRetryWindowMs = 20000;
// The pause between attempts, so a link that just dropped has time to clear.
constexpr int64_t kConnectRetryDelayMs = 500;

// Whether a failed LE connect attempt could succeed if repeated: the link
// dropped (Unreachable), or WinRT refused one exchange in a way it reports
// as ERROR_BAD_NET_RESP or E_ILLEGAL_METHOD_CALL. `hresult` is 0 when the
// failure was a GattCommunicationStatus rather than a throw.
bool IsTransientConnectFailure(BleConnectFailure failure, int32_t hresult);

// Whether to start another attempt `elapsed_ms` after the first one began.
bool ShouldRetryConnect(BleConnectFailure failure, int32_t hresult,
                        int64_t elapsed_ms);

// Whether libdc lists the computer as both Classic and LE (the Petrel 2).
// `descriptor_transports` is a LIBDC_TRANSPORT_* bitmask.
bool IsDualModeBluetooth(unsigned int descriptor_transports);

// Whether the Classic route goes first: only for a dual-mode computer that
// Windows already has paired as a Classic device, since that is the route
// Windows set up for it and LE would spend its whole retry window first.
bool ClassicRouteFirst(bool dual_mode, bool classic_paired);

// The advice when neither route connected a dual-mode computer. Without a
// Classic pairing, pairing it is the step that opens the Classic route. With
// one, the computer did not answer; ble_device_not_found would say to remove
// the pairing the Classic route needs.
BleConnectFailure ClassifyDualModeFailure(BleConnectFailure le_failure,
                                          bool classic_paired);

// Colon-free upper-case hex, the one form a Windows address takes anywhere
// in this plugin: ble_scanner.cc formats the same uint64 as "%012llX", that
// string is DiscoveredDevice::address(), it is the access-code storage key,
// it is what bluetooth_connect.cc parses back with strtoull, and it is what
// the Dart log prints. A colon-separated form would mean the connect and
// error lines could not be matched to the device that produced them, and
// bluetoothAddressesMatch (discovery_providers.dart) only upper-cases before
// comparing, so it would not bridge the two spellings.
std::string FormatBluetoothAddress(uint64_t address);

}  // namespace libdivecomputer_plugin

#endif  // BLUETOOTH_ROUTE_POLICY_H_
