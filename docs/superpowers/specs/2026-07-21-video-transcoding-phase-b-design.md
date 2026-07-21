# Video Transcoding (Upload Quality Phase B): Native Engines + System ffmpeg on Linux

Status: design approved (brainstorm 2026-07-21). Phase B of the Adjustable
Media Upload Quality feature
(`docs/superpowers/specs/2026-07-20-adjustable-media-upload-quality-design.md`,
Phase A shipped as PR #666 on `worktree-media-upload-quality`). Built on branch
`worktree-media-upload-quality-phase-b`, stacked on Phase A.

## 1. Problem

Phase A ships the complete adjustable-quality architecture, but video -- where
the storage actually goes -- still uploads originals at every level: the
`VideoTranscoder` interface exists with no implementation, so the pipeline's
null-fallback kicks in. A single 4K dive clip dwarfs a dive's worth of stills.
Phase B implements `VideoTranscoder` so a non-`Original` video level uploads a
compressed H.264/AAC rendition instead of the original.

## 2. Goals

1. **Video compression on every platform that can do it natively** -- iOS,
   macOS, Android, Windows via in-box OS transcoders; Linux via a system
   ffmpeg when present.
2. **Zero vendored binaries.** No ffmpeg builds, no prebuilt artifacts, no
   binary bundling on any platform.
3. **Transcode-once, upload-resumably.** A transcoded rendition survives
   upload retries and app restarts; a clip is never re-transcoded because an
   upload failed.
4. **Graceful degradation everywhere.** Any missing/failing engine yields
   Phase A's shipping behavior (upload the original), never a stuck queue.
5. **Uniform output contract:** H.264 + AAC in `.mp4` with faststart, sized
   by the level's preset, on every platform.

## 3. Non-goals (Phase B)

- **Bundled or vendored ffmpeg.** Superseded decision -- see section 4.
- **Byte-identical output across platforms.** Each OS's hardware encoder
  produces different (visually equivalent) bytes. Cross-device rendition
  content-dedup for video is explicitly not attempted; the rendition key is
  already per-content-hash, so this changes nothing observable.
- **HEVC/H.265 output.** H.264 for universal playback compatibility. HEVC is
  a possible future level option.
- **Determinate transcode progress in the Transfers UI.** The interface
  carries a progress callback (section 9), but v1 UI shows the existing
  indeterminate state during transcode.
- **Mid-transcode cancellation.** Transcodes run to completion; an app quit
  discards the incomplete `.tmp` (section 8). The worker gate is checked
  between queue entries, as today.
- **Re-transcoding library content when presets change.** Same "future
  uploads only" rule as Phase A.

## 4. Decisions made during brainstorming

| Question | Decision |
| --- | --- |
| Engine strategy | **Native per-platform engines; no ffmpeg builds.** This SUPERSEDES Phase A's provisional "GPL ffmpeg everywhere" decision. Rationale: linked libffmpeg for iOS/Android is the dominant cost/risk of that plan (cross-compilation, large binaries, the orphaned build infrastructure ffmpeg_kit's 2025 retirement left behind), and every non-Linux platform has a mature in-box transcoder. Prebuilt-artifact delivery was also weighed and rejected along with it: even at its best it left binary hosting/versioning burden, whereas native engines eliminate the question. |
| Linux (no universal native encoder) | **System ffmpeg on PATH.** Detected at runtime; absent -> transcoder returns null -> original uploads (Phase A's shipping fallback). Idiomatic for a GPL OSS app on Linux; zero bundling. |
| Windows | **Media Foundation** (in-box since Windows 7), not bundled ffmpeg. |
| Presets | **Bitrate-based, not CRF.** CRF is an x264 concept no native engine speaks. `VideoQualityPreset` is revised (section 6). |
| Ceiling rule for video | Resolution AND bitrate gated with 1.25x headroom (section 7). |
| Staging | Deterministic path + tmp-rename completeness marker; delete only on markDone (section 8). |
| Progress | Optional `onProgress(double)` on the interface now (interface churn later is worse); UI wiring deferred. |

## 5. Architecture overview

One new federated plugin, `packages/submersion_transcoder`, provides four thin
native implementations plus a pure-Dart Linux path behind the existing Phase A
seam:

```
MediaUploadPipeline ── VideoTranscoder (Phase A interface, unchanged shape)
                            │
                 PlatformVideoTranscoder (plugin's Dart entry; picks by Platform)
                            │
     ┌───────────────┬──────┴──────┬────────────────┬─────────────────┐
  darwin/          android/      windows/          linux (pure Dart)
  AVFoundation     Media3        Media Foundation  Process.start(ffmpeg)
  (AVAssetWriter)  Transformer   SourceReader→     when on PATH,
  shared iOS+macOS (MediaCodec)  SinkWriter        else null
```

- Engines are hardware-accelerated where the OS provides it.
- The app wires `PlatformVideoTranscoder` into `mediaStoreRuntimeProvider`'s
  pipeline construction (Phase A left `videoTranscoder: null`).
- Any engine returning null (unsupported input, ffmpeg absent) or being
  unavailable degrades to uploading the original -- the Phase A contract.

## 6. Presets (revised `VideoQualityPreset`)

`VideoQualityPreset` in `lib/features/media_store/data/quality_presets.dart`
is consumed by no engine yet, so Phase B revises it in place on the stacked
branch: `crf` is replaced by `videoBitrateKbps`.

| Level | maxHeight | videoBitrateKbps | audioBitrateKbps |
| --- | --- | --- | --- |
| high | 1080 | 8000 | 128 |
| balanced | 720 | 4000 | 128 |
| small | 480 | 1800 | 96 |

Output contract on every platform: H.264 (baseline/main/high as the encoder
chooses) + AAC-LC, MP4 container with faststart (moov atom leading), frame
rate preserved, aspect preserved (scale to `maxHeight`, never upscale),
rotation metadata honored (the rendition is displayed upright). On Linux the
bitrate maps to `-b:v` two-pass-off single-pass encoding; on native engines it
maps to the encoder's average-bitrate setting.

## 7. Video ceiling rule

Compressing an already-small clip wastes battery and quality. Before
transcoding, the engine probes source metadata (duration, dimensions, overall
bitrate, codec) using its native prober (AVAsset / MediaExtractor /
SourceReader / `ffprobe`). Return null -- upload the original -- when BOTH:

- `sourceHeight <= preset.maxHeight`, and
- `sourceOverallBitrateKbps <= 1.25 * (preset.videoBitrateKbps + preset.audioBitrateKbps)`.

The 1.25 headroom prevents pointless re-encodes (generation loss for ~nothing).
Resolution alone is insufficient: a 20 Mbps 720p GoPro clip should still
compress at `balanced`. A probe failure (corrupt/unsupported container) also
returns null; the original still uploads and nothing is lost.

## 8. Transcode-once staging model

Transcoding a long clip costs minutes and battery; it must never repeat
because an upload failed or the app restarted.

- **Deterministic output path:** `<cacheRoot>/transcode/<contentHash>_<level>.mp4`
  (cacheRoot = the existing MediaCacheStore root; `transcode/` is a sibling of
  `staging/`).
- **Completeness marker = atomic rename.** Engines write to
  `<name>.tmp` and rename to the final name only on success. A `.tmp` found
  later is debris from an interrupted transcode: deleted and redone.
- **Pipeline behavior:** before invoking the engine, `process()` checks the
  final path; if present, it is used directly (skip transcode). The file is
  deleted only on `markDone`. Upload failure leaves it for the retry; a
  replaced override level produces a different `_<level>` name, and stale
  siblings for the same hash are cleaned opportunistically on markDone.
- **Phase A fix folded in:** photo renditions currently leak their staging
  file when the upload fails after compression. Phase B routes photo
  renditions through the same delete-on-markDone rule for consistency.

## 9. Plugin structure and interface

```
packages/submersion_transcoder/
  pubspec.yaml            # plugin platforms: ios, macos, android, windows
  lib/submersion_transcoder.dart      # PlatformVideoTranscoder + Linux impl
  lib/src/transcode_request.dart      # request/result/probe DTOs
  darwin/                 # shared Swift (AVAssetReader/Writer), iOS+macOS
  android/                # Kotlin, media3-transformer
  windows/                # C++ Media Foundation (SourceReader -> SinkWriter)
```

- **Interface change (app side):** `VideoTranscoder.transcode()` gains
  `void Function(double fraction)? onProgress` (0.0-1.0). All four engines
  report progress natively (AVAssetWriter timestamps, Transformer
  `getProgress`, SinkWriter sample timestamps vs duration, ffmpeg
  `-progress pipe:1`). v1 passes it through the plugin but the pipeline sends
  null; the Transfers row stays indeterminate during transcode.
- **Channel design:** one MethodChannel (`transcode`, `probe`, engine
  availability) + one EventChannel for progress, mirroring the
  libdivecomputer plugin's shape. Linux bypasses channels entirely (Dart
  `Process`).
- **Availability probe:** `PlatformVideoTranscoder.isAvailable()` -- true on
  iOS/macOS/Android/Windows; on Linux, true iff `ffmpeg` and `ffprobe` are on
  PATH (checked once per session, re-checked on settings entry).

## 10. Per-engine notes

- **darwin (iOS + macOS):** `AVAssetReader` + `AVAssetWriter` (not
  `AVAssetExportSession` -- its fixed presets cannot hit per-level bitrates).
  H.264 via VideoToolbox with `AVVideoAverageBitRateKey`; AAC via
  `AVAudioSettings`. `shouldOptimizeForNetworkUse` handles faststart. Shared
  source in `darwin/` like libdivecomputer.
- **Android:** `media3-transformer` with `VideoEncoderSettings.bitrate` and
  `Presentation.createForHeight()` for scaling. Known fleet variability of
  MediaCodec encoders is accepted; a Transformer failure maps to a thrown
  error (queue retry), and repeated terminal failure leaves the original
  uploadable via retry-at-original (section 12).
- **Windows:** Media Foundation SourceReader -> SinkWriter;
  `MF_MT_AVG_BITRATE` for H.264, AAC encoder MFT for audio;
  `MF_LOW_LATENCY` off; faststart via `MF_MP4_SINK_MOOV_BEFORE_MDAT`. Watch
  the repo's known Windows plugin traps (min/max macro collisions -- see the
  `windows-minmax-macro` note).
- **Linux:** `Process.start('ffmpeg', [...])` with
  `-c:v libx264 -b:v <kbps>k -vf scale=-2:<h> -c:a aac -b:a <kbps>k
  -movflags +faststart -y <out.tmp>`; `ffprobe -print_format json` for the
  ceiling probe. If the system ffmpeg lacks libx264 (rare), the non-zero exit
  maps to null -> original uploads.

## 11. Pipeline and provider wiring

- `mediaStoreRuntimeProvider` constructs the pipeline with
  `videoTranscoder: PlatformVideoTranscoder(...)` (Phase A passes null).
- `MediaUploadPipeline._renditionFor` already routes video to the transcoder;
  Phase B adds the deterministic-staging check around it (section 8) and the
  markDone cleanup.
- The per-item re-upload override works for video unchanged: an override
  entry forces a re-render at the chosen level from the original (which must
  be locally resolvable, as in Phase A).

## 12. Settings and UX

- The existing video-quality dropdown (Phase A) simply becomes effective.
- **Linux hint:** on Linux, when a non-Original video level is selected and
  ffmpeg is not detected, the Media Storage page shows an inline hint under
  the video dropdown: "Install ffmpeg to enable video compression; originals
  are uploaded until then." (new l10n key, all 11 locales).
- No other UI changes. Transfers rows show the existing indeterminate state
  while an entry is transcoding.

## 13. Error handling

| Case | Behavior |
| --- | --- |
| Engine unavailable (Linux w/o ffmpeg) | `transcode` returns null -> original uploads (Phase A contract) |
| Probe failure / unsupported input | null -> original uploads |
| Engine failure mid-transcode (codec error, OOM, MF/Transformer error) | throw -> queue markFailed -> normal backoff/retry; `.tmp` deleted on next attempt |
| Repeated terminal failure | entry terminally 'failed'; `retry()` re-arms; user can per-item override to `Original` to upload the raw clip instead |
| Disk full while writing rendition | throw -> markFailed with the OS message |
| App quit mid-transcode | `.tmp` debris deleted on next attempt; transcode restarts |

## 14. Testing strategy

- **Dart unit (all platforms):** fake `VideoTranscoder` (exists from Phase A);
  deterministic-staging tests (existing rendition skips transcode; `.tmp`
  debris is discarded; markDone deletes; failure preserves); ceiling-rule
  tests against a fake prober seam; Linux argument-construction tests
  (preset -> ffmpeg args) with a fake `Process` runner.
- **Fixture:** one tiny checked-in test video (~seconds, small resolution,
  generated once with ffmpeg and committed) under `test/fixtures/`.
- **Real-engine smoke in CI:** macOS runner (AVFoundation), Linux runner
  (`apt-get install ffmpeg`), Windows runner (Media Foundation) each run one
  real transcode of the fixture and assert the output is a playable H.264 mp4
  smaller than the input; Android via the existing instrumented-test lane.
  These are tagged/gated so local `flutter test` stays engine-free.
- **Coverage:** >= 90% patch on the Dart side; native code exercised by the
  smoke lanes.

## 15. Delivery order (independently useful steps)

1. Package scaffold + Dart-side `PlatformVideoTranscoder` + **Linux engine**
   (pure Dart, fully unit-testable, first real end-to-end compression).
2. Pipeline integration: deterministic staging, markDone cleanup, provider
   wiring, preset revision, ceiling seam, Linux settings hint + l10n.
3. **darwin engine** (iOS + macOS shared Swift).
4. **Android engine** (Media3).
5. **Windows engine** (Media Foundation).

Each engine lands independently; platforms without their engine yet keep
uploading originals.

## 16. Alternatives considered

- **GPL ffmpeg everywhere (Phase A's provisional choice).** Rejected on
  concrete costs: linked libffmpeg for iOS/Android is the orphaned-infra
  problem ffmpeg_kit's retirement created; every delivery variant (prebuilt
  artifacts, source builds, CI caching) either stores binaries or costs
  20-40 min local ffmpeg compiles after every `flutter clean`. Its uniform
  output/CRF semantics were not worth that for logbook video.
- **Bundled ffmpeg CLI on Windows/Linux.** Media Foundation removes the
  Windows need; on Linux, system ffmpeg + graceful fallback beats
  bundling/versioning a static binary for a GPL OSS app.
- **GStreamer on Linux.** x264enc lives in plugins-ugly with uneven distro
  availability; heavier integration than `Process.start(ffmpeg)` for no
  reliability gain.
- **Community ffmpeg_kit forks.** Same maintenance risk as in Phase A's
  brainstorm; unchanged conclusion.

## 17. Risks

- **Per-engine output variability** (size/quality spread across devices,
  Android fleet quirks). Accepted trade; presets are ceilings, not promises.
- **Media Foundation implementation effort** is the largest native chunk
  (C++/COM). Mitigated by delivery order (it lands last) and by the
  SourceReader->SinkWriter pattern being well-documented.
- **Media3 Transformer API churn.** Pin the version; the engine surface is
  one class.
- **Linux UX depends on ffmpeg presence.** Mitigated by the settings hint and
  the lossless fallback (originals upload).
- **Preset numbers may need tuning** once real devices produce output; they
  live in one file and are trivially adjustable.
