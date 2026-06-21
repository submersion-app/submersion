#ifndef BLE_IO_STREAM_H_
#define BLE_IO_STREAM_H_

#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <functional>
#include <mutex>
#include <string>
#include <vector>

#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

// Bridges WinRT BLE GATT communication to libdivecomputer's synchronous
// iostream interface using condition variables.
//
// libdivecomputer calls read/write synchronously on a download thread.
// This class translates those calls to async WinRT GATT operations,
// blocking with condition_variable until the BLE operation completes.
class BleIoStream {
 public:
  BleIoStream();
  ~BleIoStream();

  // Connect to a BLE device by address and discover GATT characteristics.
  // Blocks until ready or timeout. Returns true on success.
  bool ConnectAndDiscover(uint64_t bluetooth_address);

  // Build the libdc_io_callbacks_t struct pointing to this instance.
  // The caller must keep this BleIoStream alive while the callbacks are
  // in use.
  libdc_io_callbacks_t MakeCallbacks();

  // Disconnect and clean up.
  void Close();

  // Submit a PIN code entered by the user.
  void SubmitPinCode(const std::string& pin);

  // Set the device address for access code storage.
  void SetDeviceAddress(const std::string& address);

  // Set callback for PIN code requests.
  void SetOnPinCodeRequired(std::function<void(const std::string&)> callback);

 private:
  // Discover GATT services and find the best write/notify characteristic
  // pair.
  bool DiscoverCharacteristics();

  // C callback implementations.
  static int SetTimeoutCallback(void* userdata, int timeout);
  static int ReadCallback(void* userdata, void* data, size_t size,
                          size_t* actual);
  static int WriteCallback(void* userdata, const void* data, size_t size,
                           size_t* actual);
  static int CloseCallback(void* userdata);
  static int IoctlCallback(void* userdata, unsigned int request,
                            void* data, size_t size);
  static int PollCallback(void* userdata, int timeout);
  static int PurgeCallback(void* userdata, unsigned int direction);

  // I/O operations.
  int PerformRead(void* data, size_t size, size_t* actual);
  int PerformWrite(const void* data, size_t size, size_t* actual);

  // GATT notification handler.
  void OnCharacteristicValueChanged(
      winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
          GattCharacteristic const& sender,
      winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
          GattValueChangedEventArgs const& args);

  // Known service/characteristic UUIDs for dive computers.
  static const winrt::guid kPreferredServiceUuid;
  static const winrt::guid kPreferredWriteUuid;
  static const winrt::guid kPreferredNotifyUuid;
  static const winrt::guid kHalcyonSymbiosTxUuid;
  static const winrt::guid kHalcyonSymbiosRxUuid;

  winrt::Windows::Devices::Bluetooth::BluetoothLEDevice device_{nullptr};
  // Held for the connection's lifetime to keep a throughput-optimized
  // (low-interval) connection request active; released in Close(). A faster
  // connection interval lets a dive computer's serial->BLE bridge drain its
  // buffer during bulk logbook dumps without dropping notifications (#280).
  winrt::Windows::Devices::Bluetooth::
      BluetoothLEPreferredConnectionParametersRequest
          preferred_connection_request_{nullptr};
  winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
      GattCharacteristic write_characteristic_{nullptr};
  winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
      GattCharacteristic notify_characteristic_{nullptr};
  winrt::event_token notify_token_;

  std::mutex read_mutex_;
  std::condition_variable read_cv_;
  // One entry per GATT notification. libdivecomputer's packet parsers
  // require each read to return bytes from at most one notification;
  // coalescing them into a flat buffer loses packet boundaries.
  std::deque<std::vector<uint8_t>> read_chunks_;

  int timeout_ms_ = 10000;
  std::string device_name_;

  // PIN code authentication support.
  std::mutex pin_mutex_;
  std::condition_variable pin_cv_;
  std::string pending_pin_;
  bool pin_ready_ = false;
  std::string device_address_;

  // Callback when PIN code is needed (called on download thread,
  // must dispatch to main thread internally).
  std::function<void(const std::string&)> on_pin_code_required_;

  std::vector<uint8_t> LoadAccessCode();
  void SaveAccessCode(const uint8_t* data, size_t size);
};

}  // namespace libdivecomputer_plugin

#endif  // BLE_IO_STREAM_H_
