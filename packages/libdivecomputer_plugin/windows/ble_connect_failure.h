#ifndef BLE_CONNECT_FAILURE_H_
#define BLE_CONNECT_FAILURE_H_

#include <cstddef>
#include <cstdint>
#include <string>

namespace libdivecomputer_plugin {

// Why a Windows BLE connect or service discovery was abandoned, so the
// diver is told which step broke rather than one sentence for every
// failure (issue #4094: a Shearwater Petrel 2 on Windows 10 failed "very
// fast with a non-descript error message", which is all the report could
// say). Mirrors darwin's BleConnectFailure.
//
// Free of WinRT so the classification can be unit tested on any host
// (test/native/test_ble_connect_failure.cc).
enum class BleConnectFailure {
    // Nothing recorded yet.
    kNone,
    // BluetoothLEDevice::FromBluetoothAddressAsync resolved no LE record.
    // A dual-mode computer such as the Petrel 2 that Windows knows only as
    // a Bluetooth Classic device is one known cause; an address the stack
    // has not seen advertise recently is another.
    kNoLeDevice,
    // Windows refused the GATT operation until the computer is paired.
    kPairingRequired,
    // The link went away or the computer stopped answering.
    kUnreachable,
    // Anything the diver cannot act on; the detail goes to the developers.
    kOther,
};

// GattCommunicationStatus values from
// windows.devices.bluetooth.genericattributeprofile.idl. Pinned against the
// real enum by static_assert in ble_io_stream.cc.
namespace gatt_status {
constexpr int kSuccess = 0;
constexpr int kUnreachable = 1;
constexpr int kProtocolError = 2;
constexpr int kAccessDenied = 3;
}  // namespace gatt_status

// Classifies a non-Success GattCommunicationStatus.
BleConnectFailure ClassifyGattStatus(int status);

// Classifies the code of a winrt::hresult_error thrown while connecting.
BleConnectFailure ClassifyHresult(int32_t hresult);

// Classifies a discovery that found no usable service, from how many
// services it listed and how many of those refused to list their
// characteristics with AccessDenied or with Unreachable. Every service
// refusing with AccessDenied is the shape an unpaired machine gives, and
// every one refusing with Unreachable is a link that dropped mid-discovery;
// a partial refusal is not the reason.
BleConnectFailure ClassifyDiscoveryAccess(size_t services_listed,
                                          size_t services_access_denied,
                                          size_t services_unreachable);

// The DiveComputerError code the Dart layer switches on
// (DownloadStepWidget._localizedError).
const char* BleConnectFailureCode(BleConnectFailure failure);

// The DiveComputerError message. Dart shows it on screen only for
// connect_failed, as diagnostic details under its own "could not connect"
// sentence, so that one is `detail` alone; the classified ones are localized
// in Dart, but this text is still what lands in the debug log a diver
// attaches to a report.
std::string BleConnectFailureMessage(BleConnectFailure failure,
                                     const std::string& detail);

}  // namespace libdivecomputer_plugin

#endif  // BLE_CONNECT_FAILURE_H_
