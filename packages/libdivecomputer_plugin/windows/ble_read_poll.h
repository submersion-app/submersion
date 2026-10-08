#ifndef BLE_READ_POLL_H_
#define BLE_READ_POLL_H_

#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <vector>

#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>

namespace libdivecomputer_plugin {

// Response path for a characteristic that can be read but can neither notify
// nor indicate (the Seac Tablet, issue #1454): every reply is fetched with a
// GATT read whenever libdivecomputer asks for bytes.
//
// The same state machine as darwin's ReadPollPolicy.swift and Android's
// ReadPollPolicy.kt, which carry the unit tests:
//  - at most one read in flight; a read that outlives a read() timeout is
//    adopted by the next read() instead of being doubled;
//  - an empty value or a failed read is re-read after kRetryDelay, never at
//    once, so libdivecomputer's packet loop cannot spin on zero-byte reads;
//  - Purge() discards the value of a read already in flight.
// Replies are queued one entry per packet, and Read() returns bytes from at
// most one entry, the same contract as the notification path.
class BleReadPoller {
 public:
  explicit BleReadPoller(
      winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
          GattCharacteristic characteristic);
  ~BleReadPoller();

  BleReadPoller(const BleReadPoller&) = delete;
  BleReadPoller& operator=(const BleReadPoller&) = delete;

  // libdivecomputer read(). timeout_ms follows BleIoStream::timeout_ms_:
  // INT32_MAX means no timeout.
  int Read(void* data, size_t size, size_t* actual, int timeout_ms);
  // libdivecomputer poll(): negative means no timeout, zero never blocks.
  int Poll(int timeout_ms);
  void Purge();
  // Fail any waiting Read() and ignore completions still in flight.
  void Close();

 private:
  using Clock = std::chrono::steady_clock;
  static constexpr std::chrono::milliseconds kRetryDelay{100};
  static constexpr std::chrono::milliseconds kWaitSlice{100};

  // Shared with in-flight read completions, which may run after this poller
  // is destroyed, so they capture this state and never `this`.
  struct State {
    std::mutex mutex;
    std::condition_variable cv;
    std::deque<std::vector<uint8_t>> chunks;
    bool read_in_flight = false;
    bool discard_in_flight = false;
    bool closed = false;
    Clock::time_point retry_not_before{};
  };

  // Wait, issuing reads as needed, until a packet is queued (SUCCESS), the
  // deadline passes (TIMEOUT) or Close() runs (IO). Called and returns with
  // `lock` held on state_->mutex.
  int AwaitPacket(std::unique_lock<std::mutex>& lock,
                  Clock::time_point deadline);
  // Start one asynchronous uncached read. False if it could not be issued.
  bool IssueRead();

  std::shared_ptr<State> state_ = std::make_shared<State>();
  winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
      GattCharacteristic characteristic_{nullptr};
};

}  // namespace libdivecomputer_plugin

#endif  // BLE_READ_POLL_H_
