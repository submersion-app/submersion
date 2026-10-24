# Share Colour-Corrected Videos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sharing a video with a colour correction in effect sends a
re-encoded copy carrying that correction moment by moment, keeping codec
family, HDR, bit depth, audio and date/location.

**Architecture:** The app samples the composed 4x5 matrix through the clip
into a colour timeline (Dart, tested against `VideoColorFilter`'s maths).
`submersion_transcoder` gains a `ColorEncoder` (iOS, macOS, Android,
Windows) that applies the interpolated timeline to every decoded frame with
one shared colour formula (SDR, PQ, HLG), pinned by a Dart reference
implementation the native integration tests compare against. The share flow
prepares files behind a progress dialog with Cancel, and offers the
originals when a correction cannot be applied.

**Tech Stack:** Flutter, Riverpod 3, AVFoundation + Core Image/Metal,
AndroidX Media3 Transformer (GL effect), Media Foundation Source
Reader/Sink Writer, share_plus.

**Spec:** `docs/design/specs/2026-10-23-share-corrected-video-design.md`

## Global Constraints

- Nothing is written to the original file or any cached copy.
- Linux is out of scope (issue #3606): no Linux encoder; Linux Share unchanged.
- Output: codec matches source (HEVC to HEVC, Main 10 when 10-bit/HDR;
  H.264 to H.264; anything else to HEVC, Main 10 when 10-bit/HDR); MP4,
  HEVC tagged `hvc1`; same dimensions, orientation and frame rate; never
  shrunk or switched codec silently (Media3 encoder fallback off).
- HDR kept: primaries, transfer, matrix tags and HDR10 static metadata
  copied; HDR10+ and Dolby Vision dynamic metadata dropped.
- Audio kept (passthrough where possible); recording date and ISO 6709
  location kept when present.
- Temp copy at `<temp>/share/<item id>/<share filename stem>.mp4`.
- Engine contract: write `<output>.tmp`, rename on success, never leave a
  `.tmp`; cancelled is distinct from failed.
- New user-facing strings in all 11 ARB files; app English is US spelling
  ("color").
- No em dashes anywhere; no AI attribution in commits.
- `dart format .`, `flutter analyze`, affected tests, and
  `test/architecture/` + `test/shared/` before each commit that adds lib files.

## The colour formula (all engines and the Dart reference)

Input: a pixel's encoded R'G'B' in 0..1 (after YUV to RGB with the source's
matrix), the 20-value matrix `m` (row-major, rows R,G,B,A; cols r,g,b,a,
offset; offsets on the 0-255 scale), and the source transfer:

- **sdr:** `out_i = clamp01(m[5i]*r + m[5i+1]*g + m[5i+2]*b + m[5i+3] + m[5i+4]/255)`.
  This equals `ColorMatrix.applyToPixel` divided by 255.
- **pq / hlg:**
  1. Linear, relative to SDR white: PQ `L = pqEotf(E) / 203` (pqEotf in
     cd/m2, SMPTE ST 2084); HLG `L = hlgInverseOetf(E) / hlgInverseOetf(0.75)`
     (BT.2100 inverse OETF, scene light, no OOTF).
  2. BT.2020 to BT.709 primaries (standard 3x3), may go negative.
  3. Extended sRGB encode: `s(x) = sign(x) * (|x| <= 0.0031308 ? 12.92|x| : 1.055|x|^(1/2.4) - 0.055)`.
  4. Matrix as in sdr, without the clamp.
  5. Inverse of 3, BT.709 to BT.2020, inverse of 1, clamp to 0..1.

Timeline interpolation at presentation time `t` (ms, the player's position
at that frame; corrected during the build, see Task 8's ruling): before the first key, the first key;
after the last, the last; otherwise elementwise lerp of the two keys around
`t`.

## Review Focus

1. Portrait/rotated phone clips: copy keeps the rotation, not stretched or
   turned. (Tasks 8-10: rotated input asserted.)
2. Clips whose first sample is not at time 0 (iPhone edit lists): the
   timeline is read at presentation time, as the player's position reads
   it. (Task 8: input with a start offset.)
3. Clips with no duration or shorter than one step: one key, still shared
   corrected. (Task 4 tests.)
4. Encode failing part-way (disk full, codec error): failure dialog, no
   `.tmp` or partial copy left. (Task 6 test.)
5. Android Back during the progress dialog: acts as Cancel, never strands
   the encode or pops the page. (Task 7 test.)

---

### Task 1: Colour timeline types and reference formula (package)

**Files:**
- Create: `packages/submersion_transcoder/lib/src/color_timeline.dart`
- Create: `packages/submersion_transcoder/lib/src/color_math.dart`
- Modify: `packages/submersion_transcoder/lib/submersion_transcoder.dart` (exports)
- Test: `test/features/media_store/color_timeline_test.dart`, `test/features/media_store/color_math_test.dart`

**Interfaces:**
- Produces:
  - `class ColorTimelineKey { const ColorTimelineKey({required int timeMs, required List<double> matrix}); }` (matrix has 20 values; assert)
  - `class ColorTimeline { const ColorTimeline(List<ColorTimelineKey> keys); List<double> matrixAt(int timeMs); List<Object> toChannel(); }` (`toChannel` gives `[{'t': timeMs, 'm': matrix}, ...]` sorted by time)
  - `enum SignalTransfer { sdr, pq, hlg }`
  - `List<double> correctPixel(List<double> rgb, List<double> matrix, SignalTransfer transfer)` (rgb encoded 0..1, returns encoded 0..1)
  - helpers `double pqEotf(double e)`, `double pqInverseEotf(double nits)`, `double hlgInverseOetf(double e)`, `double hlgOetf(double l)`

- [ ] **Step 1: Write failing tests**

```dart
test('matrixAt interpolates and holds at the ends', () {
  final a = ColorTimelineKey(timeMs: 0, matrix: identity20);
  final b = ColorTimelineKey(timeMs: 1000, matrix: gains20(2, 1, 1));
  final t = ColorTimeline([b, a]);
  expect(t.matrixAt(-5)[0], 1);
  expect(t.matrixAt(500)[0], closeTo(1.5, 1e-9));
  expect(t.matrixAt(9999)[0], 2);
});
test('toChannel is time-sorted plain data', () {
  expect(ColorTimeline([b, a]).toChannel().first, {'t': 0, 'm': identity20});
});
test('sdr equals applyToPixel / 255', () {
  // gains(1.2, 1, 0.8) on mid grey plus brightness offset 25.5
  expect(correctPixel([0.5, 0.5, 0.5], gainsWithOffset20(1.2, 1, 0.8, 25.5), SignalTransfer.sdr),
      [closeTo(0.7, 1e-9), closeTo(0.6, 1e-9), closeTo(0.5, 1e-9)]);
});
test('sdr clamps', () => expect(correctPixel([1, 1, 1], gains20(2, 2, 2), SignalTransfer.sdr), [1, 1, 1]));
for (final tr in [SignalTransfer.pq, SignalTransfer.hlg]) {
  test('$tr identity round-trips', () {
    for (final c in [[0.1, 0.4, 0.7], [0.58, 0.58, 0.58], [0.9, 0.2, 0.05]]) {
      final out = correctPixel(c, identity20, tr);
      for (var i = 0; i < 3; i++) expect(out[i], closeTo(c[i], 1e-6));
    }
  });
}
test('pq reference white behaves like sdr white', () {
  final e = pqInverseEotf(203); // grey at SDR white
  final out = correctPixel([e, e, e], gains20(0.5, 0.5, 0.5), SignalTransfer.pq);
  // 0.5 in extended sRGB is linear 0.2140 of SDR white
  expect(pqEotf(out[0]) / 203, closeTo(0.21404, 1e-4));
});
test('pq highlight above white is not clipped by the matrix', () {
  final e = pqInverseEotf(1000);
  final out = correctPixel([e, e, e], gains20(1.1, 1, 1), SignalTransfer.pq);
  expect(pqEotf(out[0]), greaterThan(1000));
});
test('hlg inverse OETF at the 75% reference level', () =>
    expect(hlgInverseOetf(0.75), closeTo(0.26497, 1e-4)));
```

- [ ] **Step 2: Run, expect FAIL** `flutter test test/features/media_store/color_timeline_test.dart test/features/media_store/color_math_test.dart` (undefined names).
- [ ] **Step 3: Implement** both files per "The colour formula" above (BT.2020 to BT.709 matrix: `[1.6605, -0.5876, -0.0728; -0.1246, 1.1329, -0.0083; -0.0182, -0.1006, 1.1187]` and its inverse `[0.6274, 0.3293, 0.0433; 0.0691, 0.9195, 0.0114; 0.0164, 0.0880, 0.8956]`).
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): colour timeline and reference colour formula`

### Task 2: ColorEncoder API over the channel (package)

**Files:**
- Create: `packages/submersion_transcoder/lib/src/color_encoder.dart`
- Modify: `packages/submersion_transcoder/lib/src/channel_transcode_engine.dart` (implements `ColorEncoder`)
- Modify: `packages/submersion_transcoder/lib/src/engine_factory.dart`
- Test: `test/features/media_store/channel_color_encoder_test.dart`

**Interfaces:**
- Consumes: `ColorTimeline` (Task 1)
- Produces:
  - `class ColorEncodeCancel { void cancel(); bool get isCancelled; }` (listeners notified once)
  - `class TranscodeCancelledException implements Exception`
  - `class TranscodeUnsupportedException extends TranscodeException` (device cannot decode/encode this source at full size, or cannot keep HDR)
  - `abstract interface class ColorEncoder { Future<void> encodeWithColor({required File source, required File output, required ColorTimeline timeline, ColorEncodeCancel? cancel, void Function(double fraction)? onProgress}); }`
  - `ColorEncoder? colorEncoderForThisPlatform()` (ChannelTranscodeEngine on iOS, macOS, Android, Windows; null elsewhere, including Linux)
  - Channel: method `encodeWithColor` args `{source, output, timeline: timeline.toChannel(), progressId}`; method `cancelEncode` args `{progressId}`; native error codes `cancelled`, `unsupported`, `transcode_failed`.

- [ ] **Step 1: Write failing tests** (mock `submersion_transcoder/methods` as in `channel_transcode_engine_test.dart`):
  - `encodeWithColor sends source, output, timeline and a progressId`
  - `progress events with its progressId reach onProgress, clamped`
  - `cancel sends cancelEncode with the same progressId`
  - `error code cancelled throws TranscodeCancelledException`
  - `error code unsupported throws TranscodeUnsupportedException`
  - `other PlatformException throws TranscodeException`
  - `missing plugin throws TranscodeException`
  - `colorEncoderForThisPlatform is null on Linux` (guard with `Platform.isLinux`, else expect non-null)
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Reuse the shared progress stream and `_seq`.
- [ ] **Step 4: Run, expect PASS**, plus `test/features/media_store/channel_transcode_engine_test.dart`.
- [ ] **Step 5: Commit** `feat(media): colour encoder API in submersion_transcoder`

### Task 3: Generalise VideoFileAccess

**Files:**
- Modify: `lib/features/media/presentation/providers/video_color_track_provider.dart`
- Modify tests: `test/features/media/presentation/providers/video_file_access_test.dart`, `test/features/media/presentation/providers/video_color_track_provider_test.dart`

**Interfaces:**
- Produces: `typedef VideoFileAccess = Future<T?> Function<T>({String? path, String? bookmarkRef, required Future<T> Function(String path) read});` Same behaviour, any result type.

- [ ] **Step 1:** Add test `access returns a non-list result through the bookmark` to `video_file_access_test.dart` (read returns `'opened:$path'`).
- [ ] **Step 2:** Run, expect compile FAIL.
- [ ] **Step 3:** Make the typedef and provider closure generic; update the fakes.
- [ ] **Step 4:** Run both test files, expect PASS.
- [ ] **Step 5: Commit** `refactor(media): let video file access return any result`

### Task 4: Sample the colour timeline

**Files:**
- Create: `lib/features/media/domain/color/color_timeline_sampler.dart`
- Test: `test/features/media/domain/color/color_timeline_sampler_test.dart`

**Interfaces:**
- Consumes: `ColorMatrix`, `ColorTimeline`, `ColorTimelineKey`
- Produces: `ColorTimeline? sampleColorTimeline({required double? durationSeconds, required ColorMatrix Function(double seconds) matrixAt, double stepSeconds = 0.5})`. Keys at 0, step, 2*step, ... and at the duration. Null when every key is identity (share the original). One key at 0 when all keys are equal or duration is null/<= step.

- [ ] **Step 1: Write failing tests**
  - `identity everywhere gives null`
  - `constant matrix gives one key`
  - `null duration gives one key from matrixAt(0)`
  - `0.2 s clip gives one key`
  - `keys equal matrixAt at their times` (a real `VideoColorTrack` with 7 keys, `videoDepthLookup` over a descending profile, an adjustment with warmth 0.3; `matrixAt = composeCorrection(adjustment, auto: track.paramsAt(s, depthAt))`)
  - `interpolation stays within one level` (same setup; for t every 0.05 s, `ColorTimeline.matrixAt` vs `matrixAt(t)` applied by `applyToPixel` to (20,100,160), (128,128,128), (240,200,60): every channel differs by <= 1)
- [ ] **Step 2:** Run, expect FAIL.
- [ ] **Step 3:** Implement; convert seconds to whole ms.
- [ ] **Step 4:** Run, expect PASS. If the tolerance test fails, lower the default step until it passes and note the value.
- [ ] **Step 5: Commit** `feat(media): sample a video's colour correction into a timeline`

### Task 5: Work out a video's share timeline

**Files:**
- Create: `lib/features/media/presentation/helpers/video_share_timeline.dart`
- Test: `test/features/media/presentation/helpers/video_share_timeline_test.dart`

**Interfaces:**
- Consumes: Task 4; `effectiveAdjustment`-equivalent reads (`colorAdjustmentDraftNotifierProvider`, `item.colorAdjustment`), `diverAutoColorCorrectionProvider`, `isAutoCorrectable`, `needsStoredMatch`, `mediaColorAdjustmentRepositoryProvider.enrichmentFor`, `needsAutoStats`, `videoColorTrackProvider`, `videoDepthAtProvider`, `colorAnalysisServiceProvider`, `resolvedThumbnailProvider`, `autoParamsForPhoto`, `composeCorrection`.
- Produces:
  - `bool videoMayNeedCorrection(WidgetRef ref, MediaItem item)`: video, and an adjustment is set or the diver's auto applies (`autoEnabledFor`). Cheap; decides whether the progress dialog is used.
  - `Future<ColorTimeline?> videoShareTimelineFor(WidgetRef ref, MediaItem item, {required String? path})`: null means share the original.

Read autoDispose providers with `ref.listenManual(provider.future, (_, _) {})`, `await sub.read()`, `sub.close()` in `finally`, so they are not disposed mid-await.

- [ ] **Step 1: Write failing tests** (ProviderScope overrides; fake track/depth providers):
  - `photo gives null` ; `no adjustment and auto off gives null`
  - `sliders only gives one constant key equal to composeCorrection(adjustment)`
  - `auto with a track gives keys following the track and depth`
  - `the unsaved draft wins over the stored adjustment`
  - `a library row without enrichment reads the stored match first` (repository fake returns enrichment; depth used)
  - `auto with no track falls back to the poster: cached stats used when present`
  - `auto with no track and no cached stats analyses the poster thumbnail`
  - `surface clip with auto only gives null`
- [ ] **Step 2:** Run, expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, expect PASS.
- [ ] **Step 5: Commit** `feat(media): work out the colour timeline a shared video carries`

### Task 6: Prepare share files (orchestration)

**Files:**
- Modify: `lib/features/media/data/services/media_share_temp_file.dart` (add `Future<File> shareTempFileFor(MediaItem item, {required String filename})`: creates the folder, writes nothing)
- Create: `lib/features/media/presentation/helpers/share_preparation.dart`
- Test: `test/features/media/presentation/helpers/share_preparation_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 3, 5; `writeShareFileFor`, `resolvedFullResolutionProvider`, `resolvedFilePathProvider`, `videoFileAccessProvider`.
- Produces:
  - `final colorEncoderProvider = Provider<ColorEncoder?>((ref) => colorEncoderForThisPlatform());`
  - `class VideoShareProgress { final int index; final int total; final double? fraction; }` (index 1-based; fraction null before encoding starts)
  - `sealed class SharePreparation`; `ShareReady({required List<XFile> files, required List<MediaItem> failedVideos})`, `ShareCancelled()`, `ShareInterrupted()`
  - `Future<SharePreparation> prepareShareFiles(WidgetRef ref, List<MediaItem> items, {required void Function(VideoShareProgress) onProgress, required ColorEncodeCancel cancel, bool Function()? leftForeground})`
  - `Future<List<XFile>> originalShareFiles(WidgetRef ref, List<MediaItem> items)` (today's bytes path, for Share original)
  - Rules: items in order; a video with a non-null timeline is encoded to `shareTempFileFor(item, filename: p.setExtension(item.shareFilename, '.mp4'))` through `videoFileAccessProvider` (path from `resolvedFilePathProvider`, `item.bookmarkRef`), output `XFile` mime `video/mp4`; null timeline or photo goes through `writeShareFileFor`; no encoder, no reachable file, `TranscodeException` (incl. unsupported) add to `failedVideos` and continue. Cancel requested by the diver gives `ShareCancelled`; any failure or unrequested cancellation while `leftForeground()` returned true during that encode gives `ShareInterrupted`. Cancelled and interrupted delete every corrected copy this call wrote.
- [ ] **Step 1: Write failing tests** with a fake `ColorEncoder` (records calls, scripted outcomes, writes the output file on success):
  - `uncorrected items keep today's files and never call the encoder`
  - `a corrected video is encoded to share/<id>/<stem>.mp4 with its timeline`
  - `progress reports index of total and fraction`
  - `a failing video is listed and later items are still prepared`
  - `a failing encode leaves no partial or tmp file`
  - `no encoder on this platform lists the video as failed`
  - `cancel stops the encode, deletes written copies, returns ShareCancelled`
  - `failure after leaving the foreground returns ShareInterrupted`
- [ ] **Step 2:** Run, expect FAIL. **Step 3:** Implement. **Step 4:** Run, expect PASS.
- [ ] **Step 5: Commit** `feat(media): prepare corrected video copies for sharing`

### Task 7: Share dialogs and wiring

**Files:**
- Create: `lib/features/media/presentation/widgets/video_share_progress_dialog.dart`
- Create: `lib/features/media/presentation/widgets/video_correction_failed_dialog.dart`
- Modify: `lib/features/media/presentation/helpers/media_share_helper.dart`
- Modify: `lib/features/media/presentation/pages/site_media_viewer_page.dart` (`_shareCurrentItem` calls `shareMediaItems`)
- Modify: `lib/features/media/presentation/helpers/share_color_matrix.dart` (doc comment: videos now handled by share_preparation)
- Modify: all 11 `lib/l10n/arb/app_*.arb`, regenerate l10n
- Test: `test/features/media/presentation/helpers/media_share_helper_test.dart` (create or extend), `test/features/media/presentation/widgets/video_share_progress_dialog_test.dart`

**Interfaces:**
- Consumes: Task 6.
- Produces:
  - `VideoShareProgressDialog({required ValueListenable<VideoShareProgress> progress, required VoidCallback onCancel})`: title "Preparing video" or "Preparing video {current} of {total}", `LinearProgressIndicator` (indeterminate while fraction null), percentage text, Cancel button; `PopScope(canPop: false)` whose pop attempt calls `onCancel`.
  - `Future<bool> showVideoCorrectionFailedDialog(BuildContext context, {required int failedCount})`: true for Share original.
  - ARB keys (en): `media_share_preparingVideo` "Preparing video"; `media_share_preparingVideoOf` "Preparing video {current} of {total}"; `media_share_correctionFailedTitle` "Couldn't apply the color correction"; `media_share_correctionFailedBody` "{count, plural, =1{This video can still be shared without it.} other{{count} videos can still be shared without it.}}"; `media_share_shareOriginal` "Share original"; `media_share_videoInterrupted` "Preparing the video stopped when Submersion went into the background. Share again to start over." Cancel reuses `common_action_cancel`. Translate for the other 10 locales.
  - `shareMediaItems` shows the spinner as today unless some item satisfies `videoMayNeedCorrection`, in which case the progress dialog; tracks `AppLifecycleListener` for `leftForeground`; on `ShareReady` with failures shows the failed dialog, and Share original adds `originalShareFiles(failed)` to the files; Cancel there deletes the corrected copies and shares nothing; `ShareInterrupted` shows the interrupted snackbar; `ShareCancelled` shows nothing.
- [ ] **Step 1: Write failing widget tests:**
  - `photo-only share keeps the spinner`
  - `corrected video share shows Preparing video with percentage`
  - `two corrected videos show 2 of 2`
  - `Cancel opens no share sheet and shows no error`
  - `Back during preparation cancels and keeps the page`
  - `failure dialog Share original shares the original alongside prepared files` (share platform via `test/helpers/late_bound_share_platform.dart`)
  - `failure dialog Cancel shares nothing`
  - `interrupted shows the background message`
  - `site viewer share goes through shareMediaItems`
- [ ] **Step 2:** Run, expect FAIL. **Step 3:** Implement. **Step 4:** Run, expect PASS; also `test/architecture/` and `test/shared/`.
- [ ] **Step 5: Commit** `feat(media): progress, cancel and fallback when sharing corrected videos`

### Task 8: Apple colour encode (iOS and macOS)

**Files:**
- Create: `packages/submersion_transcoder/darwin/Classes/ColorEncoder.swift`
- Modify: `packages/submersion_transcoder/darwin/Classes/SubmersionTranscoderPlugin.swift` (`encodeWithColor`, `cancelEncode`)
- Test: `integration_test/darwin_color_encode_test.dart`

**Interfaces:**
- Consumes: channel contract (Task 2), colour formula.
- Produces: `ColorEncoder.encode(source: String, output: String, keys: [(timeMs: Int, matrix: [Float])], onProgress: (Double) -> Void, isCancelled: () -> Bool) throws` with errors mapped to `cancelled` / `unsupported` / `transcode_failed`.

Approach: `AVAssetReader` video output in a 16-bit float RGBA format for 10-bit/HDR sources and BGRA for 8-bit SDR; detect transfer from the track's format description (`kCVImageBufferTransferFunction_ITU_R_2100_HLG` / `SMPTE_ST_2084_PQ`, else sdr); apply the formula on the GPU (Core Image custom color kernel or Metal compute) with colour management off (`CIImage` colorSpace `NSNull`, context working space `NSNull`); `AVAssetWriter(fileType: .mp4)` with codec by the Global Constraints, `AVVideoColorPropertiesKey` copied, Main 10 profile for 10-bit, `transform` copied, bitrate from the track's `estimatedDataRate` (floor 4 Mbps); every audio track passthrough (`outputSettings: nil`, `sourceFormatHint`); `writer.metadata = asset.metadata`; times are presentation times; iOS `beginBackgroundTask` around the encode, expiry sets cancelled; `isCancelled` checked per frame; `.tmp` then rename; `unsupported` when `canAdd`/`startWriting` refuses the codec/size/profile.

- [ ] **Step 1: Write the integration test** (pattern of `darwin_transcode_test.dart`; ffmpeg synthesizes inputs, skip without it): flat-patch clips 2 s, 320x240, three solid patches; cases `h264 sdr`, `hevc sdr`, `hevc hlg 10-bit`, `hevc pq 10-bit with mastering metadata`, `rotated 90 h264`, `h264 with 1.5 s start offset`. Timeline: identity at 0, gains(1.3, 1, 0.7) + brightness offset at 2000 ms. Assertions via ffprobe: codec matches, pix_fmt bit depth matches, `color_transfer`/`color_primaries` match, rotation matches, audio stream present, `creation_time` and `location` tags kept; via ffmpeg decoding frames at 0.5 s and 1.5 s to `rgb48le`: each patch within 3% (8-bit SDR) or 2% (10-bit) of `correctPixel` applied to the source's decoded patch with `matrixAt(t)`. Plus `cancel leaves no output or tmp`.
- [ ] **Step 2:** Run `flutter test integration_test/darwin_color_encode_test.dart -d macos`, expect FAIL (method not implemented). Needs ffmpeg with libx264/libx265 on PATH (`brew install ffmpeg`, ask first).
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, expect PASS. Re-run `integration_test/darwin_transcode_test.dart -d macos`.
- [ ] **Step 5: Commit** `feat(media): apply colour timelines when encoding on Apple platforms`

### Task 9: Android colour encode (Media3)

**Files:**
- Create: `packages/submersion_transcoder/android/src/main/kotlin/app/submersion/transcoder/ColorTimelineEffect.kt`
- Create: `packages/submersion_transcoder/android/src/main/kotlin/app/submersion/transcoder/Media3ColorEncoder.kt`
- Modify: `SubmersionTranscoderPlugin.kt`, `android/build.gradle` (Media3 upgrade if needed)
- Test: `integration_test/android_color_encode_test.dart`

**Interfaces:**
- Produces: `Media3ColorEncoder.encode(context, source, output, keys, progressId, onProgress, onDone)`, `cancel(progressId)`.

Approach: Transformer with `Composition.HDR_MODE_KEEP_HDR`; `DefaultVideoFrameProcessor.Factory` with colour transfers disabled so the GL effect sees encoded values; `ColorTimelineEffect : GlEffect` whose shader implements the formula with the transfer chosen from the input `ColorInfo`, matrix from `presentationTimeUs` relative to the first frame; `DefaultEncoderFactory` with fallback disabled; output MIME from the source track (`video/hevc` or `video/avc`, HEVC for others); `unsupported` for `ExportException` codes `ERROR_CODE_ENCODING_FORMAT_UNSUPPORTED`, `ERROR_CODE_DECODING_FORMAT_UNSUPPORTED`, `ERROR_CODE_HDR_ENCODING_UNSUPPORTED`; cancel via `transformer.cancel()` reported as `cancelled`; audio left without processors (passthrough).

- [ ] **Step 1:** Write the integration test mirroring Task 8's cases, reading pushed inputs (`it_color_<case>.mp4`, as `android_transcode_test.dart` does) and skipping absent ones; compare frames via `engine.extractFrames` for SDR patches (within 4%) and assert HDR tags through the probe.
- [ ] **Step 2:** Run on an emulator, expect FAIL. **Step 3:** Implement. **Step 4:** Run, expect PASS (record which cases the emulator could run; HDR needs a device with HDR editing).
- [ ] **Step 5: Commit** `feat(media): apply colour timelines when encoding on Android`

### Task 10: Windows colour encode (Media Foundation)

**Files:**
- Create: `packages/submersion_transcoder/windows/color_encoder.cpp`, `packages/submersion_transcoder/windows/color_encoder.h`
- Modify: `submersion_transcoder_plugin.cpp`, `windows/CMakeLists.txt`
- Test: `integration_test/windows_color_encode_test.dart`

**Interfaces:**
- Produces: `bool EncodeWithColor(const std::wstring& source, const std::wstring& output, const std::vector<TimelineKey>& keys, std::function<void(double)> on_progress, std::atomic<bool>& cancelled, std::string* error_code, std::string* error_message)`.

Approach: worker thread; Source Reader decoding to RGB32 (SDR) or P010 (10-bit, converted to RGB on the CPU with the source's matrix), formula per pixel (SDR via a 3x256 LUT plus cross terms is acceptable only if within tolerance), Sink Writer H.264 or HEVC (Main 10 for P010) with `MF_MT_VIDEO_PRIMARIES`, `MF_MT_TRANSFER_FUNCTION`, rotation copied; audio stream passthrough; creation date and location written through the shell property store (`System.Media.DateEncoded`, `System.GPS.*`) when the source has them; `unsupported` when no encoder MFT accepts the type.

- [ ] **Step 1:** Write the integration test mirroring Task 8 (ffmpeg on the Windows runner synthesizes inputs; skip without it).
- [ ] **Step 2-4:** Implement; verified by the Windows CI build and this test where a Windows runner runs it. Not runnable locally; list in the PR.
- [ ] **Step 5: Commit** `feat(media): apply colour timelines when encoding on Windows`

### Task 11: Finish

- [ ] `dart format .`, `flutter analyze`, `flutter test test/features/media test/features/media_store test/architecture test/shared`, all PASS.
- [ ] Screenshots (macOS desktop and iOS phone, light and dark): progress dialog single and "2 of 3", failure dialog, interrupted snackbar; saved as `<nn>-<screen>-after[-dark][-phone].png` in the scratchpad.
- [ ] Manual check on macOS: share a corrected dive video from the viewer and from library multi-select; the shared file plays with the correction.
