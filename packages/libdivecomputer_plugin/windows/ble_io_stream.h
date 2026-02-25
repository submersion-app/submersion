#ifndef BLE_IO_STREAM_H_
#define BLE_IO_STREAM_H_

#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <vector>

#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>
#include <winrt/Windows.Foundation.h>
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

  winrt::Windows::Devices::Bluetooth::BluetoothLEDevice device_{nullptr};
  winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
      GattCharacteristic write_characteristic_{nullptr};
  winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
      GattCharacteristic notify_characteristic_{nullptr};
  winrt::event_token notify_token_;

  std::mutex read_mutex_;
  std::condition_variable read_cv_;
  std::vector<uint8_t> read_buffer_;

  int timeout_ms_ = 10000;
  std::string device_name_;
};

}  // namespace libdivecomputer_plugin

#endif  // BLE_IO_STREAM_H_
