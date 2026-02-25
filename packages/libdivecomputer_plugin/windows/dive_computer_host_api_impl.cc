#include "dive_computer_host_api_impl.h"

#include "dive_converter.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace libdivecomputer_plugin {

DiveComputerHostApiImpl::DiveComputerHostApiImpl(
    flutter::BinaryMessenger* messenger)
    : flutter_api_(
          std::make_unique<DiveComputerFlutterApi>(messenger)) {}

DiveComputerHostApiImpl::~DiveComputerHostApiImpl() {
    if (download_thread_.joinable()) {
        download_thread_.join();
    }
}

void DiveComputerHostApiImpl::GetDeviceDescriptors(
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
    libdc_descriptor_iterator_t* iter = libdc_descriptor_iterator_new();
    if (iter == nullptr) {
        result(FlutterError("internal_error",
                            "Failed to create descriptor iterator"));
        return;
    }

    flutter::EncodableList descriptors;
    libdc_descriptor_info_t info;
    int rc;
    while ((rc = libdc_descriptor_iterator_next(iter, &info)) == 0) {
        flutter::EncodableList transports;
        if (info.transports & LIBDC_TRANSPORT_BLE) {
            transports.push_back(
                flutter::CustomEncodableValue(TransportType::kBle));
        }
        if (info.transports & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) {
            transports.push_back(
                flutter::CustomEncodableValue(TransportType::kUsb));
        }
        if (info.transports & LIBDC_TRANSPORT_SERIAL) {
            transports.push_back(
                flutter::CustomEncodableValue(TransportType::kSerial));
        }
        if (info.transports & LIBDC_TRANSPORT_IRDA) {
            transports.push_back(
                flutter::CustomEncodableValue(TransportType::kInfrared));
        }

        descriptors.push_back(flutter::CustomEncodableValue(DeviceDescriptor(
            std::string(info.vendor), std::string(info.product),
            static_cast<int64_t>(info.model), transports)));
    }
    libdc_descriptor_iterator_free(iter);

    result(descriptors);
}

void DiveComputerHostApiImpl::StartDiscovery(
    const TransportType& transport,
    std::function<void(std::optional<FlutterError> reply)> result) {
    switch (transport) {
        case TransportType::kBle: {
            ble_scanner_ = std::make_unique<BleScanner>();
            ble_scanner_->SetOnDeviceDiscovered(
                [this](DiscoveredDevice device) {
                    flutter_api_->OnDeviceDiscovered(
                        device, [] {}, [](const auto&) {});
                });
            ble_scanner_->SetOnComplete([this]() {
                flutter_api_->OnDiscoveryComplete(
                    [] {}, [](const auto&) {});
            });
            ble_scanner_->Start();
            result(std::nullopt);
            break;
        }
        case TransportType::kSerial:
        case TransportType::kUsb: {
            serial_scanner_ = std::make_unique<SerialScanner>();
            serial_scanner_->SetOnDeviceDiscovered(
                [this](DiscoveredDevice device) {
                    flutter_api_->OnDeviceDiscovered(
                        device, [] {}, [](const auto&) {});
                });
            serial_scanner_->SetOnComplete([this]() {
                flutter_api_->OnDiscoveryComplete(
                    [] {}, [](const auto&) {});
            });
            serial_scanner_->Start();
            result(std::nullopt);
            break;
        }
        default:
            result(FlutterError("unsupported_transport",
                                "Transport not yet supported on Windows"));
            break;
    }
}

std::optional<FlutterError> DiveComputerHostApiImpl::StopDiscovery() {
    if (ble_scanner_) {
        ble_scanner_->Stop();
        ble_scanner_.reset();
    }
    if (serial_scanner_) {
        serial_scanner_->Stop();
        serial_scanner_.reset();
    }
    return std::nullopt;
}

void DiveComputerHostApiImpl::StartDownload(
    const DiscoveredDevice& device,
    std::function<void(std::optional<FlutterError> reply)> result) {
    // Acknowledge start immediately.
    result(std::nullopt);

    // Join any previous download thread.
    if (download_thread_.joinable()) {
        download_thread_.join();
    }

    // Copy device for the background thread.
    DiscoveredDevice device_copy = device;
    download_thread_ = std::thread(
        [this, dev = std::move(device_copy)]() { PerformDownload(dev); });
}

std::optional<FlutterError> DiveComputerHostApiImpl::CancelDownload() {
    if (download_session_) {
        libdc_download_cancel(download_session_);
    }
    return std::nullopt;
}

ErrorOr<std::string> DiveComputerHostApiImpl::GetLibdivecomputerVersion() {
    const char* version = libdc_get_version();
    return std::string(version);
}

// -- Private download implementation --

void DiveComputerHostApiImpl::PerformDownload(
    const DiscoveredDevice& device) {
    // Create download session.
    auto* session = libdc_download_session_new();
    if (!session) {
        flutter_api_->OnError(
            DiveComputerError("session_failed",
                              "Failed to create download session"),
            [] {}, [](const auto&) {});
        return;
    }
    download_session_ = session;

    // Connect I/O transport.
    libdc_io_callbacks_t io_callbacks = {};
    bool connected = false;

    if (device.transport() == TransportType::kSerial ||
        device.transport() == TransportType::kUsb) {
        serial_stream_ = std::make_unique<SerialIoStream>();
        if (serial_stream_->Open(device.address())) {
            io_callbacks = serial_stream_->MakeCallbacks();
            connected = true;
        }
    } else {
        // BLE transport.
        if (ble_scanner_) {
            ble_scanner_->Stop();
            ble_scanner_.reset();
        }

        uint64_t ble_address = std::strtoull(
            device.address().c_str(), nullptr, 16);
        ble_stream_ = std::make_unique<BleIoStream>();
        if (ble_stream_->ConnectAndDiscover(ble_address)) {
            io_callbacks = ble_stream_->MakeCallbacks();
            connected = true;
        }
    }

    if (!connected) {
        flutter_api_->OnError(
            DiveComputerError("connect_failed",
                              "Failed to connect to device"),
            [] {}, [](const auto&) {});
        libdc_download_session_free(session);
        download_session_ = nullptr;
        ble_stream_.reset();
        serial_stream_.reset();
        return;
    }

    // Set up download callbacks.
    libdc_download_callbacks_t dl_callbacks = {};
    dl_callbacks.on_progress = [](unsigned int current, unsigned int maximum,
                                  void* ud) {
        auto* self = static_cast<DiveComputerHostApiImpl*>(ud);
        self->flutter_api_->OnDownloadProgress(
            DownloadProgress(static_cast<int64_t>(current),
                             static_cast<int64_t>(maximum),
                             "downloading"),
            [] {}, [](const auto&) {});
    };
    dl_callbacks.on_dive = [](const libdc_parsed_dive_t* dive, void* ud) {
        auto* self = static_cast<DiveComputerHostApiImpl*>(ud);
        if (!dive) return;
        auto parsed = ConvertParsedDive(*dive);
        self->flutter_api_->OnDiveDownloaded(
            parsed, [] {}, [](const auto&) {});
    };
    dl_callbacks.userdata = this;

    // Map transport type.
    unsigned int transport_value = 0;
    switch (device.transport()) {
        case TransportType::kBle:
            transport_value = LIBDC_TRANSPORT_BLE;
            break;
        case TransportType::kUsb:
            transport_value = LIBDC_TRANSPORT_USB;
            break;
        case TransportType::kSerial:
            transport_value = LIBDC_TRANSPORT_SERIAL;
            break;
        case TransportType::kInfrared:
            transport_value = LIBDC_TRANSPORT_IRDA;
            break;
    }

    // Run the blocking download.
    unsigned int serial = 0;
    unsigned int firmware = 0;
    char error_buf[256] = {};
    int rc = libdc_download_run(
        session,
        device.vendor().c_str(), device.product().c_str(),
        static_cast<unsigned int>(device.model()),
        transport_value,
        &io_callbacks,
        nullptr, 0,  // No fingerprint (download all dives).
        &dl_callbacks,
        &serial, &firmware,
        error_buf, sizeof(error_buf));

    // Format device info.
    std::optional<std::string> serial_str =
        (serial > 0) ? std::optional<std::string>(std::to_string(serial))
                     : std::nullopt;
    std::optional<std::string> firmware_str =
        (firmware > 0) ? std::optional<std::string>(std::to_string(firmware))
                       : std::nullopt;

    // Report completion or error.
    if (rc == 0 || rc == LIBDC_STATUS_CANCELLED) {
        flutter_api_->OnDownloadComplete(
            0,
            serial_str ? &*serial_str : nullptr,
            firmware_str ? &*firmware_str : nullptr,
            [] {}, [](const auto&) {});
    } else {
        flutter_api_->OnError(
            DiveComputerError("download_error", std::string(error_buf)),
            [] {}, [](const auto&) {});
    }

    // Cleanup.
    libdc_download_session_free(session);
    download_session_ = nullptr;
    ble_stream_.reset();
    serial_stream_.reset();
}

}  // namespace libdivecomputer_plugin
