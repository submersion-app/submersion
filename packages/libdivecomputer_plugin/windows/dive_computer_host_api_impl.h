#ifndef DIVE_COMPUTER_HOST_API_IMPL_H_
#define DIVE_COMPUTER_HOST_API_IMPL_H_

#include <flutter/binary_messenger.h>
#include <flutter/plugin_registrar.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <queue>
#include <string>
#include <thread>

#include "ble_io_stream.h"
#include "ble_scanner.h"
#include "dive_computer_api.g.h"
#include "serial_io_stream.h"
#include "serial_scanner.h"
#include "usbhid_io_stream.h"

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

class DiveComputerHostApiImpl : public DiveComputerHostApi,
                                public flutter::Plugin {
 public:
  explicit DiveComputerHostApiImpl(flutter::PluginRegistrarWindows* registrar);
  ~DiveComputerHostApiImpl() override;

  void GetDeviceDescriptors(
      std::function<void(ErrorOr<flutter::EncodableList> reply)> result)
      override;

  void StartDiscovery(
      const TransportType& transport,
      std::function<void(std::optional<FlutterError> reply)> result) override;

  std::optional<FlutterError> StopDiscovery() override;

  void StartDownload(
      const DiscoveredDevice& device,
      const std::string* fingerprint,
      bool sync_clock,
      std::function<void(std::optional<FlutterError> reply)> result) override;

  std::optional<FlutterError> CancelDownload() override;

  std::optional<FlutterError> SubmitPinCode(const std::string& pin_code) override;

  void ParseRawDiveData(
      const std::string& vendor,
      const std::string& product,
      int64_t model,
      const std::vector<uint8_t>& data,
      std::function<void(ErrorOr<ParsedDive> reply)> result) override;

  ErrorOr<std::string> GetLibdivecomputerVersion() override;

 private:
  void PerformDownload(const DiscoveredDevice& device,
                       const std::optional<std::string>& fingerprint = std::nullopt,
                       bool sync_clock = false);

  // Scanner and transport callbacks arrive on WinRT thread-pool threads and
  // the download thread, not the platform thread Flutter requires pigeon
  // calls to run on (issue #4039: a Perdix 2 connected and downloaded, but
  // the UI never showed it, because the engine can silently drop a call sent
  // from the wrong thread). Every call into |flutter_api_| that can happen
  // off the platform thread must be queued through this and run once the
  // platform thread's message loop picks up the wakeup message.
  void PostToPlatformThread(std::function<void()> task);
  void RunPendingTasks();

  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  HWND window_ = nullptr;
  int window_proc_delegate_id_ = -1;
  std::mutex task_mutex_;
  std::queue<std::function<void()>> pending_tasks_;

  std::unique_ptr<DiveComputerFlutterApi> flutter_api_;
  std::unique_ptr<BleScanner> ble_scanner_;
  std::unique_ptr<SerialScanner> serial_scanner_;
  std::unique_ptr<BleIoStream> ble_stream_;
  std::unique_ptr<SerialIoStream> serial_stream_;
  std::unique_ptr<UsbHidIoStream> usbhid_stream_;
  libdc_download_session_t* download_session_ = nullptr;
  std::thread download_thread_;
};

}  // namespace libdivecomputer_plugin

#endif  // DIVE_COMPUTER_HOST_API_IMPL_H_
