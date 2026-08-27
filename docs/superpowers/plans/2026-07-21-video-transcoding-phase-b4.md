# Video Transcoding Phase B4 — Windows (WinRT MediaTranscoder)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Windows engine to `submersion_transcoder` so a non-`Original` video level transcodes natively on Windows.

**Architecture:** Reuse the shared Dart `ChannelTranscodeEngine` (from B3) on Windows — only native code differs. Add the `windows:` platform to the plugin: a C++ `SubmersionTranscoderPlugin` (mirroring `submersion_ocr/windows`) implementing the same `submersion_transcoder/methods` + `/progress` channel contract, backed by WinRT `Windows.Media.Transcoding.MediaTranscoder` (H.264/AAC MP4, height cap, progress).

**Tech Stack:** C++/WinRT, CMake, Flutter Windows embedding. Template: `packages/submersion_ocr/windows`.

## Global Constraints

- Branch `worktree-media-upload-quality-phase-b4`, stacked on B3 (PR #673).
- **VERIFICATION BOUNDARY — this host is macOS; Windows C++ CANNOT be compiled or run here.** The macOS-available gates ARE run: `dart format .`, `flutter analyze` (Dart), full `flutter test` (the Dart `ChannelTranscodeEngine` already covers Windows via mocked channels; `engineForThisPlatform`'s Windows arm is exercised only on a Windows host). The C++ **compile** (`flutter build windows`) and the **runtime** transcode are explicitly DEFERRED to a Windows/CI host. Do NOT claim Windows compile or runtime success from this host — the PR must state the C++ is unverified-on-Windows.
- Channel contract (identical to darwin/android): MethodChannel `submersion_transcoder/methods` (`isAvailable`→bool; `probe {path}`→`{width,height,durationMs,overallBitrateKbps}`|null; `transcode {source,output,maxHeight,videoBitrateKbps,audioBitrateKbps,progressId}`→null|error). EventChannel `submersion_transcoder/progress` streams `{progressId,fraction}`.
- Output: H.264 + AAC `.mp4`, scale to `maxHeight` (never upscale), write `<output>.tmp` then rename.
- `dart format .` clean; `flutter analyze` clean (info lints fatal). Windows CMake floor 3.14 (do not raise). `#define NOMINMAX` before `<windows.h>` (memory: windows-minmax-macro).

---

### Task 1: Dart — return the shared engine on Windows

**Files:**
- Modify: `packages/submersion_transcoder/lib/src/engine_factory.dart` (`engineForThisPlatform`: add `Platform.isWindows`)
- Modify: `test/features/media_store/engine_for_platform_test.dart` (Windows arm)

**Interfaces:**
- Consumes: `ChannelTranscodeEngine` (B3). Produces: `engineForThisPlatform()` returns it on Windows too.

- [ ] **Step 1: Add the Windows arm**

In `engine_factory.dart`, extend the native-channel branch:
```dart
  if (Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isAndroid ||
      Platform.isWindows) {
    return ChannelTranscodeEngine();
  }
```
Update the doc comment above it to add ", Windows = Media Foundation via WinRT" and drop the "Windows arrives in B4" note.

- [ ] **Step 2: Add the test arm**

In `engine_for_platform_test.dart`, add `|| Platform.isWindows` to the `ChannelTranscodeEngine` branch:
```dart
    if (Platform.isMacOS ||
        Platform.isIOS ||
        Platform.isAndroid ||
        Platform.isWindows) {
      expect(engine, isA<ChannelTranscodeEngine>());
```

- [ ] **Step 3: Run + format + analyze**

Run: `dart format packages/submersion_transcoder/lib/src/engine_factory.dart test/features/media_store/engine_for_platform_test.dart` then `flutter test test/features/media_store/engine_for_platform_test.dart`
Expected: PASS (on macOS the Windows arm is inert; the test still asserts the macOS branch).

- [ ] **Step 4: Commit**
```bash
git add -A && git commit -m "feat(transcoder): return ChannelTranscodeEngine on Windows"
```

---

### Task 2: Windows plugin scaffold — pubspec + CMake + C-API + method channel

**Files:**
- Modify: `packages/submersion_transcoder/pubspec.yaml` (add `windows:` platform)
- Create: `packages/submersion_transcoder/windows/CMakeLists.txt`
- Create: `packages/submersion_transcoder/windows/include/submersion_transcoder/submersion_transcoder_plugin_c_api.h`
- Create: `packages/submersion_transcoder/windows/submersion_transcoder_plugin_c_api.cpp`
- Create: `packages/submersion_transcoder/windows/submersion_transcoder_plugin.h`
- Create: `packages/submersion_transcoder/windows/submersion_transcoder_plugin.cpp` (isAvailable + probe; transcode stub added in Task 3)

**Interfaces:**
- Produces: `SubmersionTranscoderPluginCApi` registering both channels; `isAvailable`→true, `probe`→VideoProperties map.

- [ ] **Step 1: Add `windows:` to the plugin block** (after the `android:` block):
```yaml
      windows:
        pluginClass: SubmersionTranscoderPluginCApi
```

- [ ] **Step 2: `windows/CMakeLists.txt`** (mirrors OCR; links `WindowsApp.lib` for WinRT):
```cmake
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "submersion_transcoder")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "submersion_transcoder_plugin")

list(APPEND PLUGIN_SOURCES
  "submersion_transcoder_plugin.cpp"
  "submersion_transcoder_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/submersion_transcoder/submersion_transcoder_plugin_c_api.h"
  "submersion_transcoder_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
# C++/WinRT projection for Windows.Media.Transcoding.
target_link_libraries(${PLUGIN_NAME} PRIVATE WindowsApp.lib)

set(submersion_transcoder_bundled_libraries
  ""
  PARENT_SCOPE
)
```

- [ ] **Step 3: `windows/include/submersion_transcoder/submersion_transcoder_plugin_c_api.h`**:
```cpp
#ifndef FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void SubmersionTranscoderPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_PLUGIN_C_API_H_
```

- [ ] **Step 4: `windows/submersion_transcoder_plugin_c_api.cpp`**:
```cpp
#include "include/submersion_transcoder/submersion_transcoder_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "submersion_transcoder_plugin.h"

void SubmersionTranscoderPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  submersion_transcoder::SubmersionTranscoderPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
```

- [ ] **Step 5: `windows/submersion_transcoder_plugin.h`**:
```cpp
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
```

- [ ] **Step 6: `windows/submersion_transcoder_plugin.cpp`** (scaffold: registration of BOTH channels, isAvailable, probe; transcode returns notImplemented until Task 3):
```cpp
#include "submersion_transcoder_plugin.h"

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.MediaProperties.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.FileProperties.h>

#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
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
    const auto* path =
        args ? std::get_if<std::string>(
                   &args->find(EncodableValue("path"))->second)
             : nullptr;
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
```
Note the `Utf8` helper is unused in this task but is used by Task 3 (the transcode path/error strings); keep it — Task 3 references it. (If the analyzer/compiler on Windows warns unused, Task 3 removes the warning by using it.)

- [ ] **Step 7: `flutter pub get`** (regenerates the Windows plugin registrant list; harmless on macOS):

Run: `flutter pub get`
Expected: succeeds. (No Windows build on macOS — the C++ is not compiled here.)

- [ ] **Step 8: Commit**
```bash
git add packages/submersion_transcoder/pubspec.yaml packages/submersion_transcoder/windows
git commit -m "feat(transcoder): Windows plugin scaffold + WinRT probe (unverified on Windows)"
```

---

### Task 3: Windows transcode via MediaTranscoder + progress

**Files:**
- Modify: `packages/submersion_transcoder/windows/submersion_transcoder_plugin.cpp` (add `TranscodeOnWorker` + `transcode` dispatch)

- [ ] **Step 1: Add WinRT transcoding includes** (top of the file, with the other `winrt/*` includes):
```cpp
#include <winrt/Windows.Media.Transcoding.h>
#include <winrt/Windows.Storage.Search.h>
```

- [ ] **Step 2: Add `TranscodeOnWorker`** in the anonymous namespace (before `RegisterWithRegistrar`). It probes for the source height (never upscale), builds an H.264/AAC MP4 profile, transcodes to `<output>.tmp`, forwards progress to the sink, then renames:
```cpp
// Transcodes on a worker thread. `sink` may be null if Dart never subscribed.
void TranscodeOnWorker(
    std::string source, std::string output, int max_height,
    int video_kbps, int /*audio_kbps*/, std::string progress_id,
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
    // Preserve aspect, keep dimensions even.
    int32_t out_w =
        src_h > 0 ? static_cast<int32_t>((int64_t)src_w * out_h / src_h) : src_w;
    out_w -= (out_w % 2);
    out_h -= (out_h % 2);

    // Destination folder + <name>.tmp file (replace any stale temp).
    std::wstring wout = Wide(output);
    size_t slash = wout.find_last_of(L"\\/");
    std::wstring dir = slash == std::wstring::npos ? L"" : wout.substr(0, slash);
    std::wstring name = slash == std::wstring::npos ? wout : wout.substr(slash + 1);
    auto folder =
        WS::StorageFolder::GetFolderFromPathAsync(winrt::hstring(dir)).get();
    auto tmp_file =
        folder
            .CreateFileAsync(winrt::hstring(name + L".tmp"),
                             WS::CreationCollisionOption::ReplaceExisting)
            .get();

    auto profile = WMP::MediaEncodingProfile::CreateMp4(
        WMP::VideoEncodingQuality::Auto);
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
```

- [ ] **Step 3: Dispatch `transcode`** in `HandleMethodCall` (before the final `NotImplemented`):
```cpp
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
```

- [ ] **Step 4: macOS gates** (the C++ is NOT compiled here):

Run: `dart format .` (0 changed for C++ — dart-format ignores `.cpp`), `flutter analyze` (clean), `flutter pub get`.
Expected: clean. The Windows build is deferred.

- [ ] **Step 5: Commit**
```bash
git add packages/submersion_transcoder/windows/submersion_transcoder_plugin.cpp
git commit -m "feat(transcoder): Windows MediaTranscoder transcode + progress (unverified on Windows)"
```

---

### Task 4: Full gates + integration test doc

**Files:**
- Create: `integration_test/windows_transcode_test.dart`

- [ ] **Step 1: Windows integration test** (same shape as darwin/android; Windows-only, skips without a pushed clip):
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

/// Real-engine integration test for the Windows MediaTranscoder engine
/// (spec §14). Runs on a Windows build (`flutter test integration_test
/// -d windows`); NOT part of plain `flutter test`. Looks for a clip the
/// harness places at the temp dir as `it_input.mp4` and skips when absent.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MediaTranscoder transcodes a real clip smaller', (tester) async {
    if (!Platform.isWindows) {
      markTestSkipped('windows transcode integration runs on Windows only');
      return;
    }
    final engine = engineForThisPlatform()!;
    expect(engine, isA<ChannelTranscodeEngine>());
    expect(await engine.isAvailable(), isTrue);

    final tmp = Directory.systemTemp;
    final input = File('${tmp.path}/it_input.mp4');
    if (!await input.exists()) {
      markTestSkipped('no it_input.mp4 at ${input.path}; skipping');
      return;
    }
    final probe = (await engine.probe(input))!;
    expect(probe.height, greaterThan(0));

    final output = File('${tmp.path}/it_out.mp4');
    if (await output.exists()) await output.delete();
    final fractions = <double>[];
    await engine.transcode(
      source: input,
      output: output,
      target: const TranscodeTarget(
        maxHeight: 240,
        videoBitrateKbps: 300,
        audioBitrateKbps: 64,
      ),
      probe: probe,
      onProgress: fractions.add,
    );
    expect(await output.exists(), isTrue);
    final outProbe = (await engine.probe(output))!;
    expect(outProbe.height, lessThanOrEqualTo(240));
    expect(await output.length(), lessThan(await input.length()));
  });
}
```

- [ ] **Step 2: Full gates**

Run:
```bash
dart format .
flutter analyze
flutter test
```
Expected: format clean, analyzer clean, full suite green (the known flaky backup-crypto test may fail only in the full ordering; confirm it passes isolated — it is not a regression).

- [ ] **Step 3: Commit**
```bash
git add integration_test/windows_transcode_test.dart
git commit -m "test(transcoder): Windows MediaTranscoder integration test"
```

---

## Self-Review notes

- **Spec coverage:** §9 channel shape → Task 2/3 (same channels as darwin/android); §10 Windows (Media Foundation → satisfied via WinRT MediaTranscoder, the modern MF-based API: H.264/AAC MP4, height cap, bitrate, progress, tmp-rename) → Task 3; §15 (Windows last) → this plan.
- **Verification honesty:** every step that could imply Windows success is qualified "(unverified on Windows)"; the only gates actually run are the macOS-available Dart ones. The C++ compile + runtime are deferred to a Windows/CI host, stated in the PR.
- **Known risks flagged in-plan:** (a) WinRT `EventSink::Success` is called from a worker thread — common in practice but must be confirmed thread-safe on the Windows embedding when the C++ is first built; (b) `MediaEncodingProfile::CreateMp4(Auto)` then overriding Width/Height/Bitrate is the exact-control path — verify `CanTranscode()` accepts the overridden profile on a real clip; (c) audio bitrate is not overridden (CreateMp4 supplies AAC), matching the Android limitation. All three are Windows-build follow-ups, not macOS-resolvable.
