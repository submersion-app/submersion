#include "native_logger.h"

namespace libdivecomputer_plugin {

std::mutex NativeLogger::mutex_;
DiveComputerFlutterApi* NativeLogger::api_ = nullptr;

void NativeLogger::SetFlutterApi(DiveComputerFlutterApi* api) {
    std::lock_guard<std::mutex> lock(mutex_);
    api_ = api;
}

void NativeLogger::Debug(const std::string& category,
                         const std::string& message) {
    Log(category, "DEBUG", message);
}

void NativeLogger::Info(const std::string& category,
                        const std::string& message) {
    Log(category, "INFO", message);
}

void NativeLogger::Warn(const std::string& category,
                        const std::string& message) {
    Log(category, "WARN", message);
}

void NativeLogger::Error(const std::string& category,
                         const std::string& message) {
    Log(category, "ERROR", message);
}

void NativeLogger::Log(const std::string& category, const std::string& level,
                       const std::string& message) {
    // Held across the send so the plugin cannot destroy the API underneath
    // an in-flight call: the BLE transport logs from a download thread that
    // outlives no shutdown of its own.
    std::lock_guard<std::mutex> lock(mutex_);
    if (api_ == nullptr) return;
    // A logging failure must never take the download with it. The no-op
    // reply callbacks only cover a Dart-side error reply; a throw from the
    // send itself (a bad_alloc from the string or EncodableValue copies)
    // would escape, and the BLE transport logs from a std::thread whose
    // entry function has no handler, where an escaping exception is
    // std::terminate. Android's NativeLogger.kt wraps the same call.
    try {
        api_->OnLogEvent(
            category, level, message, [] {}, [](const FlutterError&) {});
    } catch (...) {
    }
}

}  // namespace libdivecomputer_plugin
