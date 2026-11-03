#ifndef NATIVE_LOGGER_H_
#define NATIVE_LOGGER_H_

#include <functional>
#include <mutex>
#include <string>

#include "dive_computer_api.g.h"

namespace libdivecomputer_plugin {

// Forwards native log lines into the Dart layer's debug log, the way
// Android's NativeLogger.kt and darwin's NativeLogger.swift already do.
//
// Windows had no such bridge: every failure inside the BLE transport was
// invisible, and a Windows bug report could carry nothing between "device
// discovered" and "Failed to connect to device" (issue #957, a Shearwater
// Petrel 2 that failed on both Windows 11 and Android; only the Android
// half of the report could be diagnosed from a log).
//
// Used on the connect and discovery paths and for one-off failures on the
// download thread (a rejected write, a failed characteristic read), never
// from the GATT notification handler: callers run on whichever thread they
// run on, and a per-packet log line during a logbook dump would queue a
// platform-thread task per packet on the transport's hot path.
class NativeLogger {
 public:
  // Runs a task on the platform thread, the only one Flutter takes pigeon
  // calls on (issue #4086).
  using Dispatcher = std::function<void(std::function<void()>)>;

  // Called by the plugin as it takes and releases ownership of the API.
  // Passing nullptr stops forwarding, which must happen before the API is
  // destroyed.
  static void SetFlutterApi(DiveComputerFlutterApi* api,
                            Dispatcher dispatcher = nullptr);

  static void Debug(const std::string& category, const std::string& message);
  static void Info(const std::string& category, const std::string& message);
  static void Warn(const std::string& category, const std::string& message);
  static void Error(const std::string& category, const std::string& message);

 private:
  static void Log(const std::string& category, const std::string& level,
                  const std::string& message);
  static void Send(const std::string& category, const std::string& level,
                   const std::string& message);

  static std::mutex mutex_;
  static DiveComputerFlutterApi* api_;
  static Dispatcher dispatcher_;
};

}  // namespace libdivecomputer_plugin

#endif  // NATIVE_LOGGER_H_
