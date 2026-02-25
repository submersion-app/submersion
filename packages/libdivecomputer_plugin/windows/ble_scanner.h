#ifndef BLE_SCANNER_H_
#define BLE_SCANNER_H_

#include <functional>
#include <memory>
#include <mutex>
#include <set>
#include <string>

#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Foundation.h>

#include "dive_computer_api.g.h"

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

// Scans for BLE dive computers using WinRT BluetoothLEAdvertisementWatcher
// and matches discovered devices against libdivecomputer descriptors.
class BleScanner {
 public:
  using DeviceCallback = std::function<void(DiscoveredDevice)>;
  using CompleteCallback = std::function<void()>;

  BleScanner();
  ~BleScanner();

  void SetOnDeviceDiscovered(DeviceCallback callback);
  void SetOnComplete(CompleteCallback callback);

  void Start();
  void Stop();

 private:
  void OnAdvertisementReceived(
      winrt::Windows::Devices::Bluetooth::Advertisement::
          BluetoothLEAdvertisementWatcher const& watcher,
      winrt::Windows::Devices::Bluetooth::Advertisement::
          BluetoothLEAdvertisementReceivedEventArgs const& args);

  void OnWatcherStopped(
      winrt::Windows::Devices::Bluetooth::Advertisement::
          BluetoothLEAdvertisementWatcher const& watcher,
      winrt::Windows::Devices::Bluetooth::Advertisement::
          BluetoothLEAdvertisementWatcherStoppedEventArgs const& args);

  // Pelagic BLE names are typically two letters + serial digits (e.g.
  // FH025918). Returns the two-byte model code, or 0 if not a match.
  static uint32_t ParsePelagicModelCode(const std::string& name);

  winrt::Windows::Devices::Bluetooth::Advertisement::
      BluetoothLEAdvertisementWatcher watcher_{nullptr};
  winrt::event_token received_token_;
  winrt::event_token stopped_token_;

  DeviceCallback on_device_discovered_;
  CompleteCallback on_complete_;

  std::mutex seen_mutex_;
  std::set<uint64_t> seen_addresses_;
};

}  // namespace libdivecomputer_plugin

#endif  // BLE_SCANNER_H_
