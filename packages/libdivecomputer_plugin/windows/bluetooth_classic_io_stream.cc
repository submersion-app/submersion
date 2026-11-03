#include "bluetooth_classic_io_stream.h"

#include <cstdio>

#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Foundation.h>

#include <libdivecomputer/bluetooth.h>

#include "native_logger.h"

namespace libdivecomputer_plugin {

namespace {

// Shares the BLE category so one filter in the debug log shows both routes
// a Bluetooth download tried.
constexpr char kBleCategory[] = "BLE";

std::string FormatAddress(uint64_t address) {
    char buffer[13];
    std::snprintf(buffer, sizeof(buffer), "%012llX",
                  static_cast<unsigned long long>(address));
    return std::string(buffer);
}

}  // namespace

BluetoothClassicIoStream::BluetoothClassicIoStream() = default;

BluetoothClassicIoStream::~BluetoothClassicIoStream() { Close(); }

void BluetoothClassicIoStream::LogCallback(dc_context_t* /*context*/,
                                           dc_loglevel_t loglevel,
                                           const char* /*file*/,
                                           unsigned int /*line*/,
                                           const char* function,
                                           const char* message,
                                           void* userdata) {
    auto* stream = static_cast<BluetoothClassicIoStream*>(userdata);
    const std::string line = std::string(function ? function : "") + ": " +
                             (message ? message : "");
    switch (loglevel) {
        case DC_LOGLEVEL_ERROR:
            stream->last_error_ = line;
            NativeLogger::Error(kBleCategory, "Classic: " + line);
            break;
        case DC_LOGLEVEL_WARNING:
            NativeLogger::Warn(kBleCategory, "Classic: " + line);
            break;
        default:
            NativeLogger::Debug(kBleCategory, "Classic: " + line);
            break;
    }
}

std::string BluetoothClassicIoStream::Open(uint64_t address) {
    Close();
    last_error_.clear();
    if (dc_context_new(&context_) != DC_STATUS_SUCCESS) {
        context_ = nullptr;
        return "could not create a libdivecomputer context";
    }
    dc_context_set_loglevel(context_, DC_LOGLEVEL_INFO);
    dc_context_set_logfunc(context_, &BluetoothClassicIoStream::LogCallback,
                           this);

    NativeLogger::Debug(kBleCategory,
                        "Connecting over Bluetooth Classic to " +
                            FormatAddress(address));
    // Port 0: Winsock looks the Serial Port Profile channel up through SDP.
    const dc_status_t status = dc_bluetooth_open(
        &iostream_, context_, static_cast<dc_bluetooth_address_t>(address), 0);
    if (status != DC_STATUS_SUCCESS) {
        iostream_ = nullptr;
        std::string reason =
            "Bluetooth Classic connect to " + FormatAddress(address) +
            " failed (status " + std::to_string(static_cast<int>(status)) +
            ")";
        if (!last_error_.empty()) reason += ": " + last_error_;
        Close();
        return reason;
    }
    NativeLogger::Info(kBleCategory, "Connected over Bluetooth Classic to " +
                                         FormatAddress(address));
    return "";
}

libdc_io_callbacks_t BluetoothClassicIoStream::MakeCallbacks() {
    libdc_io_callbacks_t cbs = {};
    cbs.userdata = this;
    cbs.set_timeout = SetTimeoutCallback;
    cbs.read = ReadCallback;
    cbs.write = WriteCallback;
    cbs.close = CloseCallback;
    cbs.poll = PollCallback;
    cbs.purge = PurgeCallback;
    cbs.sleep = SleepCallback;
    // An RFCOMM socket has no line settings, ioctls, DTR or RTS.
    cbs.ioctl = nullptr;
    cbs.configure = nullptr;
    cbs.set_dtr = nullptr;
    cbs.set_rts = nullptr;
    return cbs;
}

void BluetoothClassicIoStream::Close() {
    if (iostream_) {
        dc_iostream_close(iostream_);
        iostream_ = nullptr;
    }
    if (context_) {
        dc_context_free(context_);
        context_ = nullptr;
    }
}

bool BluetoothClassicIoStream::IsPaired(uint64_t address) {
    // catch (...) rather than winrt::hresult_error alone: nothing above the
    // download thread would catch a WinRT error, and it is not a
    // std::exception (issue #2507).
    try {
        auto device =
            winrt::Windows::Devices::Bluetooth::BluetoothDevice::
                FromBluetoothAddressAsync(address)
                    .get();
        if (!device) return false;
        return device.DeviceInformation().Pairing().IsPaired();
    } catch (...) {
        return false;
    }
}

int BluetoothClassicIoStream::SetTimeoutCallback(void* userdata,
                                                 int timeout) {
    auto* stream = static_cast<BluetoothClassicIoStream*>(userdata);
    if (!stream->iostream_) return LIBDC_STATUS_IO;
    return dc_iostream_set_timeout(stream->iostream_, timeout);
}

int BluetoothClassicIoStream::ReadCallback(void* userdata, void* data,
                                           size_t size, size_t* actual) {
    auto* stream = static_cast<BluetoothClassicIoStream*>(userdata);
    if (!stream->iostream_) return LIBDC_STATUS_IO;
    return dc_iostream_read(stream->iostream_, data, size, actual);
}

int BluetoothClassicIoStream::WriteCallback(void* userdata, const void* data,
                                            size_t size, size_t* actual) {
    auto* stream = static_cast<BluetoothClassicIoStream*>(userdata);
    if (!stream->iostream_) return LIBDC_STATUS_IO;
    return dc_iostream_write(stream->iostream_, data, size, actual);
}

int BluetoothClassicIoStream::CloseCallback(void* userdata) {
    auto* stream = static_cast<BluetoothClassicIoStream*>(userdata);
    stream->Close();
    return LIBDC_STATUS_SUCCESS;
}

int BluetoothClassicIoStream::PollCallback(void* userdata, int timeout) {
    auto* stream = static_cast<BluetoothClassicIoStream*>(userdata);
    if (!stream->iostream_) return LIBDC_STATUS_IO;
    return dc_iostream_poll(stream->iostream_, timeout);
}

int BluetoothClassicIoStream::PurgeCallback(void* userdata,
                                            unsigned int direction) {
    auto* stream = static_cast<BluetoothClassicIoStream*>(userdata);
    if (!stream->iostream_) return LIBDC_STATUS_IO;
    return dc_iostream_purge(stream->iostream_,
                             static_cast<dc_direction_t>(direction));
}

int BluetoothClassicIoStream::SleepCallback(void* userdata,
                                            unsigned int milliseconds) {
    auto* stream = static_cast<BluetoothClassicIoStream*>(userdata);
    if (!stream->iostream_) return LIBDC_STATUS_IO;
    return dc_iostream_sleep(stream->iostream_, milliseconds);
}

}  // namespace libdivecomputer_plugin
