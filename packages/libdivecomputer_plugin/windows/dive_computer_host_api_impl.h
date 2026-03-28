#ifndef DIVE_COMPUTER_HOST_API_IMPL_H_
#define DIVE_COMPUTER_HOST_API_IMPL_H_

#include <flutter/binary_messenger.h>
#include <flutter/plugin_registrar.h>

#include <memory>
#include <optional>
#include <string>
#include <thread>

#include "ble_io_stream.h"
#include "ble_scanner.h"
#include "dive_computer_api.g.h"
#include "serial_io_stream.h"
#include "serial_scanner.h"

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

class DiveComputerHostApiImpl : public DiveComputerHostApi,
                                public flutter::Plugin {
 public:
  explicit DiveComputerHostApiImpl(flutter::BinaryMessenger* messenger);
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
                       const std::optional<std::string>& fingerprint = std::nullopt);

  std::unique_ptr<DiveComputerFlutterApi> flutter_api_;
  std::unique_ptr<BleScanner> ble_scanner_;
  std::unique_ptr<SerialScanner> serial_scanner_;
  std::unique_ptr<BleIoStream> ble_stream_;
  std::unique_ptr<SerialIoStream> serial_stream_;
  libdc_download_session_t* download_session_ = nullptr;
  std::thread download_thread_;
};

}  // namespace libdivecomputer_plugin

#endif  // DIVE_COMPUTER_HOST_API_IMPL_H_
