#ifndef FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PROGRESS_DISPATCHER_H_
#define FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PROGRESS_DISPATCHER_H_

#define NOMINMAX
#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/event_sink.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <queue>
#include <utility>

namespace submersion_transcoder {

// Custom window message used to wake the platform thread. WM_APP + 2 is picked
// to avoid colliding with auto_updater_windows (which uses WM_APP + 1) on the
// shared top-level window proc chain; each plugin filters by its own value.
constexpr UINT WM_APP_TRANSCODE_PROGRESS = WM_APP + 2;

// Marshals transcode progress events from the WinRT worker thread onto the
// Flutter platform thread. flutter::EventSink::Success must only be called on
// the platform thread, so Emit() (worker thread) merely enqueues the event and
// signals the platform window via PostMessage; Drain() (platform thread, from
// the plugin's window proc delegate) delivers the queued events through the
// sink. This mirrors the auto_updater_windows plugin's approach.
//
// Held by shared_ptr and captured by the detached worker thread, so the
// dispatcher outlives the plugin if a transcode is still running at teardown.
class ProgressDispatcher {
 public:
  // Platform thread: called when Dart subscribes to / cancels the stream.
  void SetSink(
      std::shared_ptr<flutter::EventSink<flutter::EncodableValue>> sink) {
    std::lock_guard<std::mutex> lock(mutex_);
    sink_ = std::move(sink);
  }

  // Platform thread: the HWND that PostMessage should target. Null in headless
  // runs (no view), in which case Emit() silently drops progress.
  void SetWindow(HWND hwnd) { hwnd_.store(hwnd); }

  // Worker thread: enqueue an event and wake the platform thread. With no
  // window (headless run) nothing would ever drain the queue, so drop the event
  // rather than let it accumulate unbounded.
  void Emit(flutter::EncodableValue event) {
    HWND hwnd = hwnd_.load();
    if (hwnd == nullptr) return;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      queue_.push(std::move(event));
    }
    PostMessage(hwnd, WM_APP_TRANSCODE_PROGRESS, 0, 0);
  }

  // Platform thread: deliver all queued events through the sink.
  void Drain() {
    std::queue<flutter::EncodableValue> local;
    std::shared_ptr<flutter::EventSink<flutter::EncodableValue>> sink;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      std::swap(local, queue_);
      sink = sink_;
    }
    if (!sink) return;
    while (!local.empty()) {
      sink->Success(local.front());
      local.pop();
    }
  }

 private:
  std::mutex mutex_;
  std::queue<flutter::EncodableValue> queue_;
  std::shared_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  std::atomic<HWND> hwnd_{nullptr};
};

}  // namespace submersion_transcoder

#endif  // FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PROGRESS_DISPATCHER_H_
