#include "submersion_transcoder_plugin.h"

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.MediaProperties.h>
#include <winrt/Windows.Media.Transcoding.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.FileProperties.h>
#include <winrt/Windows.Storage.Search.h>

#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <chrono>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <utility>

namespace submersion_transcoder {

namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;

std::string Utf8(const std::wstring& w) {
  if (w.empty()) return {};
  int len = WideCharToMultiByte(CP_UTF8, 0, w.c_str(),
                                static_cast<int>(w.size()), nullptr, 0, nullptr,
                                nullptr);
  std::string out(len, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w.c_str(), static_cast<int>(w.size()),
                      out.data(), len, nullptr, nullptr);
  return out;
}

std::wstring Wide(const std::string& s) {
  if (s.empty()) return {};
  int len = MultiByteToWideChar(CP_UTF8, 0, s.c_str(),
                                static_cast<int>(s.size()), nullptr, 0);
  std::wstring out(len, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()),
                      out.data(), len);
  return out;
}

// Reads video properties on a worker thread (WinRT async must not block the
// STA platform thread). Responds null when the file is not a readable video.
void ProbeOnWorker(
    std::string path,
    std::shared_ptr<flutter::MethodResult<EncodableValue>> result) {
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    auto file = winrt::Windows::Storage::StorageFile::GetFileFromPathAsync(
                    winrt::hstring(Wide(path)))
                    .get();
    auto props = file.Properties().GetVideoPropertiesAsync().get();
    const int32_t w = static_cast<int32_t>(props.Width());
    const int32_t h = static_cast<int32_t>(props.Height());
    if (w == 0 || h == 0) {
      result->Success(EncodableValue());
      return;
    }
    const int32_t durationMs = static_cast<int32_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(props.Duration())
            .count());
    const int32_t kbps = static_cast<int32_t>(props.Bitrate() / 1000);
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("width"), EncodableValue(w)},
        {EncodableValue("height"), EncodableValue(h)},
        {EncodableValue("durationMs"), EncodableValue(durationMs)},
        {EncodableValue("overallBitrateKbps"), EncodableValue(kbps)},
    }));
  } catch (...) {
    result->Success(EncodableValue());
  }
}

}  // namespace

// static
void SubmersionTranscoderPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto methods = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "submersion_transcoder/methods",
      &flutter::StandardMethodCodec::GetInstance());

  auto progress = std::make_unique<flutter::EventChannel<EncodableValue>>(
      registrar->messenger(), "submersion_transcoder/progress",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<SubmersionTranscoderPlugin>();

  methods->SetMethodCallHandler(
      [p = plugin.get()](const auto& call, auto result) {
        p->HandleMethodCall(call, std::move(result));
      });

  progress->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [p = plugin.get()](
              const EncodableValue*,
              std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            std::lock_guard<std::mutex> lock(p->progress_mutex_);
            p->progress_sink_ =
                std::shared_ptr<flutter::EventSink<EncodableValue>>(
                    std::move(events));
            return nullptr;
          },
          [p = plugin.get()](const EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            std::lock_guard<std::mutex> lock(p->progress_mutex_);
            p->progress_sink_.reset();
            return nullptr;
          }));

  registrar->AddPlugin(std::move(plugin));
}

SubmersionTranscoderPlugin::SubmersionTranscoderPlugin() {}
SubmersionTranscoderPlugin::~SubmersionTranscoderPlugin() {}

void SubmersionTranscoderPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = method_call.method_name();
  if (method == "isAvailable") {
    result->Success(EncodableValue(true));
    return;
  }
  if (method == "probe") {
    const auto* args = std::get_if<EncodableMap>(method_call.arguments());
    const std::string* path = nullptr;
    if (args) {
      auto it = args->find(EncodableValue("path"));
      if (it != args->end()) path = std::get_if<std::string>(&it->second);
    }
    if (!path) {
      result->Success(EncodableValue());
      return;
    }
    std::shared_ptr<flutter::MethodResult<EncodableValue>> shared(
        std::move(result));
    std::thread(ProbeOnWorker, *path, shared).detach();
    return;
  }
  result->NotImplemented();
}

}  // namespace submersion_transcoder
