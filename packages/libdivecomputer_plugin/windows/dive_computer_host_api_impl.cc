#include "dive_computer_host_api_impl.h"

#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

DiveComputerHostApiImpl::DiveComputerHostApiImpl(
    flutter::BinaryMessenger* messenger)
    : flutter_api_(
          std::make_unique<DiveComputerFlutterApi>(messenger)) {}

DiveComputerHostApiImpl::~DiveComputerHostApiImpl() = default;

void DiveComputerHostApiImpl::GetDeviceDescriptors(
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  libdc_descriptor_iterator_t* iter = libdc_descriptor_iterator_new();
  if (iter == nullptr) {
    result(FlutterError("internal_error",
                        "Failed to create descriptor iterator"));
    return;
  }

  flutter::EncodableList descriptors;
  libdc_descriptor_info_t info;
  int rc;
  while ((rc = libdc_descriptor_iterator_next(iter, &info)) == 0) {
    flutter::EncodableList transports;
    if (info.transports & LIBDC_TRANSPORT_BLE) {
      transports.push_back(
          flutter::CustomEncodableValue(TransportType::kBle));
    }
    if (info.transports & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) {
      transports.push_back(
          flutter::CustomEncodableValue(TransportType::kUsb));
    }
    if (info.transports & LIBDC_TRANSPORT_SERIAL) {
      transports.push_back(
          flutter::CustomEncodableValue(TransportType::kSerial));
    }
    if (info.transports & LIBDC_TRANSPORT_IRDA) {
      transports.push_back(
          flutter::CustomEncodableValue(TransportType::kInfrared));
    }

    descriptors.push_back(flutter::CustomEncodableValue(DeviceDescriptor(
        std::string(info.vendor), std::string(info.product),
        static_cast<int64_t>(info.model), transports)));
  }
  libdc_descriptor_iterator_free(iter);

  result(descriptors);
}

void DiveComputerHostApiImpl::StartDiscovery(
    const TransportType& transport,
    std::function<void(std::optional<FlutterError> reply)> result) {
  // Windows BLE discovery requires WinRT BLE APIs.
  // Stubbed for now.
  result(FlutterError("not_implemented",
                      "BLE discovery is not yet implemented on Windows"));
}

std::optional<FlutterError> DiveComputerHostApiImpl::StopDiscovery() {
  return std::nullopt;
}

void DiveComputerHostApiImpl::StartDownload(
    const DiscoveredDevice& device,
    std::function<void(std::optional<FlutterError> reply)> result) {
  // Windows download requires WinRT BLE or USB transport.
  // Stubbed for now.
  result(FlutterError("not_implemented",
                      "Download is not yet implemented on Windows"));
}

std::optional<FlutterError> DiveComputerHostApiImpl::CancelDownload() {
  return std::nullopt;
}

ErrorOr<std::string> DiveComputerHostApiImpl::GetLibdivecomputerVersion() {
  const char* version = libdc_get_version();
  return std::string(version);
}

}  // namespace libdivecomputer_plugin
