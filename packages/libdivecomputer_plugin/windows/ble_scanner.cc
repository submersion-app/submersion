#include "ble_scanner.h"

#include <cctype>
#include <cstdio>
#include <string>

#include <winrt/Windows.Devices.Bluetooth.h>

#include "native_logger.h"

namespace libdivecomputer_plugin {

namespace {

constexpr char kBleCategory[] = "BLE";

// HRESULT code plus message, as ble_io_stream.cc logs them. The code is what
// a bug report can be searched on; the message alone is localized.
std::string DescribeHresult(const winrt::hresult_error& e) {
    char code[16];
    std::snprintf(code, sizeof(code), "0x%08X",
                  static_cast<unsigned int>(static_cast<int32_t>(e.code())));
    return std::string(code) + " " + winrt::to_string(e.message());
}

}  // namespace

BleScanner::BleScanner() = default;

BleScanner::~BleScanner() { Stop(); }

void BleScanner::SetOnDeviceDiscovered(DeviceCallback callback) {
    on_device_discovered_ = std::move(callback);
}

void BleScanner::SetOnComplete(CompleteCallback callback) {
    on_complete_ = std::move(callback);
}

uint32_t BleScanner::ParsePelagicModelCode(const std::string& name) {
    if (name.size() < 8) return 0;

    char c0 = name[0];
    char c1 = name[1];
    if (!std::isalpha(static_cast<unsigned char>(c0)) ||
        !std::isalpha(static_cast<unsigned char>(c1))) {
        return 0;
    }

    int digits = 0;
    for (size_t i = 2; i < name.size(); i++) {
        char ch = name[i];
        if (std::isdigit(static_cast<unsigned char>(ch))) {
            digits++;
        } else if (ch == ' ' || ch == '-' || ch == '_') {
            continue;
        } else {
            return 0;
        }
    }
    if (digits < 6) return 0;

    uint32_t upper0 = static_cast<uint32_t>(std::toupper(
        static_cast<unsigned char>(c0)));
    uint32_t upper1 = static_cast<uint32_t>(std::toupper(
        static_cast<unsigned char>(c1)));
    return (upper0 << 8) | upper1;
}

std::optional<std::string> BleScanner::Start() {
    {
        std::lock_guard<std::mutex> lock(seen_mutex_);
        seen_addresses_.clear();
    }

    try {
        watcher_ = winrt::Windows::Devices::Bluetooth::Advertisement::
            BluetoothLEAdvertisementWatcher();
        watcher_.ScanningMode(
            winrt::Windows::Devices::Bluetooth::Advertisement::
                BluetoothLEScanningMode::Active);

        received_token_ = watcher_.Received(
            {this, &BleScanner::OnAdvertisementReceived});
        stopped_token_ = watcher_.Stopped(
            {this, &BleScanner::OnWatcherStopped});

        // Throws 0x800710DF (ERROR_DEVICE_NOT_AVAILABLE) when the Bluetooth
        // radio is off or there is none.
        watcher_.Start();
        return std::nullopt;
    } catch (const winrt::hresult_error& e) {
        std::string reason = DescribeHresult(e);
        NativeLogger::Error(kBleCategory,
                            "BLE scan could not start: " + reason);
        Stop();
        return reason;
    }
}

void BleScanner::Stop() {
    if (!watcher_) return;
    try {
        watcher_.Received(received_token_);
        watcher_.Stopped(stopped_token_);
        if (watcher_.Status() ==
            winrt::Windows::Devices::Bluetooth::Advertisement::
                BluetoothLEAdvertisementWatcherStatus::Started) {
            watcher_.Stop();
        }
    } catch (const winrt::hresult_error& e) {
        NativeLogger::Warn(kBleCategory,
                           "BLE scan did not stop cleanly: " +
                               DescribeHresult(e));
    }
    watcher_ = nullptr;
}

void BleScanner::OnAdvertisementReceived(
    winrt::Windows::Devices::Bluetooth::Advertisement::
        BluetoothLEAdvertisementWatcher const&,
    winrt::Windows::Devices::Bluetooth::Advertisement::
        BluetoothLEAdvertisementReceivedEventArgs const& args) {
    uint64_t address = args.BluetoothAddress();

    {
        std::lock_guard<std::mutex> lock(seen_mutex_);
        if (seen_addresses_.count(address) > 0) return;
    }

    auto advertisement = args.Advertisement();
    auto local_name = advertisement.LocalName();
    if (local_name.empty()) return;

    std::string name = winrt::to_string(local_name);

    libdc_descriptor_info_t info = {};
    int matched = 0;

    // Try Pelagic model-code match first.
    uint32_t model_code = ParsePelagicModelCode(name);
    if (model_code != 0) {
        matched = libdc_descriptor_lookup_model(
            LIBDC_TRANSPORT_BLE, model_code, &info);
    }

    if (!matched) {
        matched = libdc_descriptor_match(
            name.c_str(), LIBDC_TRANSPORT_BLE, &info);
    }

    if (!matched) return;

    {
        std::lock_guard<std::mutex> lock(seen_mutex_);
        seen_addresses_.insert(address);
    }

    // Format BLE address as hex string for device identification.
    char addr_str[18] = {};
    snprintf(addr_str, sizeof(addr_str), "%012llX",
             static_cast<unsigned long long>(address));

    DiscoveredDevice device(
        std::string(info.vendor), std::string(info.product),
        static_cast<int64_t>(info.model), std::string(addr_str),
        &name, TransportType::kBle);

    if (on_device_discovered_) {
        on_device_discovered_(std::move(device));
    }
}

void BleScanner::OnWatcherStopped(
    winrt::Windows::Devices::Bluetooth::Advertisement::
        BluetoothLEAdvertisementWatcher const&,
    winrt::Windows::Devices::Bluetooth::Advertisement::
        BluetoothLEAdvertisementWatcherStoppedEventArgs const& args) {
    // A radio that goes away mid-scan, or one that Windows accepted Start()
    // for and then refused, ends the scan here instead of throwing.
    auto error = args.Error();
    if (error != winrt::Windows::Devices::Bluetooth::BluetoothError::Success) {
        NativeLogger::Warn(kBleCategory,
                           "BLE scan stopped with BluetoothError " +
                               std::to_string(static_cast<int32_t>(error)));
    }
    if (on_complete_) {
        on_complete_();
    }
}

}  // namespace libdivecomputer_plugin
