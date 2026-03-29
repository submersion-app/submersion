#include "WinSparkle-0.8.1/include/winsparkle.h"

#include <windows.h>

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <queue>
#include <sstream>
#include <stdexcept>
#include <string>

namespace {

// Custom Windows message used to signal the platform thread that events are
// waiting in the queue. WM_APP is the start of the application-private range.
constexpr UINT WM_APP_SPARKLE_EVENT = WM_APP + 1;

// Forward declarations for WinSparkle callbacks
void __onErrorCallback();
void __onShutdownRequestCallback();
void __onDidFindUpdateCallback();
void __onDidNotFindUpdateCallback();
void __onUpdateCancelledCallback();

class AutoUpdater {
 public:
  static AutoUpdater* GetInstance();

  AutoUpdater();

  virtual ~AutoUpdater();

  void SetFeedURL(std::string feedURL);
  void CheckForUpdates();
  void CheckForUpdatesWithoutUI();
  void SetScheduledCheckInterval(int interval);

  void RegisterEventSink(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> ptr);

  void UnregisterEventSink();

  // Enqueues an event and signals the platform thread via PostMessage.
  // Safe to call from any thread (WinSparkle background threads or the
  // platform thread itself).
  void OnWinSparkleEvent(std::string eventName);

  // Called from the platform thread (window proc delegate) to drain the queue
  // and deliver events through the EventSink.
  void DrainEvents();

  // Store the HWND used for PostMessage signaling.
  void SetWindowHandle(HWND hwnd);

 private:
  static AutoUpdater* lazySingleton;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  // Thread-safe event queue. WinSparkle callbacks push event names here;
  // the platform thread drains them in DrainEvents().
  std::mutex event_mutex_;
  std::queue<std::string> event_queue_;
  std::atomic<HWND> hwnd_{nullptr};
};

AutoUpdater* AutoUpdater::lazySingleton = nullptr;

AutoUpdater* AutoUpdater::GetInstance() {
  return lazySingleton;
}

AutoUpdater::AutoUpdater() {
  if (lazySingleton != nullptr) {
    throw std::invalid_argument("AutoUpdater has already been initialized");
  }

  lazySingleton = this;
}

AutoUpdater::~AutoUpdater() {
  win_sparkle_cleanup();
  lazySingleton = nullptr;
}

void AutoUpdater::SetWindowHandle(HWND hwnd) {
  hwnd_ = hwnd;
}

void AutoUpdater::SetFeedURL(std::string feedURL) {
  win_sparkle_set_appcast_url(feedURL.c_str());
  win_sparkle_set_error_callback(__onErrorCallback);
  win_sparkle_set_shutdown_request_callback(__onShutdownRequestCallback);
  win_sparkle_set_did_find_update_callback(__onDidFindUpdateCallback);
  win_sparkle_set_did_not_find_update_callback(__onDidNotFindUpdateCallback);
  win_sparkle_set_update_cancelled_callback(__onUpdateCancelledCallback);
  win_sparkle_init();
}

void AutoUpdater::CheckForUpdates() {
  win_sparkle_check_update_with_ui();
  OnWinSparkleEvent("checking-for-update");
}

void AutoUpdater::CheckForUpdatesWithoutUI() {
  win_sparkle_check_update_without_ui();
  OnWinSparkleEvent("checking-for-update");
}

void AutoUpdater::SetScheduledCheckInterval(int interval) {
  win_sparkle_set_update_check_interval(interval);
}

void AutoUpdater::RegisterEventSink(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> ptr) {
  event_sink_ = std::move(ptr);
}

void AutoUpdater::UnregisterEventSink() {
  event_sink_ = nullptr;
}

void AutoUpdater::OnWinSparkleEvent(std::string eventName) {
  {
    std::lock_guard<std::mutex> lock(event_mutex_);
    event_queue_.push(std::move(eventName));
  }

  // Signal the platform thread. PostMessage is safe to call from any thread.
  HWND hwnd = hwnd_.load();
  if (hwnd != nullptr) {
    PostMessage(hwnd, WM_APP_SPARKLE_EVENT, 0, 0);
  }
}

void AutoUpdater::DrainEvents() {
  // Swap the queue under the lock to minimize time spent holding the mutex.
  std::queue<std::string> local_queue;
  {
    std::lock_guard<std::mutex> lock(event_mutex_);
    std::swap(local_queue, event_queue_);
  }

  // Now deliver events outside the lock, on the platform thread.
  while (!local_queue.empty()) {
    std::string eventName = std::move(local_queue.front());
    local_queue.pop();

    if (event_sink_ == nullptr)
      continue;

    flutter::EncodableMap args = flutter::EncodableMap();
    args[flutter::EncodableValue("type")] = eventName;
    event_sink_->Success(flutter::EncodableValue(args));
  }
}

void __onErrorCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("error");
}

void __onShutdownRequestCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("before-quit-for-update");
}

void __onDidFindUpdateCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("update-available");
}

void __onDidNotFindUpdateCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("update-not-available");
}

void __onUpdateCancelledCallback() {
  AutoUpdater* autoUpdater = AutoUpdater::GetInstance();
  if (autoUpdater == nullptr)
    return;
  autoUpdater->OnWinSparkleEvent("updateCancelled");
}
}  // namespace
