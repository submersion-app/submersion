#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <utility>
#include <vector>

#include "win32_window.h"

// Finished posters handed back from worker threads to the platform thread.
//
// A flutter::MethodResult may only be completed on the platform thread, so a
// worker parks its result here and posts a message; the window drains this on
// the platform thread. Held via shared_ptr so an in-flight worker can outlive
// the window without dangling, and `alive` stops it posting to a dead HWND.
struct ThumbnailBridge {
  std::mutex mutex;
  std::vector<
      std::pair<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>,
                std::vector<uint8_t>>>
      completed;
  std::atomic<bool> alive{true};
  HWND hwnd = nullptr;
};

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Channel for local media operations (video poster thumbnails).
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      local_media_channel_;

  // Hand-off point for thumbnails generated on worker threads.
  std::shared_ptr<ThumbnailBridge> thumb_bridge_;

  // Custom system menu command ID for "Check for Updates..."
  static constexpr UINT kCheckForUpdatesCmd = 0x0010;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
