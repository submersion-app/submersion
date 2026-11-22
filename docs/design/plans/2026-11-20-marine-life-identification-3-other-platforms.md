# Marine life identification, piece 3: Android, Windows and Linux Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the species pack's detectors and classifier on Android, Windows and Linux through ONNX Runtime, proven against Core ML, with Windows GPUs used through Windows ML.

**Architecture:** One Dart pipeline (resize, read boxes, merge, crop, fit) runs in a worker isolate and calls ONNX Runtime's C API through FFI; only video frame reading is native (Kotlin on Android, C++ on Windows). ONNX Runtime arrives as a build hook code asset from `packages/submersion_vision`; on Windows it comes from Windows ML's package, which also registers GPU and NPU engines. The pack gains `<stem>.onnx.zip` files beside the Core ML ones, and the species-pack scorer measures the shipped Dart code on a Mac.

**Tech Stack:** Flutter 3.47, Dart FFI, `hooks` and `code_assets` (already locked through `sqlite3`), `ffigen` (new dev dependency), ONNX Runtime C API (version pinned to what Windows ML ships, 1.24 at writing), Windows ML (`Microsoft.Windows.AI.MachineLearning`), Kotlin (`MediaCodec`, `MediaMetadataRetriever`), C++ (Media Foundation), Python 3.14 in submersion-app/species-pack (`onnx`, `onnxruntime`, `onnxconverter-common`).

**Spec:** [docs/design/specs/2026-11-19-marine-life-identification-3-other-platforms-design.md](../specs/2026-11-19-marine-life-identification-3-other-platforms-design.md). Read it before any task. Section numbers below ("spec 2a") are the spec's.

## Global Constraints

- Platforms: Android minSdk 26 with the feature on arm64-v8a and x86_64 only; Windows 10 (1903) and later, x64, vendor engines on Windows 11 24H2 and later; Linux x64, built on Ubuntu 24.04.
- The web build must compile. Nothing the web build reaches may import `dart:ffi` or the worker isolate; the ONNX engine is reached through a conditional import (Task B16).
- Engine name `onnx`; model files `<stem>.onnx.zip`, each holding `model.onnx` at its top; no manifest format change.
- Photo decode: longer side capped at 4096, EXIF orientation applied. Video pass 1 frames: longer side at most 960. Pass 2 frames: capped at 4096.
- Detector and crop rules are the Swift pipeline's (`VisionPipeline.swift`): RF-DETR straight resize, sigmoid of the best logit, threshold, best first, `maxBoxes`; YOLO letterbox with grey 114, suppression at 0.7 overlap; two detectors merged as `merge(runs, iou: mergeIoU, limit: maxBoxes)`; crops padded by `cropPadding`, clamped, integral (floor the origin, ceil the far edge), skipped under 2 by 2 pixels; tensors `[1, 3, size, size]` float32, R G B planes, `(v / 255 - mean[c]) / std[c]`; thumbnail fitted within `cropThumbnailSize`, JPEG quality 0.85.
- Memory floors: PCs need 6,979,321,856 bytes (6.5 GiB) reported; Android starts at the same value and moves to the 6 GB cut-off only if the Pixel 6a passes (Task D2).
- Defines: `MARINE_LIFE_ID_ONNX` (default false until Task D5) turns the three platforms on; `MARINE_LIFE_ID_IGNORE_FLOOR` (default false) lifts the floor for the measurement build only; `MARINE_LIFE_ID=false` still turns everything off.
- Gate: paired McNemar test at alpha 0.05 (`bars.mcnemar_p`); junk within `JUNK_LIMIT` 0.02; x64 comparison on 100 held-out photos, every crop's embedding cosine 0.999 or more, at least 99 in 100 crops with the same top name and suggestion outcome. Every pack passes it before publishing.
- Publishing anything to submersion-app/species-pack needs the maintainer's go, every time.
- Every new string goes into all 11 `lib/l10n/arb/app_*.arb` files, then `flutter gen-l10n`.
- Tests first. Run only the test files written or changed, by path; never a folder or the whole suite.
- A test that changes process-wide state (`marineLifeIdEnabled`, `debugDefaultTargetPlatformOverride`, a mock channel handler) puts it back in `tearDown` or `addTearDown`.
- Paths built with `p.join`; temporary space through `Directory.systemTemp`.
- `dart format .` before every commit. No em-dashes or en-dashes as punctuation anywhere. No commit, PR or GitHub text mentions Claude, Claude Code or Anthropic.
- Every pull request description carries `Refs #<piece 3 issue>` (Task A0).

## Review Focus

1. **A portrait phone photo with EXIF orientation 6** must give boxes on the fish as the viewer shows them. Pinned in Task B8 (`applies EXIF orientation`).
2. **The app leaving the foreground mid-chunk on Android** must end the pass with `not_foreground` and return no partial chunk. Pinned in Task B13 (`a chunk cut short is never returned`).
3. **A photo opened while a video chunk is running** must not run two sessions at once in the worker. Pinned in Task B9 (`calls are served one at a time`).
4. **A very large or very wide image** (8000 by 2000) must decode with its longer side at 4096. Pinned in Task B8 (`caps the longer side at 4096`).
5. **A Windows GPU engine failing on its first run** must fall back to DirectML, then the processor, without failing the photo. Pinned in Task B14 (`a run failing on the GPU moves to DirectML`).

---

## Part A: before the engine (this repository)

### Task A0: The piece 3 issue

- [ ] **Step 1:** Ask the maintainer for the go to open the issue. Do not open it without that go.
- [ ] **Step 2:** Open it with `gh issue create`, titled "Marine life identification on Android, Windows and Linux", body linking the spec and listing the four pull requests of this plan. `gh issue create` leaves the issue's type empty, so set it over the REST API afterwards. Record its number for every `Refs` line below.

### Task A1: Adoption ignores other engines' files

Its own small pull request, merged before the release that first turns the feature on (spec 4).

**Files:**
- Modify: `lib/features/species_id/domain/entities/species_pack_manifest.dart` (`adoptableFrom`, `_withoutAdoptable`, around lines 553 to 565)
- Modify: `lib/features/species_id/presentation/providers/species_pack_controller.dart:152`
- Test: `test/features/species_id/domain/species_pack_manifest_test.dart` (group `'a republished manifest is adoptable'`, line 783)
- Test: `test/features/species_id/presentation/species_pack_controller_test.dart` (group at line 381)

**Interfaces:**
- Produces: `bool adoptableFrom(SpeciesPackManifest published, {required String engine})`

- [ ] **Step 1: Write the failing tests**

In the manifest test group, beside `'only when nothing else changes'`:

```dart
test('when it only adds another engine\'s files', () {
  final published = installed.copyWith(files: [
    ...installed.files,
    const PackFile(name: 'classifier.onnx.zip', engine: 'onnx', size: 1, sha256: 'ab'),
  ]);
  expect(installed.adoptableFrom(published, engine: 'coreml'), isTrue);
});

test('not when it changes a file of this engine', () {
  final changed = [for (final f in installed.files)
    f.engine == 'coreml' ? f.copyWith(sha256: 'ff') : f];
  expect(installed.adoptableFrom(installed.copyWith(files: changed), engine: 'coreml'), isFalse);
});
```

Update the existing calls in the group to pass `engine: 'coreml'`. In the controller group, add `'a republish that adds another engine\'s files is taken in place'`: installed pack has Core ML files, the published manifest adds an `onnx` file under the same version; expect `PackInstalled`, `updateBytes` null, and no download.

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/features/species_id/domain/species_pack_manifest_test.dart test/features/species_id/presentation/species_pack_controller_test.dart`
Expected: FAIL (no `engine` parameter).

- [ ] **Step 3: Implement**

`_withoutAdoptable` takes the engine and also replaces `files` with `filesFor(engine)`; `adoptableFrom` compares those. The controller passes `engine: engineName`.

- [ ] **Step 4: Run them and see them pass** (same command). Expected: PASS.
- [ ] **Step 5: Commit** `fix(species-id): take a republished pack in place when only another engine's files change`

---

## Part B: the engine (this repository, one pull request)

### Task B1: Windows ML spike (throwaway)

Proves Windows ML's catalogue works from the app as packaged today, an unpackaged Win32 app (spec 2a, risk "Windows ML in an unpackaged app"). Nothing from it is kept but the findings.

**Files:**
- Create: `docs/design/findings/2026-11-20-windows-ml-unpackaged.md`

- [ ] **Step 1:** On a Windows PC, in a scratch Flutter app (not this repository), load `onnxruntime.dll` and `Microsoft.Windows.AI.MachineLearning.dll` from the `Microsoft.Windows.AI.MachineLearning` NuGet package beside the executable, and from Dart FFI: create an ONNX Runtime environment, list providers through `WinMLEpCatalog.h`, call `WinMLEpEnsureReady` on one, get its library path, `RegisterExecutionProviderLibrary` it, and run a one-layer model with the GPU preferred.
- [ ] **Step 2:** Record in the findings: whether it works with no Windows App SDK bootstrap, with the bootstrapper, or only self-contained; the files and their sizes the installer must carry; whether the catalogue works on Windows 10 (DirectML and the processor only); the ONNX Runtime version shipped.
- [ ] **Step 3:** If the catalogue cannot be made to work unpackaged, stop and ask the maintainer whether to fall back to DirectML through plain ONNX Runtime (spec, call 17). Do not start Task B14 until answered.
- [ ] **Step 4: Commit** the findings: `docs(species-id): Windows ML from an unpackaged app`

### Task B2: Platform gating and defines

**Files:**
- Modify: `lib/core/constants/feature_flags.dart`
- Modify: `lib/features/species_id/data/engines/channel_vision_engine.dart:23` (`_apple`)
- Test: `test/core/constants/marine_life_flag_test.dart`

**Interfaces:**
- Produces:
  - `bool visionEngineRuns(TargetPlatform platform, {bool web = kIsWeb, bool onnx = marineLifeOnnxPlatforms})`: iOS and macOS always; Android, Windows, Linux only when `onnx`.
  - `bool coreMlRuns(TargetPlatform platform, {bool web = kIsWeb})`: iOS and macOS, never web.
  - `bool visionVideoRuns(TargetPlatform platform, {bool web = kIsWeb})`: iOS, macOS, Android, Windows.
  - `const bool marineLifeOnnxPlatforms = bool.fromEnvironment('MARINE_LIFE_ID_ONNX');`
  - `const bool marineLifeIgnoreFloor = bool.fromEnvironment('MARINE_LIFE_ID_IGNORE_FLOOR');`

- [ ] **Step 1: Write the failing tests**

```dart
test('the ONNX platforms run only with the define', () {
  for (final p in [TargetPlatform.android, TargetPlatform.windows, TargetPlatform.linux]) {
    expect(visionEngineRuns(p, web: false, onnx: false), isFalse);
    expect(visionEngineRuns(p, web: false, onnx: true), isTrue);
  }
  expect(visionEngineRuns(TargetPlatform.android, web: true, onnx: true), isFalse);
});
test('Core ML runs on Apple platforms only', () {
  expect(coreMlRuns(TargetPlatform.macOS, web: false), isTrue);
  expect(coreMlRuns(TargetPlatform.android, web: false), isFalse);
  expect(coreMlRuns(TargetPlatform.macOS, web: true), isFalse);
});
test('video runs everywhere but Linux and the web', () {
  expect(visionVideoRuns(TargetPlatform.linux, web: false), isFalse);
  expect(visionVideoRuns(TargetPlatform.windows, web: false), isTrue);
  expect(visionVideoRuns(TargetPlatform.android, web: true), isFalse);
});
```

- [ ] **Step 2: Run** `flutter test test/core/constants/marine_life_flag_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the functions and constants above; `ChannelVisionEngine._apple` uses `coreMlRuns`. Update the doc comment of `marineLifeIdEnabled` to name the new define.
- [ ] **Step 4: Run** the same test plus `flutter test test/features/species_id/data/channel_vision_engine_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): gate the ONNX platforms behind MARINE_LIFE_ID_ONNX`

### Task B3: Reading detector outputs and merging (pure Dart)

**Files:**
- Create: `lib/features/species_id/data/engines/onnx/pipeline/detector_reading.dart`
- Test: `test/features/species_id/data/onnx/detector_reading_test.dart`
- Test: `test/features/species_id/data/onnx/merge_cases_test.dart`

**Interfaces:**
- Produces:
  - `class PipelineBox { const PipelineBox(this.x, this.y, this.w, this.h, this.score); final double x, y, w, h, score; }` with `==` and `hashCode` over all five, normalised 0 to 1; `score` rounded through 32 bits (`Float32List`) as Swift's `Float`.
  - `typedef PixelRect = ({double left, double top, double width, double height});`
  - `PixelRect letterboxRect(int width, int height, int size)`
  - `List<PipelineBox> readRfdetr({required Float32List boxes, required Float32List logits, required int queries, required int classes, required double scoreThreshold, required int maxBoxes})`
  - `List<PipelineBox> readYolo({required Float32List output, required int channels, required int anchors, required PixelRect letterbox, required int imageWidth, required int imageHeight, required double scoreThreshold, required int maxBoxes})`
  - `List<PipelineBox> suppress(List<PipelineBox> boxes, {required double iou, required int limit})`
  - `List<PipelineBox> mergeRuns(List<List<PipelineBox>> runs, {required double iou, required int limit})`
  - `double overlap(PipelineBox a, PipelineBox b)`
  - `const double yoloSuppressIoU = 0.7; const int letterboxGrey = 114;`

- [ ] **Step 1: Write the failing tests**

`merge_cases_test.dart` mirrors every case of species-pack `vision_cli/merge_check.swift`, one `test` per `check(...)`, same names and values, with `merge(runs, limit: 8)` calling `mergeRuns(runs, iou: 0.5, limit: limit)`; for example:

```dart
test('equal scores keep the first detector\'s box', () {
  const a = PipelineBox(0.2, 0.2, 0.3, 0.3, 0.5), b = PipelineBox(0.21, 0.2, 0.3, 0.3, 0.5);
  expect(merge([[a], [b]]), [a]);
});
```

`detector_reading_test.dart`: build inputs in the test from known boxes (not hand-typed raw arrays):
- `letterboxRect(1920, 1080, 640)` equals `(left: 0, top: 140, width: 640, height: 360)`, and for (1080, 1920) the transposed one (computed as Swift does, with the `- 0.1` before rounding).
- `readRfdetr` with three queries whose logits are `ln(p / (1 - p))` for p = 0.9, 0.2, 0.5 and threshold 0.3 returns two boxes, best first, scores 0.9 and 0.5; a box running past the edge is clamped to 0..1; a box with zero area after clamping is dropped; `maxBoxes: 1` keeps one.
- `readYolo` places a box built in letterbox pixels back at its image-normalised place (to 1e-9), drops scores under the threshold, and suppresses a second box overlapping the first by 0.8.
- `overlap` of identical boxes is 1, of disjoint boxes 0, of two empty boxes 0.

- [ ] **Step 2: Run** `flutter test test/features/species_id/data/onnx/detector_reading_test.dart test/features/species_id/data/onnx/merge_cases_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** as ports of `VisionPipeline.swift` `detect`, `detectYolo`, `letterboxRect`, `suppress`, `merge` and `overlap` (stable order for equal scores, as `merge` documents). No Flutter import.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): read detector outputs and merge boxes in Dart`

### Task B4: Pixels (pure Dart)

**Files:**
- Create: `lib/features/species_id/data/engines/onnx/pipeline/pixels.dart`
- Test: `test/features/species_id/data/onnx/pixels_test.dart`

**Interfaces:**
- Consumes: `PixelRect` (B3), `CropFit` (`species_pack_manifest.dart`).
- Produces:
  - `class RgbaImage { const RgbaImage(this.width, this.height, this.bytes); final int width, height; final Uint8List bytes; }` (4 bytes a pixel, top-left origin)
  - `RgbaImage drawInto(RgbaImage source, PixelRect target, {required int canvas, List<double>? fill})`: the source resampled into `target` of a `canvas`-square; `fill` (0 to 1 RGB) elsewhere, else zero.
  - `Float32List toTensor(RgbaImage square, {required List<double> mean, required List<double> std})`
  - `PixelRect fitRect(int width, int height, int size, CropFit fit)`
  - `typedef CropRect = ({int x, int y, int width, int height});`
  - `CropRect? paddedCrop({required int imageWidth, required int imageHeight, required double x, required double y, required double w, required double h, required double padding})`
  - `RgbaImage cropOf(RgbaImage image, CropRect rect)`
  - `RgbaImage fittedWithin(RgbaImage image, int side)`
  - `Uint8List jpegOf(RgbaImage image)` (quality 85, `package:image`)

- [ ] **Step 1: Write the failing tests**
  - `toTensor` of a 2 by 2 image puts R, G and B in three planes of 4, `(v / 255 - mean) / std` to 1e-6, shape length 12.
  - `fitRect(400, 200, 224, CropFit.padSquare)` is `(left: 0, top: 56, width: 224, height: 112)`; `centreCrop` is `(left: -112, top: 0, width: 448, height: 224)`.
  - `paddedCrop(1000, 500, x: 0.1, y: 0.1, w: 0.2, h: 0.2, padding: 0.1)` is `(x: 80, y: 40, width: 240, height: 120)`; a box at the edge is clamped; a box under 2 pixels gives null.
  - `drawInto` with `fill: [1, 0, 0]` leaves the outside of `target` pure red and the inside the source's colour (a uniform source, so any filter agrees).
  - `fittedWithin(RgbaImage(1000, 500, ...), 320)` is 320 by 160; one already smaller is returned unchanged.
  - `jpegOf` output starts with `0xFF, 0xD8`.
- [ ] **Step 2: Run** `flutter test test/features/species_id/data/onnx/pixels_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** The resampling filter is the implementer's (spec, left to the builder); use an area average when shrinking by more than two and bilinear otherwise, and keep it in one function so the gate can judge one choice.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): pixel steps of the ONNX pipeline`

### Task B5: The pipeline over model runners (pure Dart)

**Files:**
- Create: `lib/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart`
- Test: `test/features/species_id/data/onnx/onnx_pipeline_test.dart`

**Interfaces:**
- Consumes: B3, B4; `VisionModels`, `VisionDetection`, `VisionAnalysis`, `VisionMomentCrop`, `IdentificationBox`, `VisionEngineException`.
- Produces:
  - `class ModelOutput { const ModelOutput(this.shape, this.data); final List<int> shape; final Float32List data; }`
  - `abstract interface class ModelRunner { List<ModelOutput> run(Float32List input, List<int> shape); }`
  - `class PipelineResult { final VisionAnalysis analysis; final List<List<PipelineBox>> detectorBoxes; final List<PipelineBox> mergedBoxes; final double detectMs; final List<double> embedMs; }` (`embedMs` has one entry per detection, in order)
  - `class OnnxPipeline { OnnxPipeline({required VisionModels models, required List<ModelRunner> detectors, required ModelRunner classifier}); PipelineResult analyze(RgbaImage image); List<PipelineBox> detectFrame(RgbaImage frame); VisionMomentCrop? cropAndEmbed(RgbaImage image, IdentificationBox box); }`

- [ ] **Step 1: Write the failing tests** with fake runners that record their inputs and return prepared outputs:
  - RF-DETR runner given an RGBA image receives a tensor of shape `[1, 3, inputSize, inputSize]`; its outputs `[1, Q, 4]` and `[1, Q, C]` become boxes as in B3.
  - Two detectors: the result's boxes equal `mergeRuns` of each runner's boxes; `detectorBoxes` and `mergedBoxes` are filled.
  - The classifier runner receives `[1, 3, 224, 224]`; a returned embedding of the wrong length throws `VisionEngineException` with code `inference_failed`.
  - A detection's `pixelWidth` and `pixelHeight` are the unpadded box in image pixels, rounded; its `cropJpeg` is a JPEG no larger than `cropThumbnailSize` on its longer side.
  - A box whose padded crop is under 2 pixels is left out, as in Swift.
  - `cropAndEmbed` for a moment returns the same fields as a photo detection.
- [ ] **Step 2: Run** `flutter test test/features/species_id/data/onnx/onnx_pipeline_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** as a port of `analyze`, `detectBoxes`, `cropAndEmbed` and `embed` in `VisionPipeline.swift`. RF-DETR's box output is the rank-3 output whose last dimension is 4; YOLO's is the rank-3 output. No Flutter or FFI import.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): the ONNX pipeline, run over any model runner`

### Task B6: ONNX Runtime bindings and sessions (package)

**Files:**
- Create: `packages/submersion_vision/third_party/onnxruntime/onnxruntime_c_api.h` (from the pinned release, with its MIT licence beside it)
- Create: `packages/submersion_vision/ffigen_ort.yaml`
- Create: `packages/submersion_vision/lib/src/ort/ort_c_api.g.dart` (generated, checked in)
- Create: `packages/submersion_vision/lib/src/ort/ort_native.dart` (the asset-bound `OrtGetApiBase`)
- Create: `packages/submersion_vision/lib/src/ort/ort_runtime.dart`
- Create: `packages/submersion_vision/lib/onnx_runtime.dart` (exports the public types)
- Modify: `packages/submersion_vision/pubspec.yaml` (dev dependency `ffigen`; dependency `ffi`)
- Create: `packages/submersion_vision/test/fixtures/add_one.onnx` (one Add node: `y = x + 1`, float32 `[1, 3]`)
- Test: `packages/submersion_vision/test/ort_runtime_test.dart`

**Interfaces:**
- Produces (from `package:submersion_vision/onnx_runtime.dart`):
  - `enum OrtDevice { cpu, preferGpu, directMl }`
  - `class OrtSessionSettings { const OrtSessionSettings({this.intraOpThreads = 0, this.device = OrtDevice.cpu}); }`
  - `class OrtTensor { const OrtTensor(this.shape, this.data); final List<int> shape; final Float32List data; }`
  - `class OrtRuntime { factory OrtRuntime.open({String? libraryPath}); OrtModelSession openSession(String modelPath, {OrtSessionSettings settings}); void registerProviderLibrary(String name, String path); void close(); }`: the code asset when `libraryPath` is null, else that file.
  - `class OrtModelSession { List<OrtTensor> run(OrtTensor input); String get device; void close(); }`: runs the model's first input, returns every output in order.
  - `class OrtException implements Exception { const OrtException(this.message); final String message; }`

- [ ] **Step 1: Write the failing test**

```dart
final lib = Platform.environment['SUBMERSION_ORT_LIBRARY'];
final onLinux = Platform.isLinux;
test('runs a model through ONNX Runtime', () {
  final runtime = OrtRuntime.open(libraryPath: onLinux ? null : lib);
  addTearDown(runtime.close);
  final session = runtime.openSession(p.join('test', 'fixtures', 'add_one.onnx'));
  addTearDown(session.close);
  final out = session.run(OrtTensor([1, 3], Float32List.fromList([1, 2, 3])));
  expect(out.single.shape, [1, 3]);
  expect(out.single.data, [2, 3, 4]);
}, skip: !onLinux && lib == null ? 'no ONNX Runtime library on this machine' : false);
```

On Linux the test never skips: it loads the code asset.

plus `'a missing model file throws OrtException'`.

- [ ] **Step 2: Run** `cd packages/submersion_vision && flutter test test/ort_runtime_test.dart`. Expected: FAIL (no library yet).
- [ ] **Step 3: Implement.** Generate bindings with `dart run ffigen --config ffigen_ort.yaml`. Every call goes through the `OrtApi` table from `OrtGetApiBase()->GetApi(ORT_API_VERSION)`. Session options: `SetIntraOpNumThreads`, config entry `session.intra_op.allow_spinning = 0`; `preferGpu` sets the EP selection policy to prefer the GPU; `directMl` appends the `DML` provider. On Windows the model path is passed as UTF-16 (`ORTCHAR_T` is `wchar_t`). Free every `OrtStatus`, string and value.
- [ ] **Step 4: Run** the test (Linux after Task B7, Mac with `SUBMERSION_ORT_LIBRARY` set). Expected: PASS.
- [ ] **Step 5: Commit** `feat(vision): ONNX Runtime bindings and sessions`

### Task B7: The build hook and the native library checks

**Files:**
- Create: `packages/submersion_vision/hook/build.dart`
- Create: `packages/submersion_vision/lib/src/ort/ort_release.dart` (pinned versions, URLs, SHA-256 per target)
- Modify: `packages/submersion_vision/pubspec.yaml` (dependencies `hooks`, `code_assets` in the ranges `sqlite3` already locks)
- Modify: `scripts/check_native_libs_present.py` and its test (per-ABI requirements)
- Modify: `scripts/check_bundled_native_assets.py` and its test (also require the ONNX Runtime asset id)
- Modify: `.github/workflows/ci.yaml` (a step on the Linux test job, or a small job of its own, running `flutter test` in `packages/submersion_vision`, so Task B6's real ONNX Runtime test runs on every change to the package or the engine)
- Test: `packages/submersion_vision/test/ort_release_test.dart`

**Interfaces:**
- Produces: code assets with ids `package:submersion_vision/src/ort/ort_native.dart` (ONNX Runtime), and on Windows `package:submersion_vision/src/winml/winml_native.dart` (Windows ML's library) plus DirectML's DLL as a further asset.
- Produces (Python): `REQUIRED_LIBS_BY_ABI = {"arm64-v8a": ("libsqlcipher.so", "libonnxruntime.so"), "x86_64": ("libsqlcipher.so", "libonnxruntime.so"), "armeabi-v7a": ("libsqlcipher.so",)}`.

- [ ] **Step 1: Write the failing tests**
  - `ort_release_test.dart`: every target in the table (android arm64, android x64, linux x64, windows x64) has an `https` URL and a 64-hex SHA-256; macOS, iOS and 32-bit Android have none.
  - Python: an APK fixture missing `libonnxruntime.so` in arm64-v8a fails; one with it absent only from armeabi-v7a passes.
- [ ] **Step 2: Run** `cd packages/submersion_vision && flutter test test/ort_release_test.dart` and `python3.14 -I scripts/check_native_libs_present_test.py`. Expected: FAIL.
- [ ] **Step 3: Implement** the hook on `package:sqlite3`'s model: for the target OS and architecture, download the pinned archive into the hook's output directory once, check its SHA-256, extract the library (Android: `jni/<abi>/libonnxruntime.so` from the `onnxruntime-android` AAR; Linux: `lib/libonnxruntime.so*`; Windows: the DLLs from the Windows ML NuGet package, as Task B1's findings name them), and add each as a dynamic-loading-bundled code asset. Nothing for iOS, macOS or the web. Then the two scripts.
- [ ] **Step 4: Run** the tests again, then `flutter build linux` and `python3 scripts/check_bundled_native_assets.py build/linux/x64/release/bundle`, and `flutter build apk` and `python3 scripts/check_16kb_alignment.py build/app/outputs/flutter-apk/app-release.apk` plus `check_native_libs_present.py` on it. Expected: all pass; then Task B6's test passes on Linux with no path.
- [ ] **Step 5: Commit** `build(vision): ship ONNX Runtime through a build hook`

### Task B8: Decoding a photo with Flutter's decoder

**Files:**
- Create: `lib/features/species_id/data/engines/onnx/flutter_image_decoder.dart`
- Create: `test/features/species_id/data/onnx/fixtures/exif6.jpg` (40 by 20 pixels stored, orientation 6)
- Test: `test/features/species_id/data/onnx/flutter_image_decoder_test.dart`

**Interfaces:**
- Consumes: `RgbaImage` (B4).
- Produces: `Future<RgbaImage> decodeForAnalysis(Uint8List encoded, {int maxSide = 4096})`; throws `VisionEngineException('decode_failed', ...)`.

- [ ] **Step 1: Write the failing tests** (`testWidgets` with `tester.runAsync`):
  - `'applies EXIF orientation'`: `exif6.jpg` decodes as 20 wide by 40 high.
  - `'caps the longer side at 4096'`: a generated 8000 by 2000 PNG decodes as 4096 by 1024.
  - `'leaves a small image as it is'`: 300 by 200 stays 300 by 200.
  - `'unreadable bytes fail with decode_failed'`.
- [ ] **Step 2: Run** `flutter test test/features/species_id/data/onnx/flutter_image_decoder_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** with `ui.ImmutableBuffer.fromUint8List`, `ui.ImageDescriptor.encoded` for the size, `instantiateCodec(targetWidth:, targetHeight:)` scaled to the cap, then `toByteData(format: ui.ImageByteFormat.rawRgba)`. If orientation is not applied by Flutter on some platform, stop and report: the spec assumes it is.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): decode photos for the ONNX engine with Flutter's decoder`

### Task B9: The worker isolate and the photo path

**Files:**
- Create: `lib/features/species_id/data/engines/onnx/onnx_worker.dart`
- Create: `lib/features/species_id/data/engines/onnx/ort_model_runner.dart` (adapts `OrtModelSession` to `ModelRunner`)
- Create: `lib/features/species_id/data/engines/onnx/onnx_vision_engine.dart`
- Modify: `lib/features/species_id/domain/services/vision_engine.dart` (`static const String onnxEngine = 'onnx';`)
- Modify: `lib/features/species_id/data/pack/species_pack_store.dart` (`_model` prefers a `.onnx` file as it prefers `.mlmodelc`)
- Test: `test/features/species_id/data/onnx/onnx_vision_engine_test.dart`
- Test: `test/features/species_id/data/species_pack_store_test.dart` (one new test)

**Interfaces:**
- Consumes: B5, B6, B8.
- Produces:
  - `typedef ProviderLibrary = ({String name, String path});`
  - `abstract interface class OnnxWorkerHandle { Future<void> load(VisionModels models); Future<PipelineResult> analyze(RgbaImage image); Future<List<PipelineBox>> detect(RgbaImage frame); Future<VisionMomentCrop?> cropAndEmbed(RgbaImage frame, IdentificationBox box); Future<void> unload(); Future<void> close(); }`
  - `class OnnxWorker implements OnnxWorkerHandle { static Future<OnnxWorker> spawn({String? ortLibraryPath, List<OrtDevice> devices = const [OrtDevice.cpu], List<ProviderLibrary> providerLibraries = const []}); }`: the worker registers `providerLibraries` with its `OrtRuntime`, opens sessions on the first of `devices` that works, and moves to the next when a session fails to open or a run fails (Task B14 tests this); images cross as `TransferableTypedData`; `analyze` and friends throw `VisionEngineException(VisionEngineException.notLoaded)` when nothing is loaded.
  - `class OnnxVisionEngine implements VisionEngine { OnnxVisionEngine({TargetPlatform? platform, Future<OnnxWorkerHandle> Function()? worker, Future<RgbaImage> Function(Uint8List)? decode}); }`. Later tasks each add one named parameter: `deviceMemory` and `ignoreFloor` (B10), `frames` and `lifecycle` (B13), `hardware` (B14).

- [ ] **Step 1: Write the failing tests** with a fake worker handle:
  - `engineName` is `'onnx'`.
  - `analyze(path:)` reads the file, decodes, and returns the worker's `analysis`; `analyze(bytes:)` decodes the bytes; passing both or neither throws `ArgumentError`.
  - `'calls are served one at a time'`: two `analyze` calls started together reach the worker one after the other (the fake records overlapping calls and the test expects none).
  - `load` twice with equal models loads once; `unload` then `analyze` throws `not_loaded`.
  - `'memory pressure unloads the models'`: calling the engine's `didHaveMemoryPressure()` unloads; the next `analyze` throws `not_loaded`.
  - `excludeFromBackup` completes and touches nothing.
  - Store: `'an unpacked ONNX model is found'`: a folder holding `model.onnx` and `model.onnx.data` gives the `.onnx` path.
- [ ] **Step 2: Run** `flutter test test/features/species_id/data/onnx/onnx_vision_engine_test.dart test/features/species_id/data/species_pack_store_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** The engine queues calls to the worker (one in flight), registers as a `WidgetsBindingObserver` for memory pressure, and maps `OrtException` to `VisionEngineException('inference_failed', message)`. The worker owns `OrtRuntime` and the sessions and builds `OnnxPipeline` on load.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): the ONNX engine's photo path in a worker isolate`

### Task B10: Availability, floors and memory readings

**Files:**
- Create: `lib/features/species_id/data/engines/onnx/device_memory.dart`
- Modify: `lib/features/species_id/domain/entities/vision_memory.dart` (`final bool? lowMemory;`, in `copyWith` and `props`)
- Modify: `lib/features/species_id/data/services/memory_readout.dart` (`describeMemory` appends `, low memory` when `lowMemory == true`)
- Modify: `lib/features/species_id/data/engines/onnx/onnx_vision_engine.dart`
- Test: `test/features/species_id/data/onnx/device_memory_test.dart`
- Test: `test/features/species_id/data/onnx/onnx_vision_engine_test.dart`
- Test: `test/features/species_id/data/memory_readout_test.dart`, `test/features/species_id/domain/entity_copy_with_test.dart`

**Interfaces:**
- Produces:
  - `const int pcMinimumMemoryBytes = 6979321856;` and `const int androidMinimumMemoryBytes = 6979321856;` (Task D5 may lower the Android one)
  - `int? parseMemTotal(String procMeminfo)`, `int? parseMemAvailable(String procMeminfo)`, `({int? rss, int? hwm}) parseProcStatus(String procStatus)` (kB lines to bytes)
  - `abstract interface class DeviceMemory { Future<int?> totalBytes(); Future<VisionMemory> reading(); }` with `ProcDeviceMemory({Future<({bool lowMemory, int availableBytes})> Function()? systemState})` (Android and Linux; on Android, Task B11 passes the frames channel's `deviceState` as `systemState`, which fills `lowMemory` and `availableBytes`) and `WindowsDeviceMemory` (`GlobalMemoryStatusEx`, `GetProcessMemoryInfo` through FFI)
  - `OnnxVisionEngine` gains `DeviceMemory? deviceMemory` and `bool ignoreFloor = marineLifeIgnoreFloor`.

- [ ] **Step 1: Write the failing tests**
  - Parsers on real `/proc` text samples kept in the test.
  - Availability: `available` at exactly the floor; `deviceNotEligible` one byte under; `available` under the floor with `ignoreFloor: true`; `deviceNotEligible` for a 32-bit Android ABI; `unsupportedPlatform` when the library fails to open.
  - `memory()` maps `VmRSS` to `footprintBytes` and `VmHWM` to `footprintPeakBytes`; neural fields null.
  - `describeMemory` with `lowMemory: true` ends with `, low memory`.
- [ ] **Step 2: Run** the four test files by path. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** them again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): memory floors and readings for the ONNX engine`

### Task B11: Android frames and device state (Kotlin)

**Files:**
- Modify: `packages/submersion_vision/pubspec.yaml` (platform `android: package: app.submersion.vision, pluginClass: SubmersionVisionPlugin`)
- Create: `packages/submersion_vision/android/build.gradle.kts`, `android/src/main/AndroidManifest.xml`
- Create: `packages/submersion_vision/android/src/main/kotlin/app/submersion/vision/SubmersionVisionPlugin.kt`
- Create: `.../vision/SequentialFrames.kt` (pass 1: `MediaExtractor` and `MediaCodec`, in order)
- Create: `.../vision/ExactFrames.kt` (pass 2: `MediaMetadataRetriever`, `OPTION_CLOSEST`, as `FrameExtractor.kt` opens paths and `content://` URIs)
- Create: `.../vision/DeviceState.kt`
- Create: `lib/features/species_id/data/engines/onnx/frame_reader.dart`
- Test: `test/features/species_id/data/onnx/frame_reader_test.dart`

**Interfaces:**
- Produces: channel `submersion_vision/frames`, methods:
  - `open {path}` returns `{handle, width, height, durationMs}` (width and height as the player shows the video)
  - `next {handle, atOrAfterMs, maxSide}` returns `{ms, width, height, rgba}` for the first decoded frame at or after `atOrAfterMs`, rotated as shown, longer side at most `maxSide`; null at the end
  - `frameAt {handle, ms, maxSide}` returns `{width, height, rgba}` or null
  - `close {handle}`
  - `deviceState` returns `{thermalSevere: bool, lowMemory: bool, availableBytes: int}` (`thermalSevere` true at `THERMAL_STATUS_SEVERE` or above, false before API 29)
- Produces (Dart): `class VideoFrame { final int ms; final RgbaImage image; }`, `abstract interface class FrameReader { Future<({int handle, int width, int height, int durationMs})> open(String path); Future<VideoFrame?> next(int handle, {required int atOrAfterMs, required int maxSide}); Future<RgbaImage?> frameAt(int handle, int ms, {required int maxSide}); Future<void> close(int handle); Future<({bool thermalSevere, bool lowMemory, int availableBytes})> deviceState(); }`, `class ChannelFrameReader implements FrameReader`.

- [ ] **Step 1: Write the failing channel contract test**: each method sends the argument map above (a `content://` path passes through unchanged) and decodes the reply; a `PlatformException` becomes `VisionEngineException(code)`; the mock handler is restored in `tearDown`.
- [ ] **Step 2: Run** `flutter test test/features/species_id/data/onnx/frame_reader_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the Dart reader, then the Kotlin. Decoding runs off the main thread; one frame is held at a time; the RGBA bytes go back as a byte array. Rotation from `METADATA_KEY_VIDEO_ROTATION`. Pass the reader's `deviceState` to `ProcDeviceMemory` as `systemState` on Android (Task B10).
- [ ] **Step 4: Run** the test (PASS), then `flutter build apk --debug` (builds).
- [ ] **Step 5: Commit** `feat(vision): read video frames on Android for the ONNX engine`

### Task B12: Windows frames (C++)

**Files:**
- Modify: `packages/submersion_vision/pubspec.yaml` (platform `windows: pluginClass: SubmersionVisionPluginCApi`)
- Create: `packages/submersion_vision/windows/CMakeLists.txt`, `submersion_vision_plugin.{h,cpp}`, `submersion_vision_plugin_c_api.cpp`, `include/submersion_vision/submersion_vision_plugin_c_api.h`
- Create: `packages/submersion_vision/windows/frame_reader.{h,cpp}` (Media Foundation source reader with video processing on, RGB32 out, `MF_MT_VIDEO_ROTATION` applied)

**Interfaces:**
- Produces: the `submersion_vision/frames` channel of Task B11, the same methods and replies; `deviceState` returns `{thermalSevere: false, lowMemory: false, availableBytes: <GlobalMemoryStatusEx ullAvailPhys>}`.

- [ ] **Step 1:** The contract test of Task B11 already pins the replies; add `'Windows replies decode the same'` only if the C++ needs a reply shape the Kotlin does not.
- [ ] **Step 2: Implement** on the model of `packages/submersion_transcoder/windows/color_encoder.cpp`'s source reader. `next` reads forward; `frameAt` seeks and reads to the exact frame.
- [ ] **Step 3: Verify** `flutter build windows` on a Windows machine, then the hand check of Task D3.
- [ ] **Step 4: Commit** `feat(vision): read video frames on Windows for the ONNX engine`

### Task B13: Video in the ONNX engine

**Files:**
- Modify: `lib/features/species_id/data/engines/onnx/onnx_vision_engine.dart`
- Test: `test/features/species_id/data/onnx/onnx_vision_engine_video_test.dart`

**Interfaces:**
- Consumes: `FrameReader` (B11), `OnnxWorkerHandle.detect` and `cropAndEmbed` (B9), `visionVideoRuns` (B2).
- Produces: `detectVideo` and `embedMoments` per the `VisionEngine` contract; `OnnxVisionEngine` gains `FrameReader? frames` and `AppLifecycleState? Function()? lifecycle` (default `WidgetsBinding.instance.lifecycleState`).

- [ ] **Step 1: Write the failing tests** with a fake reader and worker:
  - Pass 1 samples as Swift does: frames at 0, 33, 66, ... ms with interval 250 give samples at 0, 250 (first frame at or after), 500 ...; `durationMs`, `width` and `height` come from `open`; the reader is asked for `maxSide: 960`.
  - `'a chunk cut short is never returned'`: the lifecycle turns paused after the second frame on Android; `detectVideo` throws `not_foreground`.
  - `thermalSevere` before the call throws `too_hot`; turning severe between frames throws `too_hot`.
  - On Windows neither check runs.
  - `embedMoments` asks `frameAt` with `maxSide: 4096`, returns null for an unreadable frame, and throws `decode_failed` when every moment is unreadable.
  - On Linux both calls throw `VisionEngineException('unsupported')`.
- [ ] **Step 2: Run** `flutter test test/features/species_id/data/onnx/onnx_vision_engine_video_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement**, closing the reader's handle in `finally`.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): video scanning in the ONNX engine`

### Task B14: Windows ML engines and the download step

Do not start until Task B1 has answered how Windows ML is reached.

**Files:**
- Create: `packages/submersion_vision/lib/src/winml/winml_native.dart` and generated `winml_catalog.g.dart` (from `WinMLEpCatalog.h`, vendored with its licence)
- Create: `lib/features/species_id/data/engines/onnx/hardware_engines.dart`
- Modify: `lib/features/species_id/domain/services/vision_engine.dart` (`HardwareEngineSource`)
- Modify: `lib/features/species_id/data/engines/onnx/onnx_vision_engine.dart`, `onnx_worker.dart`
- Modify: `lib/features/species_id/presentation/providers/species_pack_controller.dart` (`_prepare`, and the confirmation)
- Modify: `lib/features/species_id/presentation/pages/marine_life_identification_page.dart` (confirmation body)
- Modify: 11 `lib/l10n/arb/app_*.arb`: `settings_speciesId_downloadConfirmBodyHardware`: "This downloads {size} and keeps it on this device. Windows may also download an engine for your graphics card from Microsoft. You can remove the model at any time."
- Test: `test/features/species_id/data/onnx/hardware_engines_test.dart`, `test/features/species_id/presentation/species_pack_controller_test.dart`, `test/features/species_id/presentation/marine_life_identification_page_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class HardwareEngineSource { Future<bool> offersEngineToFetch(); Future<bool> fetchEngine(); }` (in `vision_engine.dart`; `OnnxVisionEngine` implements it, `FakeEngine` does not)
  - `abstract interface class HardwareEngines { Future<bool> offersEngineToFetch(); Future<bool> fetchEngine(); Future<List<ProviderLibrary>> readyProviderLibraries(); }` with `WindowsMlEngines` (the catalogue, from the main isolate) and `NoHardwareEngines`
  - `OnnxVisionEngine` gains `HardwareEngines? hardware`; on Windows it spawns the worker with `devices: [OrtDevice.hardware, OrtDevice.directMl, OrtDevice.cpu]` and `providerLibraries: await hardware.readyProviderLibraries()`, elsewhere with the processor only. *(Amended after B1: `OrtDevice.preferGpu` became `OrtDevice.hardware`, an explicit attach of the devices `chooseHardwareDevices` picks, never Windows' software renderer; the catalogue is declared by hand in `winml_native.dart` rather than generated from the package's header, which may not be redistributed.)*

- [ ] **Step 1: Write the failing tests**
  - A fake catalogue with one ready and one not-present provider: `readyProviderLibraries` lists only the ready one; `offersEngineToFetch` is true; `fetchEngine` makes it ready.
  - `'a session failing on the GPU opens on DirectML'` and `'a run failing on the GPU moves to DirectML'`: the worker reopens on the next device and the photo still returns its analysis; failing on DirectML too lands on the processor.
  - Controller: with an engine that is a `HardwareEngineSource` offering an engine, `_prepare` calls `fetchEngine` before `load`; a fetch returning false or throwing still ends in `PackInstalled`.
  - Page: the confirmation uses the hardware body when the engine offers one, the plain body otherwise.
- [ ] **Step 2: Run** the three test files by path. Expected: FAIL.
- [ ] **Step 3: Implement**, logging the device each session opened on (`OrtModelSession.device`) at info level so the debug log shows which engine ran; then add the string to the 11 arb files and run `flutter gen-l10n`.
- [ ] **Step 4: Run** them again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): Windows GPU and NPU engines through Windows ML`

### Task B15: Linux is photos only

**Files:**
- Modify: `lib/features/species_id/data/services/media_identification_service.dart` (`_process`, after line 451: a video when `!_videoRuns()` gives `RunItemOutcome.skipped`; constructor gains `bool Function() videoRuns`)
- Modify: `lib/features/species_id/presentation/providers/species_id_providers.dart` (passes `() => visionVideoRuns(defaultTargetPlatform)`)
- Modify: `lib/features/species_id/presentation/widgets/identification_trigger.dart:62` (`_applies` excludes videos when `!visionVideoRuns`)
- Modify: the settings page, the Photos and videos entry and the download prompt, to pick the photos-only strings when `!visionVideoRuns`
- Modify: 11 arb files, new keys: `settings_speciesId_entrySubtitlePhotos` "Find fish in your photos and suggest what they are"; `speciesId_downloadPrompt_titlePhotos` "Identify fish in your photos"; `settings_speciesId_introPhotos` "Finds fish in your photos and suggests what they are. Runs on this device. Your photos never leave it."; `settings_speciesId_togglePhotos` "Identify fish when I open a photo"
- Test: `test/features/species_id/data/media_identification_service_video_test.dart`, `test/features/species_id/data/dive_species_run_test.dart`, `test/features/species_id/presentation/identification_trigger_test.dart`, `test/features/species_id/presentation/marine_life_identification_page_test.dart`

- [ ] **Step 1: Write the failing tests**: with `videoRuns` false, a viewer video request ends `skipped` with no file resolved; a Find species run over two photos and a video counts two looked and no unreadable; the trigger starts nothing for a video; the page shows the four photos-only strings.
- [ ] **Step 2: Run** the four files by path. Expected: FAIL.
- [ ] **Step 3: Implement**, add the strings, `flutter gen-l10n`.
- [ ] **Step 4: Run** them again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): photos only on Linux, which has no video player`

### Task B16: Wiring, backup rules and licences

**Files:**
- Create: `lib/features/species_id/data/engines/platform_vision_engine.dart` (conditional export), `platform_vision_engine_io.dart`, `platform_vision_engine_web.dart`
- Modify: `lib/features/species_id/presentation/providers/species_id_providers.dart:42` (`visionEngineProvider` uses `createPlatformVisionEngine()`)
- Create: `android/app/src/main/res/xml/backup_rules.xml`, `android/app/src/main/res/xml/data_extraction_rules.xml`
- Modify: `android/app/src/main/AndroidManifest.xml:70` (`android:fullBackupContent="@xml/backup_rules"`, `android:dataExtractionRules="@xml/data_extraction_rules"`)
- Create: `lib/features/species_id/data/engines/onnx/onnx_runtime_attribution.dart`; modify `lib/core/bootstrap/bootstrap_shared.dart:32` to register it; add the licence texts under `assets/licenses/`
- Modify: `docs/developer/species-identification.md` (ONNX engine, defines, running the scoring runner)
- Test: `test/features/species_id/presentation/species_id_providers_test.dart:345`, `test/core/platform/android_backup_rules_test.dart`, `test/features/species_id/data/onnx/onnx_runtime_attribution_test.dart`

**Interfaces:**
- Produces: `VisionEngine createPlatformVisionEngine()`: `ChannelVisionEngine` where `coreMlRuns`, else `OnnxVisionEngine`; the web file returns `ChannelVisionEngine()`, which reports `unsupportedPlatform`.

- [ ] **Step 1: Write the failing tests**
  - Providers: with `debugDefaultTargetPlatformOverride` set to Android (reset to null in `tearDown`), `visionEngineProvider` is an `OnnxVisionEngine`; on macOS a `ChannelVisionEngine`.
  - Backup rules: both XML files exclude exactly `species_id/pack/` in the `file` domain (cloud backup and device transfer in the extraction rules) and include nothing; the manifest names both.
  - Attribution: the licence registry yields an entry for ONNX Runtime.
- [ ] **Step 2: Run** the three files by path. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** them again (PASS), then `flutter build web` (compiles).
- [ ] **Step 5: Commit** `feat(species-id): pick the engine per platform, keep the pack out of Android backups`

### Task B17: The scoring runner

**Files:**
- Create: `tool/species_vision_onnx/species_vision_onnx_test.dart`
- Create: `lib/features/species_id/data/engines/onnx/scoring_line.dart` (pure: one result to `vision_cli`'s JSON line)
- Test: `test/features/species_id/data/onnx/scoring_line_test.dart`

**Interfaces:**
- Consumes: `OnnxPipeline` via `OnnxWorker` (with `ortLibraryPath`), `decodeForAnalysis`.
- Produces: a runner started as `SPECIES_VISION_REQUEST=<request.json> flutter test tool/species_vision_onnx/species_vision_onnx_test.dart`, where the request is `{manifest, detectors: [paths], classifier, cropFit, detectorBoxes: bool, photos: [paths], out: <jsonl path>, ortLibrary: <path>}`. It writes one line per photo in `vision_cli/main.swift`'s format: `{path, width, height, detections: [{x, y, w, h, score, pixelWidth, pixelHeight, embedding, embedMs}], detectMs, detectorBoxes?, mergedBoxes?}` or `{path, error}`; an embedding with a non-finite value is an error line. With no request it skips.

- [ ] **Step 1: Write the failing test** for `scoringLine`: field names and order as `main.swift`, `w` and `h` (not `width`), embedding as plain numbers, the error line for NaN.
- [ ] **Step 2: Run** `flutter test test/features/species_id/data/onnx/scoring_line_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** `scoringLine`, then the runner.
- [ ] **Step 4: Run** the test (PASS), then the runner on three photos with a locally built pack and `ortLibrary` set; check three lines come out.
- [ ] **Step 5: Commit** `feat(species-id): a scoring runner for the ONNX engine`

### Task B18: Open the engine pull request

- [ ] **Step 1:** `dart format .`, then push the branch (the pre-push hook runs the checks).
- [ ] **Step 2:** Open the pull request with `Refs #<piece 3 issue>`, with screenshots attached through the project's secret gist (after only, light and dark, phone and desktop widths): the Android settings page (not downloaded, downloading, installed), a photo's suggestions on Android and Windows, a labelled video on Android and Windows, the Windows download confirmation, and the Linux settings page, all from a build with `MARINE_LIFE_ID_ONNX=true`.

---

## Part C: the pack (submersion-app/species-pack, one pull request)

### Task C1: ONNX conversions

**Files:**
- Modify: `models.py` (new `convert_detector_onnx`, `convert_classifier_onnx`, `zip_onnx`)
- Modify: `megalodon.py` (new `convert_onnx`)
- Modify: `manifest.py` (`model_in` also finds `.onnx`; `unpack_model` names the engine in its error)
- Modify: `requirements.txt` (pinned `onnx`, `onnxruntime`, `onnxconverter-common`)
- Test: `models_test.py` (new), `manifest_test.py`

**Interfaces:**
- Produces: `convert_detector_onnx(checkpoint, out_dir) -> str`, `convert_classifier_onnx(out_dir) -> str`, `megalodon.convert_onnx(name, work, check_image) -> str` (each a `model.onnx` path with 16-bit weights and float32 inputs and outputs), `zip_onnx(model_path, dest_zip)` (writes `model.onnx` at the zip's top).

- [ ] **Step 1: Write the failing tests**: `model_in` on a folder holding `model.onnx` returns it; `zip_onnx` puts `model.onnx` at the top; the torch-free parts run without torch, the rest skip without it, as the repository's tests already do.
- [ ] **Step 2: Run** `python3.14 -I manifest_test.py` and `python3.14 -I models_test.py`. Expected: FAIL.
- [ ] **Step 3: Implement.** Each conversion is checked as its Core ML twin is: the classifier's output cosine against the original 0.999 or more on the fixed input; the fish detector through `check_detector`'s comparison; Megalodon against `reference_boxes`. The operator set is one the pinned ONNX Runtime runs.
- [ ] **Step 4: Run** them again. Expected: PASS.
- [ ] **Step 5: Commit** `feat: convert the pack's models to ONNX`

### Task C2: Build both engines' files

**Files:**
- Modify: `build_pack.py` (`--engines`, default `coreml,onnx`; stale zips of both engines removed; ONNX entries with engine `onnx`)
- Test: `build_pack_test.py`

- [ ] **Step 1: Write the failing test**: with the converters stubbed, `main` writes a manifest listing `detector.coreml.zip`, `detector.onnx.zip`, `megalodon.coreml.zip`, `megalodon.onnx.zip`, `classifier.coreml.zip`, `classifier.onnx.zip` and the three shared files, each ONNX entry with engine `onnx`.
- [ ] **Step 2: Run** `python3.14 -I build_pack_test.py`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it again. Expected: PASS.
- [ ] **Step 5: Commit** `feat: build every pack with both engines' models`

### Task C3: Score the ONNX engine

**Files:**
- Create: `vision_onnx.sh` (fetches the pinned macOS ONNX Runtime library into `build/`, checks its SHA-256, writes the request and runs the app's runner from Task B17 in `SUBMERSION_APP`)
- Modify: `score.py` (`--engine coreml|onnx`, default `coreml`; `--pack-bars` evaluates at the manifest's own naming bars instead of choosing them; the run fingerprint includes the Dart pipeline sources under `lib/features/species_id/data/engines/onnx/` when the engine is `onnx`)
- Test: `score_test.py`

- [ ] **Step 1: Write the failing tests**: the fingerprint changes when a Dart pipeline file changes (ONNX) and not when Swift changes (ONNX), and the reverse for Core ML; `--pack-bars` reports the manifest's bars unchanged.
- [ ] **Step 2: Run** `python3.14 -I score_test.py`. Expected: FAIL.
- [ ] **Step 3: Implement**; the ONNX runner's lines are read exactly as `vision_cli`'s are, merge check included.
- [ ] **Step 4: Run** it again. Expected: PASS.
- [ ] **Step 5: Commit** `feat: score the app's ONNX engine`

### Task C4: The engine gate and the x64 comparison

**Files:**
- Create: `engine_gate.py`, `engine_gate_test.py`
- Create: `engine_compare.py`, `engine_compare_test.py`

**Interfaces:**
- Produces:
  - `engine_gate.check(coreml_per_photo, onnx_per_photo, onnx_eval, coreml_eval) -> dict` with `pass` and the four checks: `pack_bars_hold` (`held_out_gate` switches no bar off on the ONNX output at the pack's bars), `not_fewer_named_right` (fails when `bars.mcnemar_p` is under 0.05 and Core ML has more photos named right only by it), `no_group_worse` (the same per group), `junk` (ONNX junk named at most `JUNK_LIMIT` 0.02 and not significantly more often than Core ML). CLI: `engine_gate.py --coreml WORK --onnx WORK --pack PACK`, writes `engine_gate.json`, exits 1 on a fail.
  - `engine_compare.compare(reference_jsonl, other_jsonl, namer) -> dict`: per crop cosine (every one 0.999 or more) and the share with the same top name and suggestion outcome (at least 0.99). CLI over two runner outputs.

- [ ] **Step 1: Write the failing tests** on small built-in per-photo maps: equal results pass; ten more photos named right only by Core ML out of 400 fails `not_fewer_named_right`; junk at 0.021 fails; one crop at cosine 0.998 fails the comparison; 98 of 100 same outcomes fails.
- [ ] **Step 2: Run** `python3.14 -I engine_gate_test.py` and `python3.14 -I engine_compare_test.py`. Expected: FAIL.
- [ ] **Step 3: Implement**, reusing `bars.held_out_gate`, `bars.mcnemar_p` and `gate.py`'s per-group pairing.
- [ ] **Step 4: Run** them again. Expected: PASS.
- [ ] **Step 5: Commit** `feat: gate a pack's ONNX engine against Core ML`

### Task C5: The naming layer's gate covers ONNX

**Files:**
- Modify: `gate.py` (`--trained-onnx WORK`, required when the trained pack lists `onnx` files; the verdict includes `engine_gate.check` on the trained pack; `ship` needs it)
- Test: `gate_test.py`

- [ ] **Step 1: Write the failing tests**: a trained pack with ONNX files and no `--trained-onnx` stops with a message naming it; a failing engine check makes `ship` false; `confirm_same_base` passes for a baseline with ONNX files and a pack derived from it with `derive_manifest`.
- [ ] **Step 2: Run** `python3.14 -I gate_test.py`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it again. Expected: PASS. Add the new test files to the repository's CI test list.
- [ ] **Step 5: Commit** `feat: the naming layer's gate checks the ONNX engine too`, then open the pull request with `Refs submersion-app/submersion#<piece 3 issue>`.

---

## Part D: measure, publish and turn on

### Task D1: The gate run

- [ ] **Step 1:** Build the pack with both engines from the live pack's models (`build_pack.py`), or add ONNX files to a copy of the live pack's folder so its other files stay byte-identical; confirm with `shasum -a 256` that every Core ML and shared file matches the live release.
- [ ] **Step 2:** `score.py --pack PACK --engine coreml --pack-bars` and `score.py --pack PACK --engine onnx --pack-bars` (with `SUBMERSION_APP` on the engine branch), then `engine_gate.py`. Expected: exit 0. A failure is fixed in the engine (Task B4's filter, the precision of Task C1), never in the bars.
- [ ] **Step 3:** On a Linux x64 machine, run the scoring runner over 100 held-out photos and `engine_compare.py` against the Mac's ONNX output. Expected: pass.
- [ ] **Step 4:** Record both results in `docs/design/findings/2026-11-17-marine-life-measured-accuracy.md` under a new heading.

### Task D2: The Pixel 6a

- [ ] **Step 1:** Build with `--dart-define=MARINE_LIFE_ID_ONNX=true --dart-define=MARINE_LIFE_ID_IGNORE_FLOOR=true` and get it onto the maintainer's 6a as an update to the installed app (the beta track, or a build signed as the installed one is). Never uninstall.
- [ ] **Step 2:** With debug mode on and `adb logcat -b events` and `adb logcat | grep -i lowmemorykiller` captured: download the pack; open a 50 MP photo; open a 4K video and let it scan two chunks; then the same with a browser and the camera app open behind.
- [ ] **Step 3:** Passing means the app was never killed (no `am_kill` or `lowmemorykiller` line naming `app.submersion`, no restart) and no readout line says `low memory`. Record the readout lines, the times (model load, a photo, a chunk) and the verdict in a findings file.
- [ ] **Step 4:** If it passed, set `androidMinimumMemoryBytes` (Task B10) to a cut-off between what 4 GB phones report (under 4 GiB) and what 6 GB phones report (over 5 GiB; read the 6a's own `MemTotal`), for example 4.5 GiB, with the evidence in its comment and its test updated; if not, leave it at 6.5 GiB.

### Task D3: Windows and Linux by hand

Ran in CI on 2026-11-22 instead, on GitHub's hosted runners, since no
Windows or Linux PC was to hand; results in
[the Windows and Linux findings](../findings/2026-11-22-marine-life-windows-linux-ci.md).
The runners have no GPU, so step 1's GPU and Windows 10 checks, step 2
and step 3 are still unchecked.

- [ ] **Step 1:** Run spec section 7's checks on a Windows PC with a GPU (which engine ran, the vendor engine fetched in the Download, the fall back when the GPU engine is made to fail), on Windows 10 (DirectML and the processor), and on a Linux PC (photos only).
- [ ] **Step 2:** Where a Windows GPU PC was used, run the 100-photo comparison on it and record its agreement in the findings, for information.
- [ ] **Step 3 (added after B14's review):** on the Windows GPU PC, with debug mode on: download the pack, then quit and relaunch, and confirm from the log ("Marine life models open on hardware: ...") that the vendor engine is still the one that runs after the relaunch; confirm the engine list was read (Windows ML's `WinMLEpInfo` field order and its enumeration callback's thread have never run with an engine listed); confirm preparing an installed engine (`WinMLEpEnsureReady`) works on the worker's thread with no COM set up and downloads nothing, and that listing the engines makes no network request; on a PC with two vendor engines or two GPUs, note which one was chosen; confirm the engine's name in Windows ML's catalogue is the name its devices report to ONNX Runtime (the hardware session allows only catalogue names), and that Windows ML's catalogue takes two calls at once from different threads (an engine download while a worker lists the engines).

### Task D4: Publish (the maintainer's go)

- [ ] **Step 1:** Ask the maintainer for the go. Do nothing below without it.
- [ ] **Step 2:** Upload the ONNX zips to the live pack's release and replace its `manifest.json` with the one listing them, same pack version. Confirm an iPhone or Mac with the pack installed shows `Installed` with no update, and Android shows the download size.

### Task D5: Turn the platforms on

**Files:**
- Modify: `lib/core/constants/feature_flags.dart` (`MARINE_LIFE_ID_ONNX` `defaultValue: true`)
- Test: `test/core/constants/marine_life_flag_test.dart`

- [ ] **Step 1: Write the failing test**: `visionEngineRuns(TargetPlatform.android, web: false)` with the default define is true.
- [ ] **Step 2: Run** `flutter test test/core/constants/marine_life_flag_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement**, together with Task D2's floor if it changed.
- [ ] **Step 4: Run** it again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): turn marine life identification on for Android, Windows and Linux` and open the pull request with `Closes #<piece 3 issue>`.
