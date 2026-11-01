#ifndef BLE_SCANNER_H_
#define BLE_SCANNER_H_

#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <set>
#include <string>
#include <utility>

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

  // Why Windows refused to start a scan.
  struct StartFailure {
    // The radio is off or missing, as opposed to any other failure.
    bool radio_unavailable;
    // HRESULT code and message, for the log and the error reply.
    std::string reason;
  };

  // Starts the advertisement watcher. Returns the failure when Windows
  // refuses to scan, or nullopt once the watcher is running.
  //
  // WinRT reports that refusal as a winrt::hresult_error, which does not
  // derive from std::exception. The pigeon handler that calls this only
  // catches std::exception, so an error let out of here reaches
  // std::terminate and the whole app aborts (issue #2507).
  std::optional<StartFailure> Start();

  // Never throws, for the same reason.
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

  // Matches a single candidate name against the descriptor database, trying
  // the Pelagic model-code scheme first. Empty when [name] is empty, so a
  // caller can try it unconditionally without a separate emptiness check.
  static std::optional<libdc_descriptor_info_t> MatchDescriptorName(
      const std::string& name);

  // Logs an advertisement that was received but not recognized as a
  // supported dive computer, once per address per scan. Diagnostic only:
  // helps tell "nothing is advertising" apart from "something is
  // advertising but this scanner does not recognize its name" (triage for
  // a Perdix 2 that Windows' own Bluetooth settings list but this scanner
  // never reports).
  void LogUnmatchedOnce(uint64_t address, const std::string& name);

  // Matches [address] against a supported descriptor, trying
  // [primary_name] (the raw advertisement's local name, which may be
  // empty) first and, only if that does not match, the name Windows'
  // Bluetooth stack has separately resolved and cached for the address.
  // Some dive computers advertise with no name, or a name the matcher does
  // not recognize, in the specific packets this watcher sees, while
  // Windows' own Bluetooth settings reliably resolve a name for the same
  // address from its broader, longer-running scan -- this mirrors that
  // fallback (Android's BleScanner.kt already falls back from
  // scanRecord.deviceName to device.name the same way). Returns the
  // matched descriptor and the name that matched, or nullopt.
  std::optional<std::pair<libdc_descriptor_info_t, std::string>> MatchName(
      uint64_t address, const std::string& primary_name);

  winrt::Windows::Devices::Bluetooth::Advertisement::
      BluetoothLEAdvertisementWatcher watcher_{nullptr};
  winrt::event_token received_token_;
  winrt::event_token stopped_token_;

  DeviceCallback on_device_discovered_;
  CompleteCallback on_complete_;

  std::mutex seen_mutex_;
  std::set<uint64_t> seen_addresses_;
  // Addresses already logged as unmatched or unnamed, so a device that
  // keeps advertising without a recognized name does not spam the debug
  // log once per packet.
  std::set<uint64_t> logged_unmatched_;
  // Addresses already sent through the OS name resolution fallback this
  // scan, win or lose: that call blocks on a Windows round trip, so it
  // must run at most once per address, not once per advertisement packet.
  std::set<uint64_t> resolve_attempted_;
};

}  // namespace libdivecomputer_plugin

#endif  // BLE_SCANNER_H_
