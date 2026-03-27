#include "dive_computer_host_api_impl.h"

#include "dive_converter.h"
#include "serial_scanner.h"

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
    const std::string* fingerprint,
    std::function<void(std::optional<FlutterError> reply)> result) {
    // Acknowledge start immediately.
    result(std::nullopt);

    // Join any previous download thread.
    if (download_thread_.joinable()) {
        download_thread_.join();
    }

    // Copy device and fingerprint for the background thread (pointer would dangle).
    DiscoveredDevice device_copy = device;
    std::optional<std::string> fp_copy =
        fingerprint ? std::optional<std::string>(*fingerprint) : std::nullopt;
    download_thread_ = std::thread(
        [this, dev = std::move(device_copy), fp = std::move(fp_copy)]() {
            PerformDownload(dev, fp);
        });
}

std::optional<FlutterError> DiveComputerHostApiImpl::CancelDownload() {
    if (download_session_) {
        libdc_download_cancel(download_session_);
    }
    return std::nullopt;
}

std::optional<FlutterError> DiveComputerHostApiImpl::SubmitPinCode(
    const std::string& pin_code) {
    if (ble_stream_) {
        ble_stream_->SubmitPinCode(pin_code);
    }
    return std::nullopt;
}

void DiveComputerHostApiImpl::ParseRawDiveData(
    const std::string& vendor,
    const std::string& product,
    int64_t model,
    const std::vector<uint8_t>& data,
    std::function<void(ErrorOr<ParsedDive> reply)> result) {
    result(FlutterError("UNSUPPORTED",
                        "Raw dive parsing not yet implemented on Windows"));
}

ErrorOr<std::string> DiveComputerHostApiImpl::GetLibdivecomputerVersion() {
    const char* version = libdc_get_version();
    return std::string(version);
}

// -- Private download implementation --

void DiveComputerHostApiImpl::PerformDownload(
    const DiscoveredDevice& device,
    const std::optional<std::string>& fingerprint) {
    // Create download session. The session holds a dc_context_t (logging) and a
    // cancelled flag. It is intentionally reused across multiple libdc_download_run
    // calls during multi-port probing — each call creates its own internal state.
    auto* session = libdc_download_session_new();
    if (!session) {
        flutter_api_->OnError(
            DiveComputerError("session_failed",
                              "Failed to create download session"),
            [] {}, [](const auto&) {});
        return;
    }
    download_session_ = session;

    // Set up download callbacks.
    // When probing multiple serial ports, dives are buffered to avoid
    // dispatching phantom dives from a wrong port to Flutter.
    struct DownloadContext {
        DiveComputerHostApiImpl* self;
        bool buffer_dives = false;
        std::vector<ParsedDive> buffered_dives;
    };
    DownloadContext dl_ctx{this};

    libdc_download_callbacks_t dl_callbacks = {};
    dl_callbacks.on_progress = [](unsigned int current, unsigned int maximum,
                                  void* ud) {
        auto* ctx = static_cast<DownloadContext*>(ud);
        ctx->self->flutter_api_->OnDownloadProgress(
            DownloadProgress(static_cast<int64_t>(current),
                             static_cast<int64_t>(maximum),
                             "downloading"),
            [] {}, [](const auto&) {});
    };
    dl_callbacks.on_dive = [](const libdc_parsed_dive_t* dive, void* ud) {
        auto* ctx = static_cast<DownloadContext*>(ud);
        if (!dive) return;
        auto parsed = ConvertParsedDive(*dive);
        if (ctx->buffer_dives) {
            ctx->buffered_dives.push_back(std::move(parsed));
        } else {
            ctx->self->flutter_api_->OnDiveDownloaded(
                parsed, [] {}, [](const auto&) {});
        }
    };
    dl_callbacks.userdata = &dl_ctx;

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

    // Decode fingerprint from hex string.
    std::vector<unsigned char> fp_bytes;
    if (fingerprint.has_value() && !fingerprint->empty()) {
        const auto& hex = *fingerprint;
        for (size_t i = 0; i + 1 < hex.size(); i += 2) {
            fp_bytes.push_back(
                static_cast<unsigned char>(std::stoi(hex.substr(i, 2), nullptr, 16)));
        }
    }

    // Connect I/O transport and run download.
    int rc = -1;
    unsigned int serial = 0;
    unsigned int firmware = 0;
    char error_buf[256] = {};

    if (device.transport() == TransportType::kSerial ||
        device.transport() == TransportType::kUsb) {
        // Build list of candidate serial ports.
        std::vector<std::string> ports_to_try;
        std::string address = device.address();
        bool is_com_port = (address.size() >= 4 &&
            _strnicmp(address.c_str(), "COM", 3) == 0 &&
            address[3] >= '0' && address[3] <= '9');

        if (is_com_port) {
            ports_to_try.push_back(address);
        } else {
            ports_to_try = EnumerateAvailableSerialPorts();
        }

        // Try each candidate port with a full download attempt.
        // Simply opening a port is not enough — many ports open successfully
        // even when they are not the target dive computer.
        std::string probe_log;
        bool any_opened = false;
        // Buffer dives when probing multiple ports to avoid dispatching
        // phantom dives from a wrong port to Flutter.
        dl_ctx.buffer_dives = (ports_to_try.size() > 1);
        for (const auto& port : ports_to_try) {
            dl_ctx.buffered_dives.clear();
            serial_stream_ = std::make_unique<SerialIoStream>();
            if (!serial_stream_->Open(port)) {
                probe_log += "  " + port + ": failed to open\n";
                serial_stream_.reset();
                continue;
            }

            libdc_io_callbacks_t io_callbacks = serial_stream_->MakeCallbacks();
            serial = 0;
            firmware = 0;
            memset(error_buf, 0, sizeof(error_buf));

            rc = libdc_download_run(
                session,
                device.vendor().c_str(), device.product().c_str(),
                static_cast<unsigned int>(device.model()),
                transport_value,
                &io_callbacks,
                fp_bytes.empty() ? nullptr : fp_bytes.data(),
                static_cast<unsigned int>(fp_bytes.size()),
                &dl_callbacks,
                &serial, &firmware,
                error_buf, sizeof(error_buf));

            serial_stream_.reset();
            any_opened = true;

            if (rc == 0 || rc == LIBDC_STATUS_CANCELLED) {
                break;
            }
            probe_log += "  " + port + ": download failed (rc=" +
                         std::to_string(rc) + ")\n";
        }

        if (ports_to_try.empty()) {
            flutter_api_->OnError(
                DiveComputerError("no_serial_ports",
                    "No USB serial ports found. Is the dive computer connected and powered on?"),
                [] {}, [](const auto&) {});
            libdc_download_session_free(session);
            download_session_ = nullptr;
            return;
        }

        // If auto-probe tried ports but all failed, include the log in the
        // error message so users can share it with developers.
        if (!any_opened || (rc != 0 && !probe_log.empty())) {
            std::string msg = probe_log.empty()
                ? "No dive computer found on any serial port."
                : "No dive computer found. Ports tried:\n" + probe_log;
            flutter_api_->OnError(
                DiveComputerError("connect_failed", msg),
                [] {}, [](const auto&) {});
            libdc_download_session_free(session);
            download_session_ = nullptr;
            return;
        }

        // Flush buffered dives to Flutter after a successful probe.
        for (auto& dive : dl_ctx.buffered_dives) {
            flutter_api_->OnDiveDownloaded(
                dive, [] {}, [](const auto&) {});
        }
        dl_ctx.buffered_dives.clear();
        dl_ctx.buffer_dives = false;
    } else {
        // BLE transport.
        if (ble_scanner_) {
            ble_scanner_->Stop();
            ble_scanner_.reset();
        }

        uint64_t ble_address = std::strtoull(
            device.address().c_str(), nullptr, 16);
        ble_stream_ = std::make_unique<BleIoStream>();
        ble_stream_->SetDeviceAddress(device.address());
        ble_stream_->SetOnPinCodeRequired(
            [this](const std::string& address) {
                flutter_api_->OnPinCodeRequired(
                    address, [] {}, [](const auto&) {});
            });
        if (!ble_stream_->ConnectAndDiscover(ble_address)) {
            flutter_api_->OnError(
                DiveComputerError("connect_failed",
                                  "Failed to connect to device"),
                [] {}, [](const auto&) {});
            libdc_download_session_free(session);
            download_session_ = nullptr;
            ble_stream_.reset();
            return;
        }

        libdc_io_callbacks_t io_callbacks = ble_stream_->MakeCallbacks();

        rc = libdc_download_run(
            session,
            device.vendor().c_str(), device.product().c_str(),
            static_cast<unsigned int>(device.model()),
            transport_value,
            &io_callbacks,
            fp_bytes.empty() ? nullptr : fp_bytes.data(),
            static_cast<unsigned int>(fp_bytes.size()),
            &dl_callbacks,
            &serial, &firmware,
            error_buf, sizeof(error_buf));

        ble_stream_.reset();
    }

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
}

}  // namespace libdivecomputer_plugin
