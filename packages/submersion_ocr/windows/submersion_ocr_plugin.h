#ifndef FLUTTER_PLUGIN_SUBMERSION_OCR_PLUGIN_H_
#define FLUTTER_PLUGIN_SUBMERSION_OCR_PLUGIN_H_

#define NOMINMAX
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace submersion_ocr {

class SubmersionOcrPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  SubmersionOcrPlugin();

  virtual ~SubmersionOcrPlugin();

  // Disallow copy and assign.
  SubmersionOcrPlugin(const SubmersionOcrPlugin&) = delete;
  SubmersionOcrPlugin& operator=(const SubmersionOcrPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace submersion_ocr

#endif  // FLUTTER_PLUGIN_SUBMERSION_OCR_PLUGIN_H_
