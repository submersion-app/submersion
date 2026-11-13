#include "garmin_mtp_host_api_impl.h"

#include <objbase.h>

#include <chrono>
#include <memory>
#include <utility>

#include "native_logger.h"
#include "wpd_reader.h"

namespace garmin_mtp {

namespace {

using libdivecomputer_plugin::NativeLogger;

constexpr char kLogCategory[] = "APP";

FlutterError ToFlutterError(const WpdError& error) {
  return FlutterError(error.code, error.message);
}


}  // namespace

GarminMtpHostApiImpl::GarminMtpHostApiImpl(PostTask post_to_platform_thread)
    : post_(std::move(post_to_platform_thread)) {
  worker_ = std::thread([this] { WorkerLoop(); });
}

GarminMtpHostApiImpl::~GarminMtpHostApiImpl() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    stopping_ = true;
    jobs_.clear();
  }
  wake_.notify_all();
  if (worker_.joinable()) worker_.join();
}

void GarminMtpHostApiImpl::Enqueue(Job job) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (stopping_) return;
    jobs_.push_back(std::move(job));
  }
  wake_.notify_one();
}

void GarminMtpHostApiImpl::WorkerLoop() {
  // WPD wants a multithreaded apartment; the platform thread is the
  // runner's single-threaded one, which is another reason not to call WPD
  // from there.
  const HRESULT com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  {
    // Scoped so the reader, and the device it caches, is released before
    // CoUninitialize.
    WpdReader reader;
    for (;;) {
      Job job;
      {
        std::unique_lock<std::mutex> lock(mutex_);
        wake_.wait(lock, [this] { return stopping_ || !jobs_.empty(); });
        if (stopping_) break;
        job = std::move(jobs_.front());
        jobs_.pop_front();
      }
      job(reader);
    }
  }
  if (SUCCEEDED(com)) CoUninitialize();
}

void GarminMtpHostApiImpl::ListDevices(
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  Enqueue([this, result = std::move(result)](WpdReader& reader) {
    std::vector<WpdDeviceInfo> devices;
    auto error = reader.ListGarminDevices(&devices);
    if (error) {
      NativeLogger::Warn(kLogCategory,
                         "Garmin MTP: listing devices: " + error->message);
      post_([result, error = *error] { result(ToFlutterError(error)); });
      return;
    }

    flutter::EncodableList list;
    std::string described;
    for (const auto& device : devices) {
      const std::string manufacturer = WideToUtf8(device.manufacturer);
      const std::string model = WideToUtf8(device.description);
      const std::string serial = WideToUtf8(device.serial_number);
      const std::string name = WideToUtf8(device.friendly_name.empty()
                                              ? device.description
                                              : device.friendly_name);
      // Name and serial in the log, to compare with the serial number the
      // watch's FIT files carry (shown on its computer page).
      described += (described.empty() ? ": " : ", ") + name + " (serial " +
                   (serial.empty() ? std::string("unknown") : serial) + ")";
      GarminMtpDevice value(WideToUtf8(device.id), name);
      if (!manufacturer.empty()) value.set_manufacturer(manufacturer);
      if (!model.empty()) value.set_model(model);
      if (!serial.empty()) value.set_serial_number(serial);
      list.push_back(flutter::CustomEncodableValue(std::move(value)));
    }
    NativeLogger::Info(kLogCategory, "Garmin MTP: " +
                                         std::to_string(list.size()) +
                                         " device(s) found" + described);
    post_([result, list = std::move(list)] { result(list); });
  });
}

void GarminMtpHostApiImpl::ListActivityFiles(
    const std::string& device_id,
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  Enqueue([this, id = Utf8ToWide(device_id),
           result = std::move(result)](WpdReader& reader) {
    std::vector<WpdFileInfo> files;
    const auto started = std::chrono::steady_clock::now();
    auto error = reader.ListActivityFiles(id, &files);
    const auto elapsed_ms =
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - started)
            .count();
    if (error) {
      NativeLogger::Warn(kLogCategory,
                         "Garmin MTP: listing activities: " + error->message);
      post_([result, error = *error] { result(ToFlutterError(error)); });
      return;
    }

    flutter::EncodableList list;
    for (const auto& file : files) {
      GarminMtpFile value(WideToUtf8(file.object_id), WideToUtf8(file.name),
                          file.size);
      if (file.modified_millis) value.set_modified_millis(*file.modified_millis);
      list.push_back(flutter::CustomEncodableValue(std::move(value)));
    }
    NativeLogger::Info(kLogCategory, "Garmin MTP: " +
                                         std::to_string(list.size()) +
                                         " activity file(s) listed in " +
                                         std::to_string(elapsed_ms) + " ms");
    post_([result, list = std::move(list)] { result(list); });
  });
}

void GarminMtpHostApiImpl::ReadFile(
    const std::string& device_id,
    const std::string& object_id,
    std::function<void(ErrorOr<std::vector<uint8_t>> reply)> result) {
  Enqueue([this, id = Utf8ToWide(device_id), object = Utf8ToWide(object_id),
           result = std::move(result)](WpdReader& reader) {
    // Shared, so the bytes are not copied again into the posted task.
    auto bytes = std::make_shared<std::vector<uint8_t>>();
    auto error = reader.ReadFile(id, object, bytes.get());
    if (error) {
      NativeLogger::Warn(kLogCategory,
                         "Garmin MTP: reading a file: " + error->message);
      post_([result, error = *error] { result(ToFlutterError(error)); });
      return;
    }
    post_([result, bytes] { result(std::move(*bytes)); });
  });
}

}  // namespace garmin_mtp
