#include "ble_read_poll.h"

#include <algorithm>
#include <cstring>
#include <string>
#include <utility>

#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>

extern "C" {
#include "libdc_wrapper.h"
}

#include "native_logger.h"

namespace libdivecomputer_plugin {

using namespace winrt::Windows::Devices::Bluetooth;
using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;
using namespace winrt::Windows::Storage::Streams;

namespace {

constexpr char kBleCategory[] = "BLE";

}  // namespace

BleReadPoller::BleReadPoller(GattCharacteristic characteristic)
    : characteristic_(std::move(characteristic)) {}

BleReadPoller::~BleReadPoller() { Close(); }

int BleReadPoller::Read(void* data, size_t size, size_t* actual,
                        int timeout_ms) {
    const auto deadline =
        (timeout_ms == INT32_MAX)
            ? Clock::time_point::max()
            : Clock::now() + std::chrono::milliseconds(timeout_ms);
    std::unique_lock<std::mutex> lock(state_->mutex);
    const int status = AwaitPacket(lock, deadline);
    if (status != LIBDC_STATUS_SUCCESS) {
        *actual = 0;
        return status;
    }

    // At most one packet per read, a partial packet staying at the front, as
    // on the notification path.
    std::vector<uint8_t>& chunk = state_->chunks.front();
    const size_t count = std::min(size, chunk.size());
    std::memcpy(data, chunk.data(), count);
    if (count < chunk.size()) {
        chunk.erase(chunk.begin(), chunk.begin() + count);
    } else {
        state_->chunks.pop_front();
    }
    *actual = count;
    return LIBDC_STATUS_SUCCESS;
}

int BleReadPoller::Poll(int timeout_ms) {
    std::unique_lock<std::mutex> lock(state_->mutex);
    if (!state_->chunks.empty()) return LIBDC_STATUS_SUCCESS;
    if (timeout_ms == 0) return LIBDC_STATUS_TIMEOUT;
    const auto deadline =
        (timeout_ms < 0)
            ? Clock::time_point::max()
            : Clock::now() + std::chrono::milliseconds(timeout_ms);
    return AwaitPacket(lock, deadline);
}

void BleReadPoller::Purge() {
    std::lock_guard<std::mutex> lock(state_->mutex);
    state_->chunks.clear();
    // The value of a read already on the wire answers a command
    // libdivecomputer has abandoned.
    if (state_->read_in_flight) state_->discard_in_flight = true;
}

void BleReadPoller::Close() {
    {
        std::lock_guard<std::mutex> lock(state_->mutex);
        state_->closed = true;
        state_->chunks.clear();
    }
    state_->cv.notify_all();
}

int BleReadPoller::AwaitPacket(std::unique_lock<std::mutex>& lock,
                               Clock::time_point deadline) {
    State& state = *state_;
    while (state.chunks.empty()) {
        if (state.closed) return LIBDC_STATUS_IO;
        const auto now = Clock::now();
        if (now >= deadline) return LIBDC_STATUS_TIMEOUT;

        if (!state.read_in_flight && now >= state.retry_not_before) {
            state.read_in_flight = true;
            // Unlocked while issuing: Completed() runs the handler inline when
            // the read has already finished, and the handler takes this
            // non-recursive mutex (the same trap as the credit grant).
            lock.unlock();
            const bool issued = IssueRead();
            lock.lock();
            if (!issued) {
                state.read_in_flight = false;
                state.retry_not_before = Clock::now() + kRetryDelay;
            }
            // Re-check: an inline completion may already have queued a packet.
            continue;
        }

        // Sliced so a completion that queued nothing (an empty value or a
        // failed read) is followed by a retry without needing its own wakeup.
        const auto slice_end =
            (deadline - now > kWaitSlice) ? now + kWaitSlice : deadline;
        state.cv.wait_until(lock, slice_end);
    }
    return LIBDC_STATUS_SUCCESS;
}

bool BleReadPoller::IssueRead() {
    try {
        // Uncached: the default may answer from Windows' attribute cache,
        // which holds the previous packet instead of asking for the next.
        auto operation =
            characteristic_.ReadValueAsync(BluetoothCacheMode::Uncached);
        operation.Completed([state = state_](auto const& op, auto const&) {
            std::vector<uint8_t> value;
            bool ok = false;
            try {
                auto result = op.GetResults();
                if (result.Status() == GattCommunicationStatus::Success) {
                    auto reader = DataReader::FromBuffer(result.Value());
                    value.resize(reader.UnconsumedBufferLength());
                    if (!value.empty()) reader.ReadBytes(value);
                    ok = !value.empty();
                }
            } catch (...) {
                ok = false;
            }
            {
                std::lock_guard<std::mutex> lock(state->mutex);
                state->read_in_flight = false;
                if (!state->closed) {
                    if (state->discard_in_flight) {
                        state->discard_in_flight = false;
                    } else if (ok) {
                        state->chunks.push_back(std::move(value));
                    } else {
                        state->retry_not_before = Clock::now() + kRetryDelay;
                    }
                }
            }
            state->cv.notify_all();
        });
        return true;
    } catch (const winrt::hresult_error& e) {
        NativeLogger::Warn(kBleCategory,
                           "Read-poll read could not be issued: " +
                               winrt::to_string(e.message()));
        return false;
    } catch (...) {
        NativeLogger::Warn(kBleCategory,
                           "Read-poll read could not be issued");
        return false;
    }
}

}  // namespace libdivecomputer_plugin
