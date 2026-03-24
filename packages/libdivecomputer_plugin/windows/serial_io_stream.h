#ifndef SERIAL_IO_STREAM_H_
#define SERIAL_IO_STREAM_H_

#include <Windows.h>

#include <cstdint>
#include <string>

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

// Provides synchronous serial I/O for libdivecomputer using Win32 APIs.
// Opens a COM port with 8N1 configuration and implements libdc_io_callbacks_t.
class SerialIoStream {
 public:
  SerialIoStream();
  ~SerialIoStream();

  // Open the specified COM port (e.g., "COM3").
  // Configures 9600 baud, 8N1, and sets initial timeouts.
  bool Open(const std::string& port_name);

  // Build the libdc_io_callbacks_t struct pointing to this instance.
  libdc_io_callbacks_t MakeCallbacks();

  void Close();

 private:
  static int SetTimeoutCallback(void* userdata, int timeout);
  static int ReadCallback(void* userdata, void* data, size_t size,
                          size_t* actual);
  static int WriteCallback(void* userdata, const void* data, size_t size,
                           size_t* actual);
  static int CloseCallback(void* userdata);
  static int ConfigureCallback(void* userdata, unsigned int baudrate,
                               unsigned int databits, unsigned int parity,
                               unsigned int stopbits, unsigned int flowcontrol);
  static int SetDtrCallback(void* userdata, unsigned int value);
  static int SetRtsCallback(void* userdata, unsigned int value);

  int PerformRead(void* data, size_t size, size_t* actual);
  int PerformWrite(const void* data, size_t size, size_t* actual);

  HANDLE handle_ = INVALID_HANDLE_VALUE;
  int timeout_ms_ = 5000;
};

}  // namespace libdivecomputer_plugin

#endif  // SERIAL_IO_STREAM_H_
