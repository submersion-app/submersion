#ifndef FLUTTER_PLUGIN_SUBMERSION_VISION_PLUGIN_H_
#define FLUTTER_PLUGIN_SUBMERSION_VISION_PLUGIN_H_

#define NOMINMAX
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <condition_variable>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <thread>

#include "frame_reader.h"

namespace submersion_vision {

// The `submersion_vision/frames` channel on Windows: video frames for the
// ONNX engine's video passes (piece 3 of marine life identification). Every
// call runs in order on one worker thread, which owns Media Foundation and
// the opened videos.
class SubmersionVisionPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  SubmersionVisionPlugin();
  virtual ~SubmersionVisionPlugin();

  SubmersionVisionPlugin(const SubmersionVisionPlugin&) = delete;
  SubmersionVisionPlugin& operator=(const SubmersionVisionPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  void Post(std::function<void()> task);
  void Run();

  std::mutex mutex_;
  std::condition_variable wake_;
  std::deque<std::function<void()>> tasks_;
  bool stopping_ = false;

  // Worker thread only.
  std::map<int64_t, VideoFrames> videos_;
  int64_t next_handle_ = 1;

  // Last, so it starts only once everything it uses exists.
  std::thread worker_;
};

}  // namespace submersion_vision

#endif  // FLUTTER_PLUGIN_SUBMERSION_VISION_PLUGIN_H_
