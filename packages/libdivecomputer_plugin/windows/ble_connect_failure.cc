#include "ble_connect_failure.h"

namespace libdivecomputer_plugin {

namespace {

// HRESULTs, spelled out so this file needs no Windows headers.
constexpr uint32_t kEAccessDenied = 0x80070005;
// HRESULT_FROM_WIN32(ERROR_DEVICE_NOT_CONNECTED).
constexpr uint32_t kDeviceNotConnected = 0x8007048F;
// HRESULT_FROM_WIN32(ERROR_TIMEOUT).
constexpr uint32_t kTimeout = 0x800705B4;
// E_BLUETOOTH_ATT_*: the ATT error codes of the Bluetooth Core
// specification (Vol 3, Part F, 3.4.1.1) in facility 0x65.
constexpr uint32_t kAttInsufficientAuthentication = 0x80650005;
constexpr uint32_t kAttInsufficientAuthorization = 0x80650008;
constexpr uint32_t kAttInsufficientEncryption = 0x8065000F;

constexpr char kGenericMessage[] = "Failed to connect to device";

std::string WithDetail(const std::string& message, const std::string& detail) {
    return detail.empty() ? message : message + " (" + detail + ")";
}

}  // namespace

BleConnectFailure ClassifyGattStatus(int status) {
    switch (status) {
        case gatt_status::kAccessDenied:
            return BleConnectFailure::kPairingRequired;
        case gatt_status::kUnreachable:
            return BleConnectFailure::kUnreachable;
        default:
            return BleConnectFailure::kOther;
    }
}

BleConnectFailure ClassifyHresult(int32_t hresult) {
    switch (static_cast<uint32_t>(hresult)) {
        case kEAccessDenied:
        case kAttInsufficientAuthentication:
        case kAttInsufficientAuthorization:
        case kAttInsufficientEncryption:
            return BleConnectFailure::kPairingRequired;
        case kDeviceNotConnected:
        case kTimeout:
            return BleConnectFailure::kUnreachable;
        default:
            return BleConnectFailure::kOther;
    }
}

BleConnectFailure ClassifyDiscoveryAccess(size_t services_listed,
                                          size_t services_access_denied,
                                          size_t services_unreachable) {
    if (services_listed == 0) return BleConnectFailure::kOther;
    if (services_access_denied == services_listed) {
        return BleConnectFailure::kPairingRequired;
    }
    if (services_unreachable == services_listed) {
        return BleConnectFailure::kUnreachable;
    }
    return BleConnectFailure::kOther;
}

const char* BleConnectFailureCode(BleConnectFailure failure) {
    switch (failure) {
        case BleConnectFailure::kNoLeDevice:
            return "ble_device_not_found";
        case BleConnectFailure::kPairingRequired:
            return "pairing_required";
        case BleConnectFailure::kUnreachable:
            return "device_unreachable";
        case BleConnectFailure::kNone:
        case BleConnectFailure::kOther:
        default:
            return "connect_failed";
    }
}

std::string BleConnectFailureMessage(BleConnectFailure failure,
                                     const std::string& detail) {
    switch (failure) {
        case BleConnectFailure::kNoLeDevice:
            return WithDetail(
                "Windows could not find this dive computer over Bluetooth "
                "LE. Turn on its Bluetooth mode and scan again. If it is "
                "paired in Windows Bluetooth settings, remove it there "
                "first: Windows may know it only as a classic Bluetooth "
                "device",
                detail);
        case BleConnectFailure::kPairingRequired:
            return WithDetail(
                "Windows will not talk to this dive computer until it is "
                "paired. Turn on its Bluetooth mode, pair it in Windows "
                "Bluetooth settings, then try again",
                detail);
        case BleConnectFailure::kUnreachable:
            return WithDetail(
                "The dive computer did not answer over Bluetooth. Check that "
                "its Bluetooth mode is still on and that it is close to this "
                "computer, then try again",
                detail);
        case BleConnectFailure::kNone:
        case BleConnectFailure::kOther:
        default:
            // Dart wraps this in "Could not connect to dive computer", so
            // the detail stands alone rather than repeating that sentence.
            return detail.empty() ? std::string(kGenericMessage) : detail;
    }
}

}  // namespace libdivecomputer_plugin
