#ifndef BLUETOOTH_CLASSIC_IO_STREAM_H_
#define BLUETOOTH_CLASSIC_IO_STREAM_H_

#include <cstdint>
#include <string>

#include <libdivecomputer/context.h>
#include <libdivecomputer/iostream.h>

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

// A Bluetooth Classic RFCOMM link to a dive computer's Serial Port Profile
// service, for the dual-mode computers (the Shearwater Petrel 2) whose LE
// side Windows will not finish discovering (issue #4094).
//
// The socket is libdivecomputer's own Windows RFCOMM transport
// (dc_bluetooth_open with port 0, which lets Winsock find the SPP channel
// through SDP); this class only bridges it to libdc_io_callbacks_t so it can
// run through libdc_download_run like every other transport here. The
// download must be started with LIBDC_TRANSPORT_BLUETOOTH, since the
// Shearwater driver frames its packets differently over BLE.
class BluetoothClassicIoStream {
 public:
  BluetoothClassicIoStream();
  ~BluetoothClassicIoStream();

  BluetoothClassicIoStream(const BluetoothClassicIoStream&) = delete;
  BluetoothClassicIoStream& operator=(const BluetoothClassicIoStream&) =
      delete;

  // Connects to `address`. Returns an empty string on success, or the
  // reason it failed, including the Winsock error libdivecomputer logged.
  std::string Open(uint64_t address);

  // Build the libdc_io_callbacks_t struct pointing to this instance.
  libdc_io_callbacks_t MakeCallbacks();

  void Close();

  // Whether Windows holds a paired Bluetooth Classic record for `address`.
  // False when it has none, or when the lookup fails.
  static bool IsPaired(uint64_t address);

 private:
  static void LogCallback(dc_context_t* context, dc_loglevel_t loglevel,
                          const char* file, unsigned int line,
                          const char* function, const char* message,
                          void* userdata);

  static int SetTimeoutCallback(void* userdata, int timeout);
  static int ReadCallback(void* userdata, void* data, size_t size,
                          size_t* actual);
  static int WriteCallback(void* userdata, const void* data, size_t size,
                           size_t* actual);
  static int CloseCallback(void* userdata);
  static int PollCallback(void* userdata, int timeout);
  static int PurgeCallback(void* userdata, unsigned int direction);
  static int SleepCallback(void* userdata, unsigned int milliseconds);

  dc_context_t* context_ = nullptr;
  dc_iostream_t* iostream_ = nullptr;
  // The last error libdivecomputer logged while opening, which carries the
  // Winsock code that dc_bluetooth_open's status alone does not.
  std::string last_error_;
};

}  // namespace libdivecomputer_plugin

#endif  // BLUETOOTH_CLASSIC_IO_STREAM_H_
