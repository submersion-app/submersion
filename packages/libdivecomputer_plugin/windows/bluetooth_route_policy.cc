#include "bluetooth_route_policy.h"

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

namespace {

// HRESULT_FROM_WIN32(ERROR_BAD_NET_RESP), "The specified server cannot
// perform the requested operation": the reporter's log in #4094.
constexpr uint32_t kBadNetResp = 0x8007003A;
// E_ILLEGAL_METHOD_CALL, which Qt's connectToPairedDevice reads as a device
// that is not reachable at the moment and keeps trying.
constexpr uint32_t kIllegalMethodCall = 0x8000000E;

}  // namespace

bool IsTransientConnectFailure(BleConnectFailure failure, int32_t hresult) {
    if (failure == BleConnectFailure::kUnreachable) return true;
    if (failure != BleConnectFailure::kOther) return false;
    switch (static_cast<uint32_t>(hresult)) {
        case kBadNetResp:
        case kIllegalMethodCall:
            return true;
        default:
            return false;
    }
}

bool ShouldRetryConnect(BleConnectFailure failure, int32_t hresult,
                        int64_t elapsed_ms) {
    return IsTransientConnectFailure(failure, hresult) &&
           elapsed_ms + kConnectRetryDelayMs < kConnectRetryWindowMs;
}

bool IsDualModeBluetooth(unsigned int descriptor_transports) {
    const unsigned int both = LIBDC_TRANSPORT_BLUETOOTH | LIBDC_TRANSPORT_BLE;
    return (descriptor_transports & both) == both;
}

bool ClassicRouteFirst(bool dual_mode, bool classic_paired) {
    return dual_mode && classic_paired;
}

BleConnectFailure ClassifyDualModeFailure(BleConnectFailure le_failure,
                                          bool classic_paired) {
    if (!classic_paired) return BleConnectFailure::kPairingRequired;
    if (le_failure == BleConnectFailure::kPairingRequired) {
        return BleConnectFailure::kPairingRequired;
    }
    return BleConnectFailure::kUnreachable;
}

}  // namespace libdivecomputer_plugin
