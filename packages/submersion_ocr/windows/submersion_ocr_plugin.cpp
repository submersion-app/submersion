#include "submersion_ocr_plugin.h"

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <memory>
#include <thread>
#include <utility>
#include <vector>

namespace submersion_ocr {

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

// Runs OCR on a worker thread with blocking WinRT calls (the platform
// thread is an STA and must not block on async operations). The
// FlutterDesktopMessenger API is thread-safe, so responding from the
// worker is safe.
void RecognizeOnWorker(
    std::vector<uint8_t> data,
    std::shared_ptr<flutter::MethodResult<EncodableValue>> result) {
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);

    winrt::Windows::Storage::Streams::InMemoryRandomAccessStream stream;
    winrt::Windows::Storage::Streams::DataWriter writer(
        stream.GetOutputStreamAt(0));
    writer.WriteBytes(winrt::array_view<const uint8_t>(
        data.data(), data.data() + data.size()));
    writer.StoreAsync().get();
    writer.FlushAsync().get();

    auto decoder =
        winrt::Windows::Graphics::Imaging::BitmapDecoder::CreateAsync(stream)
            .get();
    auto bitmap = decoder.GetSoftwareBitmapAsync().get();

    auto engine = winrt::Windows::Media::Ocr::OcrEngine::
        TryCreateFromUserProfileLanguages();
    if (!engine) {
      result->Success(EncodableValue(EncodableList{}));
      return;
    }

    auto ocr = engine.RecognizeAsync(bitmap).get();

    EncodableList lines;
    const double img_w = static_cast<double>(bitmap.PixelWidth());
    const double img_h = static_cast<double>(bitmap.PixelHeight());
    for (auto const& line : ocr.Lines()) {
      double l = 1e18;
      double t = 1e18;
      double r = -1e18;
      double b = -1e18;
      for (auto const& word : line.Words()) {
        auto rect = word.BoundingRect();
        if (rect.X < l) l = rect.X;
        if (rect.Y < t) t = rect.Y;
        if (rect.X + rect.Width > r) r = rect.X + rect.Width;
        if (rect.Y + rect.Height > b) b = rect.Y + rect.Height;
      }
      if (r < l || b < t) continue;  // line with no words
      lines.push_back(EncodableValue(EncodableMap{
          {EncodableValue("text"),
           EncodableValue(winrt::to_string(line.Text()))},
          {EncodableValue("left"), EncodableValue(l)},
          {EncodableValue("top"), EncodableValue(t)},
          {EncodableValue("width"), EncodableValue(r - l)},
          {EncodableValue("height"), EncodableValue(b - t)},
          {EncodableValue("confidence"), EncodableValue()},
          {EncodableValue("imageWidth"), EncodableValue(img_w)},
          {EncodableValue("imageHeight"), EncodableValue(img_h)},
      }));
    }
    result->Success(EncodableValue(lines));
  } catch (winrt::hresult_error const& e) {
    result->Error("ocr_failed", winrt::to_string(e.message()));
  } catch (...) {
    result->Error("ocr_failed", "Unknown error during text recognition");
  }
}

}  // namespace

// static
void SubmersionOcrPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), "submersion_ocr",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<SubmersionOcrPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

SubmersionOcrPlugin::SubmersionOcrPlugin() {}

SubmersionOcrPlugin::~SubmersionOcrPlugin() {}

void SubmersionOcrPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  if (method_call.method_name() != "recognizeText") {
    result->NotImplemented();
    return;
  }
  const auto* args = std::get_if<EncodableMap>(method_call.arguments());
  if (!args) {
    result->Error("bad_args", "expected {'image': bytes}");
    return;
  }
  auto it = args->find(EncodableValue("image"));
  if (it == args->end()) {
    result->Error("bad_args", "expected {'image': bytes}");
    return;
  }
  const auto* bytes = std::get_if<std::vector<uint8_t>>(&it->second);
  if (!bytes) {
    result->Error("bad_args", "expected {'image': bytes}");
    return;
  }

  auto shared_result =
      std::shared_ptr<flutter::MethodResult<EncodableValue>>(
          std::move(result));
  std::thread(RecognizeOnWorker, *bytes, shared_result).detach();
}

}  // namespace submersion_ocr
