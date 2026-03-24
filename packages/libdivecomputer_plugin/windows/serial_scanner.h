#ifndef SERIAL_SCANNER_H_
#define SERIAL_SCANNER_H_

#include <functional>
#include <string>
#include <thread>
#include <vector>

#include "dive_computer_api.g.h"

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

// Returns a list of available COM port names (e.g., "COM3", "COM4").
std::vector<std::string> EnumerateAvailableSerialPorts();

// Enumerates serial (COM) ports using SetupDi and matches against
// libdivecomputer descriptors.
class SerialScanner {
 public:
  using DeviceCallback = std::function<void(DiscoveredDevice)>;
  using CompleteCallback = std::function<void()>;

  SerialScanner();
  ~SerialScanner();

  void SetOnDeviceDiscovered(DeviceCallback callback);
  void SetOnComplete(CompleteCallback callback);

  void Start();
  void Stop();

 private:
  void EnumerateSerialPorts();

  DeviceCallback on_device_discovered_;
  CompleteCallback on_complete_;
  std::thread scan_thread_;
};

}  // namespace libdivecomputer_plugin

#endif  // SERIAL_SCANNER_H_
