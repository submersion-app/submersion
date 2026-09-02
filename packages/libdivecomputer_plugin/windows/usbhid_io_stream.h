#ifndef USBHID_IO_STREAM_H_
#define USBHID_IO_STREAM_H_

#include <Windows.h>

#include <string>
#include <vector>

#include "usbhid_enumerator.h"

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

// USB HID byte pipe for libdivecomputer, backed by the Win32 HID API.
//
// This is the transport the Scubapro G2 family and the Suunto EON Steel family
// speak over a USB cable (issue #1271). libdivecomputer already knows the HID
// framing: passing LIBDC_TRANSPORT_USBHID to dc_custom_open makes uwatec_smart.c
// and suunto_eonsteel.c size their packets as HID reports, so all this class
// owes them is one report per read and one report per write.
class UsbHidIoStream {
 public:
  UsbHidIoStream();
  ~UsbHidIoStream();

  // Opens the device. Returns an empty string on success, or the reason it was
  // refused. The reason is returned rather than collapsed to a bool so the
  // probe can tell the user which of the plausible causes applies.
  std::string Open(const UsbHidDevice& device);

  // Build the libdc_io_callbacks_t struct pointing to this instance. The caller
  // must keep this object alive while the callbacks are in use: the userdata
  // pointer is not owned.
  libdc_io_callbacks_t MakeCallbacks();

  void Close();

 private:
  static int SetTimeoutCallback(void* userdata, int timeout);
  static int ReadCallback(void* userdata, void* data, size_t size,
                          size_t* actual);
  static int WriteCallback(void* userdata, const void* data, size_t size,
                           size_t* actual);
  static int CloseCallback(void* userdata);
  static int SleepCallback(void* userdata, unsigned int milliseconds);

  int PerformRead(void* data, size_t size, size_t* actual);
  int PerformWrite(const void* data, size_t size, size_t* actual);

  HANDLE handle_ = INVALID_HANDLE_VALUE;
  HANDLE read_event_ = nullptr;
  OVERLAPPED read_overlapped_ = {};
  // A read left in flight by a timeout. Reissuing instead would race the
  // device: a report delivered between the cancel and the next ReadFile would
  // be lost, and losing one report mid-transfer corrupts a download.
  bool read_pending_ = false;
  std::vector<unsigned char> read_buffer_;
  std::vector<unsigned char> write_buffer_;
  // Report lengths from HidP_GetCaps, both including the leading report id
  // byte that Windows requires on every transfer.
  size_t input_report_length_ = 0;
  size_t output_report_length_ = 0;
  int timeout_ms_ = 10000;
};

}  // namespace libdivecomputer_plugin

#endif  // USBHID_IO_STREAM_H_
