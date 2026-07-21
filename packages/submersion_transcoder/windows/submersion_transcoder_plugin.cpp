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

// Transcodes on a worker thread. `sink` may be null if Dart never subscribed
// to the progress channel.
void TranscodeOnWorker(
    std::string source, std::string output, int max_height, int video_kbps,
    int /*audio_kbps*/, std::string progress_id,
    std::shared_ptr<flutter::EventSink<EncodableValue>> sink,
    std::shared_ptr<flutter::MethodResult<EncodableValue>> result) {
  namespace WS = winrt::Windows::Storage;
  namespace WMP = winrt::Windows::Media::MediaProperties;
  namespace WMT = winrt::Windows::Media::Transcoding;
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);

    auto src_file =
        WS::StorageFile::GetFileFromPathAsync(winrt::hstring(Wide(source)))
            .get();

    // Never upscale: clamp the target height to the source height.
    auto vprops = src_file.Properties().GetVideoPropertiesAsync().get();
    const int32_t src_h = static_cast<int32_t>(vprops.Height());
    const int32_t src_w = static_cast<int32_t>(vprops.Width());
    int32_t out_h = max_height < src_h ? max_height : src_h;
    if (out_h <= 0) out_h = src_h;
    // Preserve aspect ratio, keep both dimensions even.
    int32_t out_w = src_h > 0
                        ? static_cast<int32_t>((int64_t)src_w * out_h / src_h)
                        : src_w;
    out_w -= (out_w % 2);
    out_h -= (out_h % 2);

    // Destination folder + <name>.tmp file (replace any stale temp).
    std::wstring wout = Wide(output);
    size_t slash = wout.find_last_of(L"\\/");
    std::wstring dir = slash == std::wstring::npos ? L"" : wout.substr(0, slash);
    std::wstring name =
        slash == std::wstring::npos ? wout : wout.substr(slash + 1);
    auto folder =
        WS::StorageFolder::GetFolderFromPathAsync(winrt::hstring(dir)).get();
    auto tmp_file =
        folder
            .CreateFileAsync(winrt::hstring(name + L".tmp"),
                             WS::CreationCollisionOption::ReplaceExisting)
            .get();

    auto profile =
        WMP::MediaEncodingProfile::CreateMp4(WMP::VideoEncodingQuality::Auto);
    profile.Video().Width(static_cast<uint32_t>(out_w));
    profile.Video().Height(static_cast<uint32_t>(out_h));
    profile.Video().Bitrate(static_cast<uint32_t>(video_kbps) * 1000);

    WMT::MediaTranscoder transcoder;
    auto prep =
        transcoder.PrepareFileTranscodeAsync(src_file, tmp_file, profile).get();
    if (!prep.CanTranscode()) {
      result->Error("transcode_failed", "source cannot be transcoded");
      return;
    }

    auto op = prep.TranscodeAsync();
    op.Progress([sink, progress_id](auto const&, double percent) {
      if (!sink) return;
      sink->Success(EncodableValue(EncodableMap{
          {EncodableValue("progressId"), EncodableValue(progress_id)},
          {EncodableValue("fraction"), EncodableValue(percent / 100.0)},
      }));
    });
    op.get();  // blocks until complete or throws on failure

    // Success: rename <name>.tmp -> <name>.
    tmp_file
        .RenameAsync(winrt::hstring(name),
                     WS::NameCollisionOption::ReplaceExisting)
        .get();
    if (sink) {
      sink->Success(EncodableValue(EncodableMap{
          {EncodableValue("progressId"), EncodableValue(progress_id)},
          {EncodableValue("fraction"), EncodableValue(1.0)},
      }));
    }
    result->Success(EncodableValue());
  } catch (winrt::hresult_error const& e) {
    result->Error("transcode_failed", Utf8(std::wstring(e.message())));
  } catch (...) {
    result->Error("transcode_failed", "unknown transcode error");
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
  if (method == "transcode") {
    const auto* args = std::get_if<EncodableMap>(method_call.arguments());
    if (!args) {
      result->Error("bad_args", "missing transcode arguments");
      return;
    }
    auto get_str = [&](const char* k) -> const std::string* {
      auto it = args->find(EncodableValue(k));
      return it == args->end() ? nullptr
                               : std::get_if<std::string>(&it->second);
    };
    auto get_int = [&](const char* k) -> const int32_t* {
      auto it = args->find(EncodableValue(k));
      return it == args->end() ? nullptr : std::get_if<int32_t>(&it->second);
    };
    const auto* source = get_str("source");
    const auto* output = get_str("output");
    const auto* max_height = get_int("maxHeight");
    const auto* video_kbps = get_int("videoBitrateKbps");
    const auto* audio_kbps = get_int("audioBitrateKbps");
    const auto* progress_id = get_str("progressId");
    if (!source || !output || !max_height || !video_kbps || !audio_kbps ||
        !progress_id) {
      result->Error("bad_args", "missing transcode arguments");
      return;
    }
    std::shared_ptr<flutter::EventSink<EncodableValue>> sink;
    {
      std::lock_guard<std::mutex> lock(progress_mutex_);
      sink = progress_sink_;
    }
    std::shared_ptr<flutter::MethodResult<EncodableValue>> shared(
        std::move(result));
    std::thread(TranscodeOnWorker, *source, *output, *max_height, *video_kbps,
                *audio_kbps, *progress_id, sink, shared)
        .detach();
    return;
  }
  result->NotImplemented();
}

}  // namespace submersion_transcoder
