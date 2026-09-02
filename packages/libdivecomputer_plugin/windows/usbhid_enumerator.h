#ifndef USBHID_ENUMERATOR_H_
#define USBHID_ENUMERATOR_H_

#include <functional>
#include <string>
#include <vector>

namespace libdivecomputer_plugin {

// A USB HID device present on the machine.
struct UsbHidDevice {
  unsigned short vendor_id = 0;
  unsigned short product_id = 0;
  // Device interface path, which is what CreateFile opens.
  std::wstring path;
  // The HID product string, empty when the device reports none.
  std::string product_name;

  // What to show in logs and probe messages: the device's own name when it
  // has one, its identifiers otherwise.
  std::string DisplayName() const;
};

// Lists attached HID devices that `is_match` accepts, reporting every device
// considered through `log`.
//
// There is no allowlist here. Which HID device belongs to which dive computer
// is libdivecomputer's knowledge, held in the vendor and product id tables
// inside dc_filter_uwatec and dc_filter_suunto and reachable through
// libdc_usbhid_match. The caller passes that question in as `is_match`.
//
// `log` may be empty. It is here because the two failures a user reports look
// identical from the outside: "the computer is not enumerating at all" and "it
// enumerated but did not match the selected model". Nobody working on this has
// the hardware, so a backend that can reach a log sink should pass one.
std::vector<UsbHidDevice> EnumerateMatchingUsbHidDevices(
    const std::function<bool(unsigned short, unsigned short)>& is_match,
    const std::function<void(const std::string&)>& log);

}  // namespace libdivecomputer_plugin

#endif  // USBHID_ENUMERATOR_H_
