#ifndef DIVE_COMPUTER_HOST_API_IMPL_H_
#define DIVE_COMPUTER_HOST_API_IMPL_H_

#include <flutter/binary_messenger.h>

#include <memory>

#include "dive_computer_api.g.h"

namespace libdivecomputer_plugin {

class DiveComputerHostApiImpl : public DiveComputerHostApi {
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
      std::function<void(std::optional<FlutterError> reply)> result) override;

  std::optional<FlutterError> CancelDownload() override;

  ErrorOr<std::string> GetLibdivecomputerVersion() override;

 private:
  std::unique_ptr<DiveComputerFlutterApi> flutter_api_;
};

}  // namespace libdivecomputer_plugin

#endif  // DIVE_COMPUTER_HOST_API_IMPL_H_
