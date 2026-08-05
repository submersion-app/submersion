#ifndef FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PLUGIN_H_
#define FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PLUGIN_H_

#define NOMINMAX
#include <windows.h>

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

#include "progress_dispatcher.h"

namespace submersion_transcoder {

class SubmersionTranscoderPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit SubmersionTranscoderPlugin(
      flutter::PluginRegistrarWindows* registrar);
  virtual ~SubmersionTranscoderPlugin();

  SubmersionTranscoderPlugin(const SubmersionTranscoderPlugin&) = delete;
  SubmersionTranscoderPlugin& operator=(const SubmersionTranscoderPlugin&) =
      delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Marshals worker-thread progress onto the platform thread. Shared with the
  // detached transcode worker so it outlives the plugin if a transcode is still
  // running at teardown.
  std::shared_ptr<ProgressDispatcher> dispatcher_ =
      std::make_shared<ProgressDispatcher>();

 private:
  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  int window_proc_delegate_id_ = 0;
};

}  // namespace submersion_transcoder

#endif  // FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PLUGIN_H_
