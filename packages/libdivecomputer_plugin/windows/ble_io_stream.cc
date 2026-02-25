#include "ble_io_stream.h"

#include <algorithm>
#include <cstring>

namespace libdivecomputer_plugin {

using namespace winrt::Windows::Devices::Bluetooth;
using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;
using namespace winrt::Windows::Foundation;
using namespace winrt::Windows::Storage::Streams;

// Same UUIDs as the macOS/iOS BleIoStream.
const winrt::guid BleIoStream::kPreferredServiceUuid{
    0xCB3C4555, 0xD670, 0x4670,
    {0xBC, 0x20, 0xB6, 0x1D, 0xBC, 0x85, 0x1E, 0x9A}};
const winrt::guid BleIoStream::kPreferredWriteUuid{
    0x6606AB42, 0x89D5, 0x4A00,
    {0xA8, 0xCE, 0x4E, 0xB5, 0xE1, 0x41, 0x4E, 0xE0}};
const winrt::guid BleIoStream::kPreferredNotifyUuid{
    0xA60B8E5C, 0xB267, 0x44D7,
    {0x97, 0x64, 0x83, 0x7C, 0xAF, 0x96, 0x48, 0x9E}};

static constexpr uint32_t kBleIoctlType = 'b';
static constexpr uint32_t kBleIoctlGetName = 0;
static constexpr uint32_t kDirectionInput = 1;

BleIoStream::BleIoStream() = default;

BleIoStream::~BleIoStream() { Close(); }

bool BleIoStream::ConnectAndDiscover(uint64_t bluetooth_address) {
    try {
        device_ = BluetoothLEDevice::FromBluetoothAddressAsync(
                      bluetooth_address)
                      .get();
        if (!device_) return false;

        device_name_ = winrt::to_string(device_.Name());
        return DiscoverCharacteristics();
    } catch (...) {
        return false;
    }
}

bool BleIoStream::DiscoverCharacteristics() {
    auto services_result =
        device_.GetGattServicesAsync(BluetoothCacheMode::Uncached).get();
    if (services_result.Status() != GattCommunicationStatus::Success) {
        return false;
    }

    struct Candidate {
        int score = -1;
        GattCharacteristic write{nullptr};
        GattCharacteristic notify{nullptr};
    };
    Candidate best;

    for (auto const& service : services_result.Services()) {
        auto chars_result =
            service.GetCharacteristicsAsync(BluetoothCacheMode::Uncached)
                .get();
        if (chars_result.Status() != GattCommunicationStatus::Success) {
            continue;
        }

        GattCharacteristic best_write{nullptr};
        int best_write_score = -1;
        GattCharacteristic best_notify{nullptr};
        int best_notify_score = -1;

        for (auto const& ch : chars_result.Characteristics()) {
            auto props = ch.CharacteristicProperties();

            // Evaluate as write candidate.
            if ((props & GattCharacteristicProperties::Write) !=
                    GattCharacteristicProperties::None ||
                (props &
                 GattCharacteristicProperties::WriteWithoutResponse) !=
                    GattCharacteristicProperties::None) {
                int ws = 0;
                if ((props &
                     GattCharacteristicProperties::WriteWithoutResponse) !=
                    GattCharacteristicProperties::None) {
                    ws += 4;
                }
                if ((props & GattCharacteristicProperties::Write) !=
                    GattCharacteristicProperties::None) {
                    ws += 2;
                }
                if (ch.Uuid() == kPreferredWriteUuid) ws += 1000;
                if (ws > best_write_score) {
                    best_write = ch;
                    best_write_score = ws;
                }
            }

            // Evaluate as notify candidate.
            if ((props & GattCharacteristicProperties::Notify) !=
                    GattCharacteristicProperties::None ||
                (props & GattCharacteristicProperties::Indicate) !=
                    GattCharacteristicProperties::None) {
                int ns = 0;
                if ((props & GattCharacteristicProperties::Notify) !=
                    GattCharacteristicProperties::None) {
                    ns += 4;
                }
                if ((props & GattCharacteristicProperties::Indicate) !=
                    GattCharacteristicProperties::None) {
                    ns += 2;
                }
                if (ch.Uuid() == kPreferredNotifyUuid) ns += 1000;
                if (ns > best_notify_score) {
                    best_notify = ch;
                    best_notify_score = ns;
                }
            }
        }

        if (!best_write || !best_notify) continue;

        int service_score = best_write_score + best_notify_score;
        if (service.Uuid() == kPreferredServiceUuid) {
            service_score += 1000;
        }

        if (service_score > best.score) {
            best = {service_score, best_write, best_notify};
        }
    }

    if (best.score < 0) return false;

    write_characteristic_ = best.write;
    notify_characteristic_ = best.notify;

    // Enable notifications.
    auto cccd_value =
        ((notify_characteristic_.CharacteristicProperties() &
          GattCharacteristicProperties::Notify) !=
         GattCharacteristicProperties::None)
            ? GattClientCharacteristicConfigurationDescriptorValue::Notify
            : GattClientCharacteristicConfigurationDescriptorValue::
                  Indicate;

    auto cccd_result =
        notify_characteristic_
            .WriteClientCharacteristicConfigurationDescriptorAsync(
                cccd_value)
            .get();
    if (cccd_result != GattCommunicationStatus::Success) {
        return false;
    }

    notify_token_ = notify_characteristic_.ValueChanged(
        {this, &BleIoStream::OnCharacteristicValueChanged});

    return true;
}

void BleIoStream::OnCharacteristicValueChanged(
    GattCharacteristic const&,
    GattValueChangedEventArgs const& args) {
    auto reader = DataReader::FromBuffer(args.CharacteristicValue());
    uint32_t length = reader.UnconsumedBufferLength();
    if (length == 0) return;

    std::vector<uint8_t> data(length);
    reader.ReadBytes(data);

    {
        std::lock_guard<std::mutex> lock(read_mutex_);
        read_buffer_.insert(read_buffer_.end(), data.begin(), data.end());
    }
    read_cv_.notify_one();
}

libdc_io_callbacks_t BleIoStream::MakeCallbacks() {
    libdc_io_callbacks_t cbs = {};
    cbs.userdata = this;
    cbs.set_timeout = SetTimeoutCallback;
    cbs.read = ReadCallback;
    cbs.write = WriteCallback;
    cbs.close = CloseCallback;
    cbs.ioctl = IoctlCallback;
    cbs.poll = PollCallback;
    cbs.purge = PurgeCallback;
    cbs.sleep = nullptr;
    return cbs;
}

void BleIoStream::Close() {
    if (notify_characteristic_) {
        notify_characteristic_.ValueChanged(notify_token_);
        try {
            notify_characteristic_
                .WriteClientCharacteristicConfigurationDescriptorAsync(
                    GattClientCharacteristicConfigurationDescriptorValue::
                        None)
                .get();
        } catch (...) {
        }
        notify_characteristic_ = nullptr;
    }
    write_characteristic_ = nullptr;
    if (device_) {
        device_.Close();
        device_ = nullptr;
    }
}

// -- C callback implementations --

int BleIoStream::SetTimeoutCallback(void* userdata, int timeout) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    stream->timeout_ms_ =
        (timeout < 0) ? INT32_MAX : std::max(timeout, 3000);
    return LIBDC_STATUS_SUCCESS;
}

int BleIoStream::ReadCallback(void* userdata, void* data, size_t size,
                               size_t* actual) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    size_t transferred = 0;
    int status = stream->PerformRead(data, size, &transferred);
    if (actual) {
        *actual = transferred;
    }
    return status;
}

int BleIoStream::WriteCallback(void* userdata, const void* data,
                                size_t size, size_t* actual) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    size_t transferred = 0;
    int status = stream->PerformWrite(data, size, &transferred);
    if (actual) {
        *actual = transferred;
    }
    return status;
}

int BleIoStream::CloseCallback(void* userdata) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    stream->Close();
    return LIBDC_STATUS_SUCCESS;
}

int BleIoStream::IoctlCallback(void* userdata, unsigned int request,
                                 void* data, size_t size) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    uint32_t ioctl_type = (request >> 8) & 0xFF;
    uint32_t ioctl_number = request & 0xFF;

    if (ioctl_type == kBleIoctlType && ioctl_number == kBleIoctlGetName) {
        if (!data || size == 0) return LIBDC_STATUS_INVALIDARGS;
        if (stream->device_name_.empty()) return LIBDC_STATUS_UNSUPPORTED;

        size_t copy_len =
            std::min(stream->device_name_.size() + 1, size);
        std::memcpy(data, stream->device_name_.c_str(), copy_len);
        static_cast<char*>(data)[copy_len - 1] = '\0';
        return LIBDC_STATUS_SUCCESS;
    }
    return LIBDC_STATUS_UNSUPPORTED;
}

int BleIoStream::PollCallback(void* userdata, int timeout) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    std::unique_lock<std::mutex> lock(stream->read_mutex_);
    if (!stream->read_buffer_.empty()) return LIBDC_STATUS_SUCCESS;
    if (timeout == 0) return LIBDC_STATUS_TIMEOUT;

    if (timeout < 0) {
        stream->read_cv_.wait(
            lock, [stream] { return !stream->read_buffer_.empty(); });
    } else {
        if (!stream->read_cv_.wait_for(
                lock, std::chrono::milliseconds(timeout),
                [stream] { return !stream->read_buffer_.empty(); })) {
            return LIBDC_STATUS_TIMEOUT;
        }
    }
    return LIBDC_STATUS_SUCCESS;
}

int BleIoStream::PurgeCallback(void* userdata, unsigned int direction) {
    if ((direction & kDirectionInput) == 0) return LIBDC_STATUS_SUCCESS;
    auto* stream = static_cast<BleIoStream*>(userdata);
    std::lock_guard<std::mutex> lock(stream->read_mutex_);
    stream->read_buffer_.clear();
    return LIBDC_STATUS_SUCCESS;
}

int BleIoStream::PerformRead(void* data, size_t size, size_t* actual) {
    std::unique_lock<std::mutex> lock(read_mutex_);

    auto deadline = (timeout_ms_ == INT32_MAX)
                        ? std::chrono::steady_clock::time_point::max()
                        : std::chrono::steady_clock::now() +
                              std::chrono::milliseconds(timeout_ms_);

    while (read_buffer_.empty()) {
        if (timeout_ms_ == INT32_MAX) {
            read_cv_.wait(
                lock, [this] { return !read_buffer_.empty(); });
        } else {
            if (!read_cv_.wait_until(
                    lock, deadline,
                    [this] { return !read_buffer_.empty(); })) {
                *actual = 0;
                return LIBDC_STATUS_TIMEOUT;
            }
        }
    }

    size_t bytes_to_read = std::min(size, read_buffer_.size());
    std::memcpy(data, read_buffer_.data(), bytes_to_read);
    read_buffer_.erase(read_buffer_.begin(),
                       read_buffer_.begin() + bytes_to_read);
    *actual = bytes_to_read;
    return LIBDC_STATUS_SUCCESS;
}

int BleIoStream::PerformWrite(const void* data, size_t size,
                               size_t* actual) {
    if (!write_characteristic_) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }

    try {
        auto writer = DataWriter();
        writer.WriteBytes(winrt::array_view<const uint8_t>(
            static_cast<const uint8_t*>(data), static_cast<uint32_t>(size)));

        auto props = write_characteristic_.CharacteristicProperties();
        bool has_write_with_response =
            (props & GattCharacteristicProperties::Write) !=
            GattCharacteristicProperties::None;

        GattWriteOption write_option =
            has_write_with_response
                ? GattWriteOption::WriteWithResponse
                : GattWriteOption::WriteWithoutResponse;

        auto result =
            write_characteristic_
                .WriteValueWithResultAsync(writer.DetachBuffer(),
                                           write_option)
                .get();
        if (result.Status() != GattCommunicationStatus::Success) {
            *actual = 0;
            return LIBDC_STATUS_IO;
        }

        *actual = size;
        return LIBDC_STATUS_SUCCESS;
    } catch (...) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }
}

}  // namespace libdivecomputer_plugin
