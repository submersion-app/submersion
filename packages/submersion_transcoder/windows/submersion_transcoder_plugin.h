#ifndef FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PLUGIN_H_
#define FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PLUGIN_H_

#define NOMINMAX
#include <windows.h>

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <mutex>
#include <string>

namespace submersion_transcoder {

class SubmersionTranscoderPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  SubmersionTranscoderPlugin();
  virtual ~SubmersionTranscoderPlugin();

  SubmersionTranscoderPlugin(const SubmersionTranscoderPlugin&) = delete;
  SubmersionTranscoderPlugin& operator=(const SubmersionTranscoderPlugin&) =
      delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Progress sink shared with worker threads; guarded by progress_mutex_.
  std::shared_ptr<flutter::EventSink<flutter::EncodableValue>> progress_sink_;
  std::mutex progress_mutex_;
};

}  // namespace submersion_transcoder

#endif  // FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PLUGIN_H_
