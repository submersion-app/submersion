# Video Transcoding Phase B2 — Apple AVFoundation Engine (iOS + macOS)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `submersion_transcoder` into a Flutter plugin with a shared-darwin AVFoundation engine, so a non-`Original` video level transcodes natively on iOS and macOS.

**Architecture:** Convert the plain Dart package into a plugin with `sharedDarwinSource` (one `darwin/` dir, mirroring `submersion_ocr`). A Swift `AvfTranscoder` (AVAssetReader + AVAssetWriter) does the work; the plugin exposes `isAvailable`/`probe`/`transcode` over a MethodChannel and progress over an EventChannel. A Dart `DarwinAvfEngine implements TranscodeEngine` marshals to those channels and, crucially, degrades to "unavailable" on `MissingPluginException` so `flutter test` (no plugin registration) stays green. `engineForThisPlatform()` returns it on iOS/macOS.

**Tech Stack:** Swift (AVFoundation / VideoToolbox), Flutter platform channels, Dart. Template: `packages/submersion_ocr` (sharedDarwinSource Swift plugin).

**Spec:** `docs/superpowers/specs/2026-07-21-video-transcoding-phase-b-design.md` (§9 plugin/channel shape, §10 darwin notes, §15 delivery order). Scope = the darwin engine ONLY; Android is B3, Windows is B4.

## Global Constraints

- Branch `worktree-media-upload-quality-phase-b2`, stacked on B1 (PR #668). Worktree build-ready.
- **Verification reality — native Swift is NOT run by `flutter test`** (no plugin registration in the test harness). Therefore:
  1. The Dart `DarwinAvfEngine` is unit-tested against a **mock** MethodChannel/EventChannel via `TestDefaultBinaryMessengerBinding` — arg marshaling, availability, progress decoding, `MissingPluginException` → unavailable, error → `TranscodeException`.
  2. The Swift is **compile-verified** with `flutter build macos --debug` (from the app root).
  3. Real transcoding is verified by an **`integration_test/`** that runs on a macOS build/CI, tagged so plain `flutter test` never runs it.
  **Never claim runtime transcode success from `flutter test` alone.**
- Engine contract (unchanged from B1): `transcode` writes `<output>.tmp` then renames; throws `TranscodeException` on genuine failure; the adapter treats unavailable/probe-fail/within-ceiling as "upload original" (that logic lives in `PlatformVideoTranscoder`, already shipped — B2 does not touch it).
- Output: H.264 + AAC `.mp4`, faststart, scale to `maxHeight` (never upscale), rotation honored.
- `dart format .` clean; `flutter analyze` clean (info lints fatal); ≥ 90% patch coverage on the Dart additions.
- macOS plugin gotchas: adding a new plugin's first native file can leave stale Pods — a failed macOS build after Task 1 usually needs `flutter clean && (cd macos && pod install)` in the **app**. CI uses CocoaPods (SPM disabled), so the podspec is the source of truth (no `Package.swift` needed for B2).
- `*.g.dart` gitignored; `lib/l10n/arb/app_localizations*.dart` tracked (B2 adds no l10n).

## Channel contract (both sides implement exactly this)

- MethodChannel `submersion_transcoder/methods`:
  - `isAvailable` → `bool` (always true on iOS/macOS once the plugin loads).
  - `probe` `{path: String}` → `{width:int, height:int, durationMs:int, overallBitrateKbps:int}` or `null`.
  - `transcode` `{source:String, output:String, maxHeight:int, videoBitrateKbps:int, audioBitrateKbps:int, progressId:String}` → `null` on success; `FlutterError` on failure.
- EventChannel `submersion_transcoder/progress`: streams `{progressId:String, fraction:double}` maps; the Dart side filters by its `progressId`.

---

### Task 1: Convert package to a plugin (scaffold + stub Swift) — compile gate

**Files:**
- Modify: `packages/submersion_transcoder/pubspec.yaml` (add `flutter: plugin:` block)
- Create: `packages/submersion_transcoder/darwin/submersion_transcoder.podspec`
- Create: `packages/submersion_transcoder/darwin/Classes/SubmersionTranscoderPlugin.swift` (registration + channel wiring; handlers return notImplemented for now)

**Interfaces:**
- Produces: a loadable iOS/macOS plugin `SubmersionTranscoderPlugin` registering the two channels above.

- [ ] **Step 1: Add the plugin block to `pubspec.yaml`** (append under a new `flutter:` key; a plain package has none):

```yaml
flutter:
  plugin:
    platforms:
      ios:
        pluginClass: SubmersionTranscoderPlugin
        sharedDarwinSource: true
      macos:
        pluginClass: SubmersionTranscoderPlugin
        sharedDarwinSource: true
```

- [ ] **Step 2: Create the podspec** (mirrors `packages/submersion_ocr/darwin/submersion_ocr.podspec`):

```ruby
Pod::Spec.new do |s|
  s.name             = 'submersion_transcoder'
  s.version          = '0.1.0'
  s.summary          = 'Native video transcoding for Submersion.'
  s.description      = 'AVFoundation H.264/AAC transcoding behind a Flutter channel.'
  s.homepage         = 'https://submersion.app'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Submersion' => 'dev@submersion.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version = '5.0'
end
```

- [ ] **Step 3: Create the plugin registration stub** (channels wired; handlers stubbed):

```swift
// packages/submersion_transcoder/darwin/Classes/SubmersionTranscoderPlugin.swift
import AVFoundation
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

public class SubmersionTranscoderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var progressSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let methods = FlutterMethodChannel(
      name: "submersion_transcoder/methods", binaryMessenger: messenger)
    let progress = FlutterEventChannel(
      name: "submersion_transcoder/progress", binaryMessenger: messenger)
    let instance = SubmersionTranscoderPlugin()
    registrar.addMethodCallDelegate(instance, channel: methods)
    progress.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    progressSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    progressSink = nil
    return nil
  }
}
```

- [ ] **Step 4: Compile-verify with a macOS build** (from the app root)

Run: `flutter build macos --debug 2>&1 | tail -20`
Expected: BUILD SUCCEEDED. If it fails with a CocoaPods/module error for the new plugin: `flutter clean && flutter pub get && (cd macos && pod install)` then rebuild (the stale-Pods gotcha).

- [ ] **Step 5: Commit**

```bash
git add packages/submersion_transcoder/pubspec.yaml packages/submersion_transcoder/darwin
git commit -m "feat(transcoder): convert to plugin with darwin scaffold (iOS+macOS)"
```

---

### Task 2: Dart `DarwinAvfEngine` (channel client) + unit tests

**Files:**
- Create: `packages/submersion_transcoder/lib/src/darwin_avf_engine.dart`
- Modify: `packages/submersion_transcoder/lib/submersion_transcoder.dart` (export)
- Test: `test/features/media_store/darwin_avf_engine_test.dart` (in the APP test tree, imports the package)

**Interfaces:**
- Consumes: `TranscodeEngine`, `TranscodeTarget`, `VideoProbe`, `TranscodeException` (B1).
- Produces: `class DarwinAvfEngine implements TranscodeEngine` with ctor `DarwinAvfEngine({MethodChannel? methods, EventChannel? progress})` (defaults to the real channels). `isAvailable`/`probe` swallow `MissingPluginException` (→ false/null); `transcode` maps a `PlatformException` to `TranscodeException` and streams progress filtered by a generated `progressId`.

- [ ] **Step 1: Write the failing test** (mock the platform channels via `TestDefaultBinaryMessengerBinding`)

```dart
// test/features/media_store/darwin_avf_engine_test.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('submersion_transcoder/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
  });

  test('isAvailable returns the channel result', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'isAvailable');
      return true;
    });
    expect(await DarwinAvfEngine().isAvailable(), isTrue);
  });

  test('isAvailable is false when the plugin is missing', () async {
    // No handler registered -> MissingPluginException.
    expect(await DarwinAvfEngine().isAvailable(), isFalse);
  });

  test('probe decodes the channel map', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'probe');
      expect((call.arguments as Map)['path'], '/x.mov');
      return {
        'width': 1920,
        'height': 1080,
        'durationMs': 5000,
        'overallBitrateKbps': 9000,
      };
    });
    final probe = (await DarwinAvfEngine().probe(File('/x.mov')))!;
    expect(probe.height, 1080);
    expect(probe.overallBitrateKbps, 9000);
  });

  test('probe returns null when the channel returns null', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => null);
    expect(await DarwinAvfEngine().probe(File('/x.mov')), isNull);
  });

  test('transcode forwards target args and completes on success', () async {
    Map<Object?, Object?>? seen;
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'transcode') {
        seen = call.arguments as Map<Object?, Object?>;
        return null;
      }
      return null;
    });
    await DarwinAvfEngine().transcode(
      source: File('/in.mov'),
      output: File('/out.mp4'),
      target: const TranscodeTarget(
        maxHeight: 720,
        videoBitrateKbps: 4000,
        audioBitrateKbps: 128,
      ),
    );
    expect(seen!['maxHeight'], 720);
    expect(seen!['videoBitrateKbps'], 4000);
    expect(seen!['output'], '/out.mp4');
    expect(seen!['progressId'], isA<String>());
  });

  test('a PlatformException becomes a TranscodeException', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'transcode_failed', message: 'boom');
    });
    await expectLater(
      DarwinAvfEngine().transcode(
        source: File('/in.mov'),
        output: File('/out.mp4'),
        target: const TranscodeTarget(
          maxHeight: 720,
          videoBitrateKbps: 4000,
          audioBitrateKbps: 128,
        ),
      ),
      throwsA(isA<TranscodeException>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/darwin_avf_engine_test.dart`
Expected: FAIL (DarwinAvfEngine undefined).

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/submersion_transcoder/lib/src/darwin_avf_engine.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:submersion_transcoder/src/transcode_engine.dart';
import 'package:submersion_transcoder/src/transcode_target.dart';
import 'package:submersion_transcoder/src/video_probe.dart';

/// AVFoundation engine (iOS + macOS). A thin Dart client over the plugin's
/// channels; the real work is in Swift. Degrades to "unavailable" when the
/// plugin is not registered (e.g. `flutter test`), so absence is a normal
/// state that maps onto the pipeline's upload-the-original fallback.
class DarwinAvfEngine implements TranscodeEngine {
  DarwinAvfEngine({MethodChannel? methods, EventChannel? progress})
    : _methods =
          methods ?? const MethodChannel('submersion_transcoder/methods'),
      _progress =
          progress ?? const EventChannel('submersion_transcoder/progress');

  final MethodChannel _methods;
  final EventChannel _progress;
  int _seq = 0;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _methods.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<VideoProbe?> probe(File source) async {
    try {
      final map = await _methods.invokeMapMethod<String, dynamic>('probe', {
        'path': source.path,
      });
      if (map == null) return null;
      return VideoProbe(
        width: map['width'] as int,
        height: map['height'] as int,
        durationMs: map['durationMs'] as int,
        overallBitrateKbps: map['overallBitrateKbps'] as int,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> transcode({
    required File source,
    required File output,
    required TranscodeTarget target,
    VideoProbe? probe,
    void Function(double fraction)? onProgress,
  }) async {
    final progressId = 'p${_seq++}';
    StreamSubscription<dynamic>? sub;
    if (onProgress != null) {
      sub = _progress.receiveBroadcastStream().listen((event) {
        if (event is Map && event['progressId'] == progressId) {
          final f = (event['fraction'] as num).toDouble();
          onProgress(f.clamp(0.0, 1.0));
        }
      });
    }
    try {
      await _methods.invokeMethod<void>('transcode', {
        'source': source.path,
        'output': output.path,
        'maxHeight': target.maxHeight,
        'videoBitrateKbps': target.videoBitrateKbps,
        'audioBitrateKbps': target.audioBitrateKbps,
        'progressId': progressId,
      });
    } on PlatformException catch (e) {
      throw TranscodeException('AVFoundation transcode failed: ${e.message}');
    } on MissingPluginException {
      throw const TranscodeException('transcoder plugin not registered');
    } finally {
      await sub?.cancel();
    }
  }
}
```

Add to `packages/submersion_transcoder/lib/submersion_transcoder.dart`:
```dart
export 'src/darwin_avf_engine.dart';
```
(The package now imports `package:flutter/services.dart`, so its `pubspec.yaml` needs a Flutter SDK dependency — add under `dependencies:`:)
```yaml
dependencies:
  flutter:
    sdk: flutter
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/darwin_avf_engine_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/submersion_transcoder/lib packages/submersion_transcoder/pubspec.yaml test/features/media_store/darwin_avf_engine_test.dart
git commit -m "feat(transcoder): Dart DarwinAvfEngine channel client"
```

---

### Task 3: Swift AVFoundation probe + transcode

**Files:**
- Create: `packages/submersion_transcoder/darwin/Classes/AvfTranscoder.swift`
- Modify: `packages/submersion_transcoder/darwin/Classes/SubmersionTranscoderPlugin.swift` (dispatch `probe`/`transcode` to `AvfTranscoder`; push progress to the sink)

**Interfaces:**
- Produces: `AvfTranscoder.probe(path) -> [String: Any]?` and `AvfTranscoder.transcode(...)` writing `<output>.tmp` then renaming, invoking a progress closure.

- [ ] **Step 1: Write `AvfTranscoder.swift`**

```swift
// packages/submersion_transcoder/darwin/Classes/AvfTranscoder.swift
import AVFoundation
import CoreMedia

enum AvfTranscodeError: Error { case noVideoTrack, readerFailed, writerFailed(String) }

final class AvfTranscoder {
  /// AVAsset-based probe (no ffprobe on Apple). Returns nil for a
  /// non-video / unreadable asset.
  static func probe(path: String) -> [String: Any]? {
    let asset = AVAsset(url: URL(fileURLWithPath: path))
    guard let v = asset.tracks(withMediaType: .video).first else { return nil }
    let size = v.naturalSize.applying(v.preferredTransform)
    let w = Int(abs(size.width)), h = Int(abs(size.height))
    if w == 0 || h == 0 { return nil }
    let durationMs = Int(CMTimeGetSeconds(asset.duration) * 1000)
    // Overall bitrate: sum of track data rates (bits/s) -> kbps.
    let bps = asset.tracks.reduce(Float(0)) { $0 + $1.estimatedDataRate }
    return [
      "width": w, "height": h,
      "durationMs": durationMs,
      "overallBitrateKbps": Int(bps / 1000),
    ]
  }

  /// Reads with AVAssetReader, re-encodes H.264+AAC with AVAssetWriter to
  /// '<output>.tmp', renames on success. Progress is fraction of duration.
  static func transcode(
    source: String, output: String,
    maxHeight: Int, videoBitrateKbps: Int, audioBitrateKbps: Int,
    onProgress: @escaping (Double) -> Void
  ) throws {
    let asset = AVAsset(url: URL(fileURLWithPath: source))
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
      throw AvfTranscodeError.noVideoTrack
    }
    let tmpURL = URL(fileURLWithPath: output + ".tmp")
    try? FileManager.default.removeItem(at: tmpURL)

    let reader = try AVAssetReader(asset: asset)
    let writer = try AVAssetWriter(outputURL: tmpURL, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true // faststart

    // Output dimensions: scale to maxHeight, preserve aspect, never upscale,
    // even dimensions. Rotation is preserved via the writer input transform.
    let t = videoTrack.preferredTransform
    let natural = videoTrack.naturalSize.applying(t)
    let srcH = abs(natural.height), srcW = abs(natural.width)
    let outH = min(CGFloat(maxHeight), srcH)
    let scale = srcH == 0 ? 1 : outH / srcH
    let evenH = (Int(outH.rounded()) / 2) * 2
    let evenW = (Int((srcW * scale).rounded()) / 2) * 2

    let videoOut = AVAssetReaderTrackOutput(
      track: videoTrack,
      outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String:
          kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
      ])
    reader.add(videoOut)
    let videoIn = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: evenW,
        AVVideoHeightKey: evenH,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: videoBitrateKbps * 1000
        ],
      ])
    videoIn.expectsMediaDataInRealTime = false
    videoIn.transform = t // honor rotation
    writer.add(videoIn)

    // Audio (optional).
    var audioOut: AVAssetReaderTrackOutput?
    var audioIn: AVAssetWriterInput?
    if let audioTrack = asset.tracks(withMediaType: .audio).first {
      let ao = AVAssetReaderTrackOutput(
        track: audioTrack,
        outputSettings: [
          AVFormatIDKey: kAudioFormatLinearPCM,
        ])
      reader.add(ao)
      audioOut = ao
      let ai = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVNumberOfChannelsKey: 2,
          AVSampleRateKey: 44100,
          AVEncoderBitRateKey: audioBitrateKbps * 1000,
        ])
      ai.expectsMediaDataInRealTime = false
      writer.add(ai)
      audioIn = ai
    }

    guard reader.startReading() else {
      throw AvfTranscodeError.writerFailed("reader: \(reader.error?.localizedDescription ?? "unknown")")
    }
    guard writer.startWriting() else {
      throw AvfTranscodeError.writerFailed("writer: \(writer.error?.localizedDescription ?? "unknown")")
    }
    writer.startSession(atSourceTime: .zero)

    let durationSec = CMTimeGetSeconds(asset.duration)
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "avf.transcode")

    func pump(_ input: AVAssetWriterInput, _ out: AVAssetReaderTrackOutput,
              reportProgress: Bool) {
      group.enter()
      input.requestMediaDataWhenReady(on: queue) {
        while input.isReadyForMoreMediaData {
          guard reader.status == .reading,
                let sample = out.copyNextSampleBuffer() else {
            input.markAsFinished()
            group.leave()
            return
          }
          if reportProgress, durationSec > 0 {
            let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
            onProgress(min(1.0, pts / durationSec))
          }
          input.append(sample)
        }
      }
    }

    pump(videoIn, videoOut, reportProgress: true)
    if let ai = audioIn, let ao = audioOut { pump(ai, ao, reportProgress: false) }

    group.wait()
    if reader.status == .failed {
      throw AvfTranscodeError.writerFailed(
        "reader failed: \(reader.error?.localizedDescription ?? "unknown")")
    }
    let sem = DispatchSemaphore(value: 0)
    writer.finishWriting { sem.signal() }
    sem.wait()
    guard writer.status == .completed else {
      try? FileManager.default.removeItem(at: tmpURL)
      throw AvfTranscodeError.writerFailed(
        writer.error?.localizedDescription ?? "writer incomplete")
    }
    onProgress(1.0)
    try FileManager.default.moveItem(
      at: tmpURL, to: URL(fileURLWithPath: output))
  }
}
```

- [ ] **Step 2: Wire the handlers in `SubmersionTranscoderPlugin.swift`** — replace the `handle` method:

```swift
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(true)
    case "probe":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(nil); return
      }
      result(AvfTranscoder.probe(path: path))
    case "transcode":
      guard let a = call.arguments as? [String: Any],
            let source = a["source"] as? String,
            let output = a["output"] as? String,
            let maxHeight = a["maxHeight"] as? Int,
            let vk = a["videoBitrateKbps"] as? Int,
            let ak = a["audioBitrateKbps"] as? Int,
            let progressId = a["progressId"] as? String else {
        result(FlutterError(code: "bad_args", message: "transcode args", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        do {
          try AvfTranscoder.transcode(
            source: source, output: output,
            maxHeight: maxHeight, videoBitrateKbps: vk, audioBitrateKbps: ak,
            onProgress: { fraction in
              DispatchQueue.main.async {
                self?.progressSink?(["progressId": progressId, "fraction": fraction])
              }
            })
          DispatchQueue.main.async { result(nil) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "transcode_failed",
                                message: error.localizedDescription, details: nil))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
```

- [ ] **Step 3: Compile-verify**

Run: `flutter build macos --debug 2>&1 | tail -20`
Expected: BUILD SUCCEEDED (fix Swift compile errors surfaced here; this is the only place they appear).

- [ ] **Step 4: Commit**

```bash
git add packages/submersion_transcoder/darwin/Classes
git commit -m "feat(transcoder): AVFoundation probe + transcode (Swift)"
```

---

### Task 4: Dispatch to the darwin engine on Apple

**Files:**
- Modify: `packages/submersion_transcoder/lib/src/transcode_engine.dart` (`engineForThisPlatform`)
- Test: `test/features/media_store/engine_for_platform_test.dart`

**Interfaces:**
- Produces: `engineForThisPlatform()` returns `DarwinAvfEngine()` on iOS/macOS, `LinuxFfmpegEngine()` on Linux, null elsewhere.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media_store/engine_for_platform_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

void main() {
  test('returns the right engine type for this host', () {
    final engine = engineForThisPlatform();
    if (Platform.isMacOS || Platform.isIOS) {
      expect(engine, isA<DarwinAvfEngine>());
    } else if (Platform.isLinux) {
      expect(engine, isA<LinuxFfmpegEngine>());
    } else {
      expect(engine, isNull);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/engine_for_platform_test.dart`
Expected: FAIL on macOS (currently returns null on non-Linux).

- [ ] **Step 3: Update `engineForThisPlatform`** in `transcode_engine.dart`:

```dart
import 'package:submersion_transcoder/src/darwin_avf_engine.dart';
```
```dart
TranscodeEngine? engineForThisPlatform() {
  if (Platform.isIOS || Platform.isMacOS) return DarwinAvfEngine();
  if (Platform.isLinux) return LinuxFfmpegEngine();
  return null;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media_store/engine_for_platform_test.dart test/features/media_store/media_store_video_providers_test.dart`
Expected: PASS. (The B1 `videoTranscodeAvailableProvider` test still resolves to a bool: on the macOS test host `DarwinAvfEngine.isAvailable()` catches `MissingPluginException` → false.)

- [ ] **Step 5: Commit**

```bash
git add packages/submersion_transcoder/lib/src/transcode_engine.dart test/features/media_store/engine_for_platform_test.dart
git commit -m "feat(transcoder): dispatch to AVFoundation engine on Apple"
```

---

### Task 5: Real-transcode integration test (macOS)

**Files:**
- Create: `integration_test/darwin_transcode_test.dart`
- Verify: `integration_test/` exists (create the dir; the repo may already have one)

**Interfaces:** exercises the fully-registered plugin on a real macOS build.

- [ ] **Step 1: Write the integration test** (synthesizes its input with AVFoundation so no binary fixture is committed)

```dart
// integration_test/darwin_transcode_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AVFoundation transcodes a real clip smaller', (tester) async {
    if (!(Platform.isMacOS || Platform.isIOS)) return;
    final engine = engineForThisPlatform()!;
    expect(await engine.isAvailable(), isTrue);

    final dir = await Directory.systemTemp.createTemp('avf_it');
    addTearDown(() => dir.delete(recursive: true));
    // Bundle a tiny sample via the test asset (see Step 2) OR generate with
    // AVFoundation; here we read a committed 1s sample from the app bundle.
    final input = File('${dir.path}/in.mp4');
    final bytes = await File('test/fixtures/sample_1s.mp4').readAsBytes();
    await input.writeAsBytes(bytes);

    final probe = (await engine.probe(input))!;
    expect(probe.height, greaterThan(0));

    final output = File('${dir.path}/out.mp4');
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
    expect(await File('${output.path}.tmp').exists(), isFalse);
    final outProbe = (await engine.probe(output))!;
    expect(outProbe.height, lessThanOrEqualTo(240));
    expect(await output.length(), lessThan(await input.length()));
    expect(fractions.last, 1.0);
  });
}
```

- [ ] **Step 2: Provide the fixture** — a real committed clip is needed for the integration test (integration tests bundle assets, and synthesizing H.264 from Dart is not available without ffmpeg). Generate one locally on macOS and commit it:

```bash
# ~40 KB, 1s, 320x240 — small enough to commit
ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=15 \
       -f lavfi -i sine=frequency=440:duration=1 \
       -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
       test/fixtures/sample_1s.mp4
```
(If ffmpeg is unavailable locally, record any ~1s clip and downscale it. Register `test/fixtures/` under `flutter: assets:` is NOT needed — the test reads it by relative path from the project root, which integration_test on desktop resolves.)

- [ ] **Step 3: Run on macOS**

Run: `flutter test integration_test/darwin_transcode_test.dart -d macos 2>&1 | tail -20`
Expected: PASS (builds + runs the macOS app; real AVFoundation transcode). This is the authoritative runtime verification; it does NOT run under plain `flutter test`.

- [ ] **Step 4: Commit**

```bash
git add integration_test/darwin_transcode_test.dart test/fixtures/sample_1s.mp4
git commit -m "test(transcoder): macOS AVFoundation integration test"
```

---

### Task 6: Full gates

- [ ] **Step 1: Format + analyze (app + package)**

Run:
```bash
dart format .
flutter analyze
dart analyze packages/submersion_transcoder
```
Expected: clean.

- [ ] **Step 2: Dart suites (no native)**

Run: `flutter test test/features/media_store/ test/features/media/data/`
Expected: PASS (the Dart engine + all Phase A/B1 tests; no native invoked).

- [ ] **Step 3: macOS build (Swift compile) + integration test**

Run:
```bash
flutter build macos --debug 2>&1 | tail -5
flutter test integration_test/darwin_transcode_test.dart -d macos 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED; integration test PASS.

- [ ] **Step 4: Full suite in the background, confirm exit 0 before pushing.**

Run: `flutter test`
Expected: All tests passed (native integration test does NOT run here — it lives under integration_test/, not test/).

- [ ] **Step 5: Commit any format fixups**

```bash
git add -A
git commit -m "chore: format + gate fixups for B2"
```

---

## Self-Review notes

- **Spec coverage:** §9 plugin/channel shape → Tasks 1–3 (sharedDarwinSource, MethodChannel+EventChannel exactly as the channel contract); §10 darwin (AVAssetReader/Writer, VideoToolbox H.264, `AVVideoAverageBitRateKey`, faststart, scale-to-maxHeight, rotation) → Task 3; the "probe via AVAsset, not ffprobe" note → Task 3 `AvfTranscoder.probe`; §15 delivery order (darwin after Linux) → this whole plan. Android/Windows explicitly out of scope.
- **Type consistency:** `DarwinAvfEngine` implements the exact `TranscodeEngine` signature from B1 (`transcode({required output, onProgress})`, `probe`, `isAvailable`); the channel contract's arg names match on both Dart and Swift sides; `engineForThisPlatform` returns the same `TranscodeEngine` supertype.
- **Verification honesty:** every native step's gate is a `flutter build macos` or an `integration_test -d macos`, never plain `flutter test`. The Dart-only tests (Tasks 2, 4) are the coverage-bearing ones.
- **Known risks flagged in-plan:** stale-Pods after Task 1 (fix documented); the integration test needs a committed fixture (Task 5 Step 2) because Dart can't synthesize H.264 without ffmpeg; iOS is covered by the shared Swift but only compile/runtime-verified on macOS here (a device/simulator run is a manual follow-up).
