// DiveComputerHostApiImpl::ConnectBluetooth: picks between Bluetooth LE and
// Bluetooth Classic for a download (issue #4094). Kept out of
// dive_computer_host_api_impl.cc, which is near the file size limit.
#include <cstdlib>
#include <string>

#include "ble_connect_failure.h"
#include "bluetooth_route_policy.h"
#include "dive_computer_host_api_impl.h"
#include "native_logger.h"

namespace libdivecomputer_plugin {

namespace {

constexpr char kBleCategory[] = "BLE";

}  // namespace

DiveComputerHostApiImpl::BluetoothConnection
DiveComputerHostApiImpl::ConnectBluetooth(const DiscoveredDevice& device) {
    const uint64_t address =
        std::strtoull(device.address().c_str(), nullptr, 16);
    const bool dual_mode = IsDualModeBluetooth(libdc_descriptor_transports(
        device.vendor().c_str(), device.product().c_str(),
        static_cast<unsigned int>(device.model())));
    const bool classic_paired =
        dual_mode && BluetoothClassicIoStream::IsPaired(address);
    if (dual_mode) {
        NativeLogger::Debug(
            kBleCategory,
            std::string("Dual-mode computer; Windows ") +
                (classic_paired ? "has" : "has no") +
                " paired Bluetooth Classic record for it");
    }

    BluetoothConnection connection;
    // Classic before LE when it was tried first, so the combined detail
    // reads in the order the routes ran.
    bool classic_tried_first = false;
    bool classic_tried = false;
    std::string classic_reason;
    auto try_classic = [&]() {
        classic_tried = true;
        classic_stream_ = std::make_unique<BluetoothClassicIoStream>();
        classic_reason = classic_stream_->Open(address);
        if (classic_reason.empty()) return true;
        classic_stream_.reset();
        return false;
    };
    const auto cancelled = [this] { return connect_cancelled_.load(); };

    // Paired as a Classic device: that is the route Windows set up, so it
    // goes first rather than after the whole LE retry window.
    if (ClassicRouteFirst(dual_mode, classic_paired)) {
        classic_tried_first = true;
        if (try_classic()) {
            connection.connected = true;
            connection.classic = true;
            return connection;
        }
    }

    BleConnectFailure le_failure = BleConnectFailure::kOther;
    std::string le_detail;
    if (!cancelled()) {
        ble_stream_ = std::make_unique<BleIoStream>();
        ble_stream_->SetDeviceAddress(device.address());
        ble_stream_->SetOnPinCodeRequired(
            [this](const std::string& pin_address) {
                PostToPlatformThread([this, pin_address] {
                    flutter_api_->OnPinCodeRequired(
                        pin_address, [] {}, [](const auto&) {});
                });
            });
        if (ble_stream_->ConnectAndDiscover(address, cancelled)) {
            connection.connected = true;
            return connection;
        }
        le_failure = ble_stream_->connect_failure();
        le_detail = ble_stream_->connect_failure_detail();
        ble_stream_.reset();
    }

    // The Petrel 2 found over LE and then refused discovery every way
    // Windows can report it (#4094), while its Classic radio is one RFCOMM
    // connect away.
    if (dual_mode && !classic_tried && !cancelled()) {
        NativeLogger::Info(kBleCategory,
                           "Bluetooth LE did not connect; trying Bluetooth "
                           "Classic");
        if (try_classic()) {
            connection.connected = true;
            connection.classic = true;
            return connection;
        }
    }

    // Name the step that broke. A fixed "Failed to connect to device" was
    // all a Windows report could carry (#4094); the Dart layer localizes the
    // codes a diver can act on and shows the detail for the rest.
    BleConnectFailure failure = le_failure;
    std::string detail = le_detail;
    if (classic_tried) {
        failure = ClassifyDualModeFailure(classic_paired);
        if (detail.empty()) {
            detail = classic_reason;
        } else if (classic_tried_first) {
            detail = classic_reason + "; then " + detail;
        } else {
            detail = detail + "; then " + classic_reason;
        }
    }
    connection.error_code = BleConnectFailureCode(failure);
    connection.error_message = BleConnectFailureMessage(failure, detail);
    return connection;
}

}  // namespace libdivecomputer_plugin
