#include "wpd_reader.h"

#include <PortableDevice.h>
#include <wrl/implements.h>

#include <algorithm>
#include <cstdio>
#include <cwctype>
#include <mutex>
#include <unordered_map>

using Microsoft::WRL::ComPtr;

namespace garmin_mtp {

namespace {

// Lower-case, for matching "VID_091E" in a PnP ID whatever its casing.
std::wstring Lower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  return value;
}

bool IsGarminPnpId(const std::wstring& pnp_id) {
  return Lower(pnp_id).find(L"vid_091e") != std::wstring::npos;
}

// A file larger than this is not a FIT activity; refuse rather than read
// a stray firmware image into memory.
constexpr size_t kMaxFileBytes = 64 * 1024 * 1024;

// Reads one of the manager's string properties for |pnp_id|, which report
// their length first. Empty when the device does not have it.
template <typename Getter>
std::wstring ManagerString(Getter getter) {
  DWORD length = 0;
  if (FAILED(getter(nullptr, &length)) || length == 0) return L"";
  std::wstring value(length, L'\0');
  if (FAILED(getter(value.data(), &length))) return L"";
  // The length counts the terminator.
  value.resize(wcsnlen(value.c_str(), value.size()));
  return value;
}

std::wstring TakeString(IPortableDeviceValues* values, REFPROPERTYKEY key) {
  LPWSTR raw = nullptr;
  if (FAILED(values->GetStringValue(key, &raw)) || raw == nullptr) return L"";
  std::wstring value(raw);
  CoTaskMemFree(raw);
  return value;
}

// The DATE (OLE automation time) a device reports, in epoch milliseconds.
std::optional<int64_t> DateToEpochMillis(IPortableDeviceValues* values,
                                         REFPROPERTYKEY key) {
  PROPVARIANT value;
  PropVariantInit(&value);
  std::optional<int64_t> result;
  if (SUCCEEDED(values->GetValue(key, &value)) && value.vt == VT_DATE) {
    SYSTEMTIME system_time;
    FILETIME file_time;
    if (VariantTimeToSystemTime(value.date, &system_time) &&
        SystemTimeToFileTime(&system_time, &file_time)) {
      ULARGE_INTEGER ticks;
      ticks.LowPart = file_time.dwLowDateTime;
      ticks.HighPart = file_time.dwHighDateTime;
      // 100 ns ticks since 1601 to milliseconds since 1970.
      constexpr ULONGLONG kEpochOffsetTicks = 116444736000000000ULL;
      if (ticks.QuadPart >= kEpochOffsetTicks) {
        result = static_cast<int64_t>((ticks.QuadPart - kEpochOffsetTicks) /
                                      10000ULL);
      }
    }
  }
  PropVariantClear(&value);
  return result;
}

struct WpdObject {
  std::wstring id;
  std::wstring name;
  GUID content_type = GUID_NULL;
  int64_t size = -1;
  std::optional<int64_t> modified_millis;
  bool has_properties = false;

  bool IsContainer() const {
    return content_type == WPD_CONTENT_TYPE_FOLDER ||
           content_type == WPD_CONTENT_TYPE_FUNCTIONAL_OBJECT;
  }
};

void FillObject(IPortableDeviceValues* values, WpdObject* object) {
  object->name = TakeString(values, WPD_OBJECT_ORIGINAL_FILE_NAME);
  if (object->name.empty()) object->name = TakeString(values, WPD_OBJECT_NAME);
  values->GetGuidValue(WPD_OBJECT_CONTENT_TYPE, &object->content_type);
  ULONGLONG size = 0;
  if (SUCCEEDED(values->GetUnsignedLargeIntegerValue(WPD_OBJECT_SIZE, &size))) {
    object->size = static_cast<int64_t>(size);
  }
  object->modified_millis = DateToEpochMillis(values, WPD_OBJECT_DATE_MODIFIED);
  object->has_properties = true;
}

// Collects the results of a bulk property request, which WPD delivers on
// its own thread, and signals when the request has finished.
class BulkValuesCallback
    : public Microsoft::WRL::RuntimeClass<
          Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>,
          IPortableDevicePropertiesBulkCallback> {
 public:
  BulkValuesCallback() : done_(CreateEventW(nullptr, TRUE, FALSE, nullptr)) {}
  ~BulkValuesCallback() override {
    if (done_ != nullptr) CloseHandle(done_);
  }

  IFACEMETHODIMP OnStart(REFGUID) override { return S_OK; }

  IFACEMETHODIMP OnProgress(REFGUID,
                            IPortableDeviceValuesCollection* results) override {
    DWORD count = 0;
    if (results == nullptr || FAILED(results->GetCount(&count))) return S_OK;
    std::lock_guard<std::mutex> lock(mutex_);
    for (DWORD i = 0; i < count; ++i) {
      ComPtr<IPortableDeviceValues> values;
      if (FAILED(results->GetAt(i, &values))) continue;
      std::wstring id = TakeString(values.Get(), WPD_OBJECT_ID);
      if (!id.empty()) values_[id] = values;
    }
    return S_OK;
  }

  IFACEMETHODIMP OnEnd(REFGUID, HRESULT status) override {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      status_ = status;
    }
    SetEvent(done_);
    return S_OK;
  }

  HANDLE done() const { return done_; }

  HRESULT status() {
    std::lock_guard<std::mutex> lock(mutex_);
    return status_;
  }

  std::unordered_map<std::wstring, ComPtr<IPortableDeviceValues>>
  TakeValues() {
    std::lock_guard<std::mutex> lock(mutex_);
    return std::move(values_);
  }

 private:
  HANDLE done_;
  std::mutex mutex_;
  HRESULT status_ = E_PENDING;
  std::unordered_map<std::wstring, ComPtr<IPortableDeviceValues>> values_;
};

// Long enough for a watch with years of activities over a slow link; past
// it the request is cancelled and the objects are read one by one.
constexpr DWORD kBulkTimeoutMs = 120000;

// Reads the properties of every object in |objects| in one bulk request,
// which a device answers far faster than one request per object. Objects
// it leaves out keep has_properties false. Fails when the device does not
// support bulk requests.
HRESULT GetValuesInBulk(IPortableDeviceProperties* properties,
                        IPortableDeviceKeyCollection* keys,
                        std::vector<WpdObject>* objects) {
  ComPtr<IPortableDevicePropertiesBulk> bulk;
  HRESULT hr = properties->QueryInterface(IID_PPV_ARGS(&bulk));
  if (FAILED(hr)) return hr;

  ComPtr<IPortableDevicePropVariantCollection> ids;
  hr = CoCreateInstance(CLSID_PortableDevicePropVariantCollection, nullptr,
                        CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&ids));
  if (FAILED(hr)) return hr;
  for (const auto& object : *objects) {
    const size_t bytes = (object.id.size() + 1) * sizeof(wchar_t);
    PROPVARIANT id;
    PropVariantInit(&id);
    id.vt = VT_LPWSTR;
    id.pwszVal = static_cast<LPWSTR>(CoTaskMemAlloc(bytes));
    if (id.pwszVal == nullptr) return E_OUTOFMEMORY;
    memcpy(id.pwszVal, object.id.c_str(), bytes);
    hr = ids->Add(&id);  // Adds a copy.
    PropVariantClear(&id);
    if (FAILED(hr)) return hr;
  }

  auto callback = Microsoft::WRL::Make<BulkValuesCallback>();
  if (!callback || callback->done() == nullptr) return E_OUTOFMEMORY;
  GUID context = GUID_NULL;
  hr = bulk->QueueGetValuesByObjectList(ids.Get(), keys, callback.Get(),
                                        &context);
  if (FAILED(hr)) return hr;
  hr = bulk->Start(context);
  if (FAILED(hr)) return hr;
  if (WaitForSingleObject(callback->done(), kBulkTimeoutMs) != WAIT_OBJECT_0) {
    bulk->Cancel(context);
    return HRESULT_FROM_WIN32(ERROR_TIMEOUT);
  }
  hr = callback->status();
  if (FAILED(hr)) return hr;

  const auto values = callback->TakeValues();
  for (auto& object : *objects) {
    const auto found = values.find(object.id);
    if (found != values.end()) FillObject(found->second.Get(), &object);
  }
  return S_OK;
}

// The children of |parent_id|, with the properties this reader needs.
HRESULT ListChildren(IPortableDeviceContent* content,
                     IPortableDeviceProperties* properties,
                     IPortableDeviceKeyCollection* keys,
                     const std::wstring& parent_id,
                     std::vector<WpdObject>* out) {
  ComPtr<IEnumPortableDeviceObjectIDs> object_ids;
  HRESULT hr =
      content->EnumObjects(0, parent_id.c_str(), nullptr, &object_ids);
  if (FAILED(hr)) return hr;

  std::vector<WpdObject> children;
  constexpr ULONG kBatch = 32;
  for (;;) {
    LPWSTR ids[kBatch] = {};
    ULONG fetched = 0;
    hr = object_ids->Next(kBatch, ids, &fetched);
    if (FAILED(hr)) return hr;
    for (ULONG i = 0; i < fetched; ++i) {
      WpdObject object;
      object.id = ids[i];
      CoTaskMemFree(ids[i]);
      children.push_back(std::move(object));
    }
    // S_FALSE, or a short batch, means the enumeration is done.
    if (hr == S_FALSE || fetched < kBatch) break;
  }

  // One request for the lot where the device allows it; anything it did
  // not answer is read on its own, as before.
  if (children.size() > 1) {
    GetValuesInBulk(properties, keys, &children);
  }
  for (auto& object : children) {
    if (object.has_properties) continue;
    ComPtr<IPortableDeviceValues> values;
    if (SUCCEEDED(properties->GetValues(object.id.c_str(), keys, &values))) {
      FillObject(values.Get(), &object);
    }
  }
  out->insert(out->end(), std::make_move_iterator(children.begin()),
              std::make_move_iterator(children.end()));
  return S_OK;
}

const WpdObject* FindContainer(const std::vector<WpdObject>& objects,
                               const wchar_t* name) {
  for (const auto& object : objects) {
    if (object.IsContainer() && _wcsicmp(object.name.c_str(), name) == 0) {
      return &object;
    }
  }
  return nullptr;
}

HRESULT CreateKeys(ComPtr<IPortableDeviceKeyCollection>* keys) {
  HRESULT hr = CoCreateInstance(CLSID_PortableDeviceKeyCollection, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&*keys));
  if (FAILED(hr)) return hr;
  // Bulk results are matched back to their objects by ID.
  (*keys)->Add(WPD_OBJECT_ID);
  (*keys)->Add(WPD_OBJECT_ORIGINAL_FILE_NAME);
  (*keys)->Add(WPD_OBJECT_NAME);
  (*keys)->Add(WPD_OBJECT_CONTENT_TYPE);
  (*keys)->Add(WPD_OBJECT_SIZE);
  (*keys)->Add(WPD_OBJECT_DATE_MODIFIED);
  return S_OK;
}

}  // namespace

WpdError WpdErrorFromHresult(const char* step, HRESULT hr) {
  std::string code = "ioError";
  switch (hr) {
    case HRESULT_FROM_WIN32(ERROR_NOT_FOUND):
    case HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND):
    case HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND):
    case HRESULT_FROM_WIN32(ERROR_DEVICE_NOT_CONNECTED):
    case HRESULT_FROM_WIN32(ERROR_DEV_NOT_EXIST):
    case HRESULT_FROM_WIN32(ERROR_INVALID_DRIVE):
      code = "notFound";
      break;
    case E_ACCESSDENIED:
    case HRESULT_FROM_WIN32(ERROR_BUSY):
    case HRESULT_FROM_WIN32(ERROR_SHARING_VIOLATION):
    case HRESULT_FROM_WIN32(ERROR_LOCK_VIOLATION):
      code = "busy";
      break;
    default:
      break;
  }

  char* system_text = nullptr;
  FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
                     FORMAT_MESSAGE_IGNORE_INSERTS,
                 nullptr, static_cast<DWORD>(hr), 0,
                 reinterpret_cast<LPSTR>(&system_text), 0, nullptr);
  std::string text = system_text ? system_text : "";
  if (system_text) LocalFree(system_text);
  while (!text.empty() && (text.back() == '\n' || text.back() == '\r' ||
                           text.back() == ' ' || text.back() == '.')) {
    text.pop_back();
  }

  char hex[16];
  std::snprintf(hex, sizeof(hex), "0x%08lX", static_cast<unsigned long>(hr));
  std::string message = std::string(step) + " failed";
  if (!text.empty()) message += ": " + text;
  message += " (" + std::string(hex) + ")";
  return WpdError{code, message};
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) return "";
  int length = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                   static_cast<int>(value.size()), nullptr, 0,
                                   nullptr, nullptr);
  std::string result(length, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      result.data(), length, nullptr, nullptr);
  return result;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) return L"";
  int length = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                   static_cast<int>(value.size()), nullptr, 0);
  std::wstring result(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      result.data(), length);
  return result;
}

WpdReader::~WpdReader() { Close(); }

void WpdReader::Close() {
  if (device_) device_->Close();
  device_.Reset();
  device_id_.clear();
}

std::optional<WpdError> WpdReader::Open(const std::wstring& device_id) {
  if (device_ && device_id_ == device_id) return std::nullopt;
  Close();

  ComPtr<IPortableDeviceValues> client_info;
  HRESULT hr = CoCreateInstance(CLSID_PortableDeviceValues, nullptr,
                                CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&client_info));
  if (FAILED(hr)) return WpdErrorFromHresult("Creating client info", hr);
  client_info->SetStringValue(WPD_CLIENT_NAME, L"Submersion");
  client_info->SetUnsignedIntegerValue(WPD_CLIENT_MAJOR_VERSION, 1);
  client_info->SetUnsignedIntegerValue(WPD_CLIENT_MINOR_VERSION, 0);
  client_info->SetUnsignedIntegerValue(WPD_CLIENT_REVISION, 0);
  client_info->SetUnsignedIntegerValue(WPD_CLIENT_SECURITY_QUALITY_OF_SERVICE,
                                       SECURITY_IMPERSONATION);
  // Read-only, so it can share the watch with another reader.
  client_info->SetUnsignedIntegerValue(WPD_CLIENT_DESIRED_ACCESS, GENERIC_READ);

  ComPtr<IPortableDevice> device;
  hr = CoCreateInstance(CLSID_PortableDeviceFTM, nullptr, CLSCTX_INPROC_SERVER,
                        IID_PPV_ARGS(&device));
  if (FAILED(hr)) return WpdErrorFromHresult("Creating the device", hr);
  hr = device->Open(device_id.c_str(), client_info.Get());
  if (FAILED(hr)) return WpdErrorFromHresult("Opening the device", hr);

  device_ = device;
  device_id_ = device_id;
  return std::nullopt;
}

std::optional<WpdError> WpdReader::ListGarminDevices(
    std::vector<WpdDeviceInfo>* out) {
  out->clear();
  // A device left open by an earlier call may have been unplugged since,
  // and plugging it back in keeps its ID: Open() would hand back the dead
  // handle, the serial below would come up empty, and the next listing
  // would fail. Every download starts with this call, so start it clean.
  Close();
  ComPtr<IPortableDeviceManager> manager;
  HRESULT hr = CoCreateInstance(CLSID_PortableDeviceManager, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&manager));
  if (FAILED(hr)) return WpdErrorFromHresult("Creating the device manager", hr);
  // Picks up a watch plugged in since the manager last looked.
  manager->RefreshDeviceList();

  DWORD count = 0;
  hr = manager->GetDevices(nullptr, &count);
  if (FAILED(hr)) return WpdErrorFromHresult("Counting devices", hr);
  if (count == 0) return std::nullopt;

  std::vector<LPWSTR> ids(count, nullptr);
  hr = manager->GetDevices(ids.data(), &count);
  if (FAILED(hr)) return WpdErrorFromHresult("Listing devices", hr);

  for (DWORD i = 0; i < count; ++i) {
    if (ids[i] == nullptr) continue;
    std::wstring id(ids[i]);
    CoTaskMemFree(ids[i]);
    if (!IsGarminPnpId(id)) continue;

    WpdDeviceInfo info;
    info.id = id;
    info.friendly_name = ManagerString([&](WCHAR* buffer, DWORD* length) {
      return manager->GetDeviceFriendlyName(id.c_str(), buffer, length);
    });
    info.manufacturer = ManagerString([&](WCHAR* buffer, DWORD* length) {
      return manager->GetDeviceManufacturer(id.c_str(), buffer, length);
    });
    info.description = ManagerString([&](WCHAR* buffer, DWORD* length) {
      return manager->GetDeviceDescription(id.c_str(), buffer, length);
    });

    // The serial is only on the device object. A watch another app holds
    // still lists, without one.
    if (!Open(id).has_value()) {
      ComPtr<IPortableDeviceContent> content;
      ComPtr<IPortableDeviceProperties> properties;
      ComPtr<IPortableDeviceKeyCollection> keys;
      ComPtr<IPortableDeviceValues> values;
      if (SUCCEEDED(device_->Content(&content)) &&
          SUCCEEDED(content->Properties(&properties)) &&
          SUCCEEDED(CoCreateInstance(CLSID_PortableDeviceKeyCollection,
                                     nullptr, CLSCTX_INPROC_SERVER,
                                     IID_PPV_ARGS(&keys))) &&
          SUCCEEDED(keys->Add(WPD_DEVICE_SERIAL_NUMBER)) &&
          SUCCEEDED(properties->GetValues(WPD_DEVICE_OBJECT_ID, keys.Get(),
                                          &values))) {
        info.serial_number = TakeString(values.Get(), WPD_DEVICE_SERIAL_NUMBER);
      }
    }
    out->push_back(std::move(info));
  }
  return std::nullopt;
}

std::optional<WpdError> WpdReader::ListActivityFiles(
    const std::wstring& device_id, std::vector<WpdFileInfo>* out) {
  out->clear();
  if (auto error = Open(device_id)) return error;

  ComPtr<IPortableDeviceContent> content;
  ComPtr<IPortableDeviceProperties> properties;
  ComPtr<IPortableDeviceKeyCollection> keys;
  HRESULT hr = device_->Content(&content);
  if (SUCCEEDED(hr)) hr = content->Properties(&properties);
  if (SUCCEEDED(hr)) hr = CreateKeys(&keys);
  if (FAILED(hr)) {
    Close();
    return WpdErrorFromHresult("Reading the device contents", hr);
  }

  // DEVICE holds the storages; GARMIN sits on a storage, or on some
  // devices directly under DEVICE.
  std::vector<WpdObject> top;
  hr = ListChildren(content.Get(), properties.Get(), keys.Get(),
                    WPD_DEVICE_OBJECT_ID, &top);
  if (FAILED(hr)) {
    Close();
    return WpdErrorFromHresult("Listing the device's storage", hr);
  }

  std::vector<std::wstring> garmin_folders;
  if (const WpdObject* garmin = FindContainer(top, L"GARMIN")) {
    garmin_folders.push_back(garmin->id);
  }
  for (const auto& storage : top) {
    if (!storage.IsContainer()) continue;
    std::vector<WpdObject> children;
    if (FAILED(ListChildren(content.Get(), properties.Get(), keys.Get(),
                            storage.id, &children))) {
      continue;
    }
    if (const WpdObject* garmin = FindContainer(children, L"GARMIN")) {
      garmin_folders.push_back(garmin->id);
    }
  }

  for (const auto& garmin_id : garmin_folders) {
    std::vector<WpdObject> garmin_children;
    if (FAILED(ListChildren(content.Get(), properties.Get(), keys.Get(),
                            garmin_id, &garmin_children))) {
      continue;
    }
    const WpdObject* activity = FindContainer(garmin_children, L"Activity");
    if (activity == nullptr) continue;

    std::vector<WpdObject> files;
    hr = ListChildren(content.Get(), properties.Get(), keys.Get(),
                      activity->id, &files);
    if (FAILED(hr)) {
      Close();
      return WpdErrorFromHresult("Listing GARMIN/Activity", hr);
    }
    for (const auto& file : files) {
      if (file.IsContainer()) continue;
      out->push_back(
          WpdFileInfo{file.id, file.name, file.size, file.modified_millis});
    }
  }
  return std::nullopt;
}

std::optional<WpdError> WpdReader::ReadFile(const std::wstring& device_id,
                                            const std::wstring& object_id,
                                            std::vector<uint8_t>* out) {
  out->clear();
  if (auto error = Open(device_id)) return error;

  ComPtr<IPortableDeviceContent> content;
  ComPtr<IPortableDeviceResources> resources;
  ComPtr<IStream> stream;
  DWORD optimal_buffer = 0;
  HRESULT hr = device_->Content(&content);
  if (SUCCEEDED(hr)) hr = content->Transfer(&resources);
  if (SUCCEEDED(hr)) {
    hr = resources->GetStream(object_id.c_str(), WPD_RESOURCE_DEFAULT,
                              STGM_READ, &optimal_buffer, &stream);
  }
  if (FAILED(hr)) {
    // A watch unplugged since the last call fails here; reopen next time.
    Close();
    return WpdErrorFromHresult("Opening the file", hr);
  }

  std::vector<uint8_t> buffer(optimal_buffer > 0 ? optimal_buffer : 65536);
  for (;;) {
    ULONG read = 0;
    hr = stream->Read(buffer.data(), static_cast<ULONG>(buffer.size()), &read);
    if (FAILED(hr)) {
      out->clear();
      Close();
      return WpdErrorFromHresult("Reading the file", hr);
    }
    if (read == 0) break;
    if (out->size() + read > kMaxFileBytes) {
      out->clear();
      return WpdError{"ioError", "The file is too large to be an activity"};
    }
    out->insert(out->end(), buffer.begin(), buffer.begin() + read);
    if (hr == S_FALSE) break;
  }
  return std::nullopt;
}

}  // namespace garmin_mtp
