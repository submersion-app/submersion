#ifndef WPD_READER_H_
#define WPD_READER_H_

// A read-only Windows Portable Devices (WPD) client: just enough MTP to list
// a Garmin watch's GARMIN/Activity folder and read its files (issue #4223).
//
// Not thread-safe. Every call must come from one thread that has called
// CoInitializeEx(COINIT_MULTITHREADED), and the reader must be destroyed on
// that thread before it calls CoUninitialize: it caches the opened device.

#include <windows.h>
#include <wrl/client.h>

#include <PortableDeviceApi.h>

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace garmin_mtp {

struct WpdDeviceInfo {
  std::wstring id;
  std::wstring friendly_name;
  std::wstring manufacturer;
  std::wstring description;
  std::wstring serial_number;
};

struct WpdFileInfo {
  std::wstring object_id;
  std::wstring name;
  int64_t size = -1;
  std::optional<int64_t> modified_millis;
};

// A failed call: a stable code for Dart (notFound, busy, ioError) and a
// message naming the step and the HRESULT.
struct WpdError {
  std::string code;
  std::string message;
};

class WpdReader {
 public:
  WpdReader() = default;
  ~WpdReader();
  WpdReader(const WpdReader&) = delete;
  WpdReader& operator=(const WpdReader&) = delete;

  // Portable devices whose PnP ID names USB vendor 0x091E (Garmin).
  std::optional<WpdError> ListGarminDevices(std::vector<WpdDeviceInfo>* out);

  // Files directly under GARMIN/Activity, searched on every storage. Leaves
  // |out| empty when the device has no such folder.
  std::optional<WpdError> ListActivityFiles(const std::wstring& device_id,
                                            std::vector<WpdFileInfo>* out);

  std::optional<WpdError> ReadFile(const std::wstring& device_id,
                                   const std::wstring& object_id,
                                   std::vector<uint8_t>* out);

 private:
  // Opens |device_id|, or reuses the device already open for it.
  std::optional<WpdError> Open(const std::wstring& device_id);
  void Close();

  Microsoft::WRL::ComPtr<IPortableDevice> device_;
  std::wstring device_id_;
};

// Exposed for the message: "<step> failed: <system text> (0x80070005)".
WpdError WpdErrorFromHresult(const char* step, HRESULT hr);

std::string WideToUtf8(const std::wstring& value);
std::wstring Utf8ToWide(const std::string& value);

}  // namespace garmin_mtp

#endif  // WPD_READER_H_
