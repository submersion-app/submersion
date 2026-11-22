# Marine life identification, piece 3: Android, Windows and Linux

Refs #4668 (closed with pieces 1 and 2). A piece 3 issue is opened before
the first pull request, which the PR issue link check needs.

Program overview, with the decisions that apply to every piece:
[2026-11-17-marine-life-identification-program-design.md](2026-11-17-marine-life-identification-program-design.md).
The pieces this one brings to other platforms:
[photos](2026-11-17-marine-life-identification-1-photos-design.md),
[video](2026-11-17-marine-life-identification-2-video-design.md),
[auto-apply and review](2026-11-18-marine-life-identification-4-auto-apply-design.md)
and [live naming](2026-11-18-marine-life-identification-5-live-naming-design.md).
The pack and floor decisions are in the
[release gate](2026-11-18-marine-life-release-gate-design.md). Read the
overview, the photos piece and the video piece first. This document does not
repeat their reasoning.

Decisions are marked **(decided)** when the maintainer made them and
**(proposed)** when they are the designer's call, open to correction.

Approved by the maintainer on 2026-11-19. Amended on 2026-11-20 for GPUs on
Windows through Windows ML (sections "GPUs on Windows" and 2a), and the
amendment approved the same day.

## What this piece delivers

On an Android phone or tablet, a Windows PC or a Linux PC, once the diver has
downloaded the model pack, the app does what it does on an iPhone, iPad or
Mac **(decided: "everyone would use it to identify things in their
photos/videos")**:

1. Suggestions on photos, in the chip row and the species sheet.
2. On Android and Windows, video scanning and labelled playback, with live
   naming following the playhead.
3. Auto-apply and review.

The same pack, the same models and the same naming bars serve every device
**(decided: "same models everywhere")**. On a Windows PC with a GPU (or an
NPU) the models run there, through Windows ML **(decided 2026-11-19:
"windows ML")**; everywhere else off Apple devices they run on the main
processor. Linux gets photos only, because the app has no video player there
**(proposed)**.

## Why

Every diver, whatever they own, should be able to have the app name the
animals in their photos and videos. Today the setting is hidden everywhere
but Apple devices, because Core ML is the only engine. This piece adds the
second engine the program overview planned: ONNX Runtime.

Success is that one photo gets the same suggestions on any device that opens
it, to within what the accuracy gate below can measure.

## Goals

- Run the pack's own detectors and classifier on Android, Windows and Linux,
  on the device, offline.
- Prove, with the pack's own scorer and test set, that the new engine names
  animals as well as Core ML does at the pack's bars, before any diver sees
  it.
- One implementation of the work around the models for all three platforms,
  which the scorer can run.
- Change nothing an iPhone, iPad or Mac does or downloads.

## Non-goals

- Video on Linux. It would need a video player in the app first, which is a
  piece of its own.
- Phone AI chips (Qualcomm's NPU, GPU paths) and smaller 8-bit models
  **(decided)**. On Android and Linux the ONNX engine runs the same models on
  the main processor. Core ML on Apple devices is unchanged: it still picks
  the GPU or Neural Engine itself (`computeUnits = .all` in
  `VisionPipeline.swift`). Windows is the exception, through Windows ML
  (section 2a).
- GPUs on Linux. ONNX Runtime's Linux GPU route is NVIDIA's CUDA, hundreds of
  megabytes for one vendor.
- Changing the naming rules, the bars, the stored records, the screens or
  how labels look. Everything above the engine is shared and stays as it is.
- The web build. It compiles and the feature stays absent.
- Lowering the iPhone floor. That waits on a 6 GB iPhone, not on this piece.
- Windows on ARM and Linux on ARM builds. The app ships x64 builds of both
  today; an x64 build under emulation is not a target.

## Anti-goals

- **Different names on different devices.** A diver who sees one name on
  their Mac and another on their phone for the same fish stops trusting
  both. Unchecked GPU and NPU engines on Windows are the maintainer's
  accepted exception (see "Risks").
- **An iPhone or Mac downloading the pack again** because files for other
  engines were added to it.
- **A phone that passes the floor getting the app killed for memory**, or a
  scan that heats a phone for minutes after the diver has moved on (piece 2's
  anti-goal, which a processor-only engine makes easier to hit).
- **Breaking a supported platform's build**: Android from API 26, Google
  Play's 16 KB page alignment, Windows 10, and the Linux tarball's glibc.

## Constraints

- **Platforms.** Android minSdk 26, with the feature on 64-bit devices only
  (arm64-v8a, and x86_64 for Chromebooks and emulators). Windows 10 and
  later, x64. Linux x64, built on Ubuntu 24.04.
- **Native libraries** reach the app as Dart build hook code assets, as
  SQLite (SQLCipher) does. CI checks that a Windows or Linux bundle carries
  every code asset it declares (`scripts/check_bundled_native_assets.py`),
  that an Android archive carries a fixed list of libraries in every ABI it
  ships (`scripts/check_native_libs_present.py`, today only
  `libsqlcipher.so`), and that Android libraries are 16 KB aligned
  (`scripts/check_16kb_alignment.py`).
- **One pack.** The app reads the latest release's manifest of
  submersion-app/species-pack. Publishing anything to it needs the
  maintainer's go, every time **(decided, standing)**.
- **The bars were measured on Core ML's output**, by the species-pack scorer
  running the app's own Swift pipeline (`vision_cli`). Nothing has measured
  any other engine.
- **Media is links only**, and a scan never starts a download (pieces 1 and
  2).
- **Android has no fixed per-app memory limit.** The iPhone floor came from
  the limit iOS gives each app; on Android a foreground app can use what the
  phone can free, and the system kills apps, background ones first, when the
  whole phone runs short.

## Approaches

### How the engine reaches Dart

1. **Native code on each platform, behind the Swift channel.** Kotlin on
   Android and one set of C++ for Windows and Linux, each copying what
   `VisionPipeline.swift` and `VideoScanner.swift` do. `ChannelVisionEngine`
   barely changes. But the pipeline would exist three times, each copy must
   match the scorer's merge and Core ML's output, and the scorer cannot run
   Kotlin or C++ over the test set, so the second goal has no route.
2. **One pipeline in Dart, calling ONNX Runtime's C library through FFI
   (chosen).** Everything around the models (resizing, reading boxes,
   merging, cropping, fitting) is written once in Dart and runs in a worker
   isolate. Photos are decoded by Flutter's own decoder. Only video frame
   reading is native. The same Dart pipeline runs on a Mac, so the scorer can
   measure exactly what ships, and it can be tested in Linux CI against real
   ONNX Runtime. Image arithmetic in Dart is slower than native vector code,
   by tens of milliseconds a photo against seconds of model time, and we keep
   our own bindings to ONNX Runtime, pinned to one version.
3. **A published Flutter ONNX package, with the Dart pipeline.** Less binding
   code, but the program overview set these aside for breaking a supported
   platform or OS version, and each would pull ONNX Runtime into the iPhone
   and Mac builds, which do not need it.

LiteRT (TensorFlow Lite) was also ruled out for Android: a third model
format, an unproven conversion for RF-DETR, and its main draw is the GPU,
which the speed decision below does not use.

The maintainer chose approach 2 **(decided)**.

### Speed on phones

1. **Same models everywhere, with ONNX Runtime on the main processor
   (chosen).** Apple devices keep Core ML's GPU and Neural Engine. One set of
   bars covers every engine. A photo takes seconds on a mid-range phone, and a
   video scan runs behind playback, so on phones most names appear when the
   diver pauses or watches again, as live naming already arranges for slower
   devices.
2. **Same models, plus the phone's AI chip where there is one.** Faster on
   Snapdragon phones only, with a large chip-specific library and each chip's
   results to check against the bars.
3. **Smaller 8-bit models on phones.** About half the classifier's download
   and memory and perhaps two to three times faster, but its names drift from
   the measured ones, so it needs bars of its own (a pack format change) or
   proof that it names the test set as well.

The maintainer chose option 1 **(decided)**. The early timing on a phone is
recorded but does not change the models.

### GPUs on Windows

Option 1 was chosen for phones; desktop GPUs were weighed after the design
was first approved.

1. **The processor only**, as on phones. Nothing new to build or check; video
   names lag playback on a PC.
2. **DirectML** when the PC has a DirectX 12 GPU, the processor otherwise.
   One ONNX Runtime setting for NVIDIA, AMD and Intel GPUs on Windows 10 and
   11. Microsoft supports it but no longer adds to it.
3. **Windows ML (chosen).** Microsoft's current route. It ships ONNX Runtime
   with the processor and DirectML on Windows 10 (1903) and later, and on
   Windows 11 24H2 and later fetches a vendor's engine for the PC's GPU or
   NPU (NVIDIA, AMD, Intel, Qualcomm). The fastest option, with each vendor's
   engine computing slightly differently, and the Windows App SDK in the
   Windows build.

The maintainer chose option 3 **(decided 2026-11-19)**, and chose that the
app uses whichever engine Windows offers, checked or not, as Core ML's GPU
and Neural Engine are trusted across Apple chips **(decided 2026-11-20: "Any
of them")**.

## What the diver sees

The same as on Apple devices: the settings page under Settings, Data, Photos
and videos; the download, with its size; the chip row and species sheet;
labels over video; auto-apply and review. The differences:

- **The download size** is the sum of the pack's ONNX files and its shared
  files, which is about what an iPhone downloads.
- **Speed.** On a mid-range phone a photo's suggestions appear several
  seconds after it opens, and a video's names mostly show when the diver
  pauses or goes back. On a PC both are faster, and on a Windows PC with a
  GPU video names can keep up with playback. First use after launch is
  slower still while the models load.
- **On Windows 11 24H2 and later,** where Windows offers a vendor engine for
  the PC's GPU or NPU, it is fetched as part of the diver's Download, and the
  download confirmation says so: one or two new strings, in all 11 languages
  **(proposed)**.
- **Find species runs** on Android and Windows cover photos and videos, as
  on Apple devices, and pause when the phone gets hot or the app leaves the
  foreground, as runs already do on iPhone **(proposed)**. On a phone a run
  over a dive's videos can take a long time.
- **Linux** offers photos only. Its toggle, introduction, settings entry
  subtitle and download prompt title say "photos", not "photos and videos":
  four new strings, in all 11 languages. Strings that only describe what
  is reviewed or applied ("Only for photos and videos with a location", the
  review summary and download text) stay as they are, since they remain true
  on Linux **(proposed)**.
- **A device below the floor**, or a 32-bit Android device, shows the
  existing "not supported on this device" state.

## How it works

```
photo opened (service unchanged)
   -> OnnxVisionEngine.analyze(path or bytes)
        main isolate: read the bytes; Flutter's decoder, longer side
          capped at 4096, orientation applied -> RGBA pixels
        worker isolate: each detector (ONNX Runtime), merge, crop, fit,
          classifier (ONNX Runtime), crop thumbnail
      -> VisionAnalysis, as Core ML returns it
   -> naming, storage, suggestions (unchanged)

video opened (Android and Windows; service unchanged)
   -> detectVideo: native frame reader, frames in order at most 960 px
        -> worker: detectors, merge -> VideoDetections
   -> embedMoments: native frame reader, each moment's exact frame
        capped at 4096 px -> worker: crop, fit, classifier
   -> tracking, naming, storage, labels (unchanged)
```

## The parts

### 1. Platforms and the flag

- `visionEngineRuns` (`lib/core/constants/feature_flags.dart`) is true for
  Android, Windows and Linux as well. The flag and the engine keep asking the
  same function, so they always agree.
- `visionEngineProvider` returns `ChannelVisionEngine` on iOS and macOS and
  the new `OnnxVisionEngine` on Android, Windows and Linux, chosen by
  `defaultTargetPlatform` so tests can override it.
- `VisionEngine` gains `onnxEngine = 'onnx'`, the engine name the pack's ONNX
  files carry.
- **Linux never touches a video.** The viewer resolves a video's file on
  Linux as everywhere (`videoPlaybackProvider` returns `FilePlayback`
  whether or not a player exists), and a Find species run resolves a video's
  file without any player (`runVideoFileOf`). So the check cannot rest on the
  player's absence: on Linux the service queues no video, a Find species run
  passes over videos without counting them as failed (the action is already
  called "Find species in photos"), and the engine's video calls fail with
  `unsupported` as a last guard **(proposed)**.

**Turning the platforms on.** Until step 5 of "Order of work",
`visionEngineRuns` includes Android, Windows and Linux only in a build made
with `--dart-define=MARINE_LIFE_ID_ONNX=true`. The measurement build, the
checks by hand and the pull request's screenshots use it. Step 5 changes the
define's default to true, once the pack carries ONNX files and the floor has
been measured, as the release gate did for Apple devices. The existing
`MARINE_LIFE_ID=false` still turns the feature off everywhere.

### 2. The engine: `OnnxVisionEngine`

An implementation of the existing `VisionEngine` interface, in
`lib/features/species_id/data/engines/`. Nothing above the interface changes.

**Bindings.** FFI bindings to ONNX Runtime's C API, generated with `ffigen`
from the pinned version's `onnxruntime_c_api.h` and checked in. Only what the
engine uses: the environment, session options, creating a session from a
file, running it, tensors and releasing them.

**The library.** `packages/submersion_vision` gains a build hook
(`hook/build.dart`), the first local package to have one, modelled on
`package:sqlite3`'s. For Android (arm64-v8a, x86_64) and Linux x64 it
fetches ONNX Runtime's official prebuilt release of the pinned version; for
Windows x64 it fetches Windows ML's package (`Microsoft.Windows.AI.MachineLearning`
on NuGet), which carries ONNX Runtime, DirectML and Windows ML's own library
(section 2a). Each download is checked against a hash kept in the package
and handed to Flutter as code assets. iOS, macOS and the web get nothing. A
32-bit Android build gets no library, and the engine reports
`deviceNotEligible` there.

**One ONNX Runtime version.** Android and Linux are pinned to the ONNX
Runtime version the pinned Windows ML package ships (1.24 at the time of
writing), so the processor path is the same code on all three. The C API is
versioned, so a newer runtime arriving with a Windows App SDK update still
serves the same bindings.

The library must pass the three CI checks above. The Android check today
requires each listed library in every ABI the archive ships, and Flutter's
default APK also ships armeabi-v7a, which gets no ONNX Runtime; the check
gains a per-ABI requirement so that ONNX Runtime is required on arm64-v8a
and x86_64 only. ONNX Runtime's licence (MIT) and its third-party notices
are added to the app's licences page.

**On a Mac, for tests and scoring only.** ONNX Runtime's C library exports
one function, `OrtGetApiBase`; every other call goes through the function
table it returns. On the three platforms the engine finds that one function
in the code asset. The scoring runner (section 6) and test runs on a Mac
load ONNX Runtime's macOS library from a path given at run time instead, so
the Mac app carries nothing it does not use **(proposed)**. Past that one
lookup the code is the same. The real ONNX Runtime test runs in Linux CI
and must not be skipped there; on a Mac without the library it skips.

**The worker isolate.** One long-lived isolate owns the ONNX Runtime
sessions and does every per-pixel step. The main isolate only reads bytes and
asks Flutter to decode them; nothing does pixel work or model work on the UI
isolate (piece 1's rule).

**Decoding a photo.** The engine reads the file (or takes the bytes the
service passes), asks Flutter for the image's size, and decodes it with the
longer side capped at 4096, as the Swift pipeline caps it. Flutter applies
EXIF orientation, so boxes match what the viewer shows; a rotated test photo
checks this. A format Flutter cannot decode on that platform (HEIC on Windows
and Linux, which the viewer cannot show either) fails with `decode_failed`,
and nothing is recorded. The RGBA pixels go to the worker without a copy
where the platform allows.

**The detectors, merge, crop and embedding** are Dart ports of the Swift
pipeline, step for step:

- RF-DETR: the image resized straight to the square input, normalised with
  the detector's mean and standard deviation, a sigmoid on each query's best
  class score, the score threshold, best first, at most `maxBoxes`.
- YOLO: letterboxed as ultralytics places it (`letterboxRect`), grey 114
  fill, boxes taken out of the letterbox, suppression at 0.7 overlap, at most
  `maxBoxes`.
- Two detectors: Swift's `merge` and `overlap`, which equal `boxes.py`'s.
  The Dart merge runs `boxes_test.py`'s cases in Linux CI, as
  `vision-merge-check.yml` does for Swift on macOS.
- Each box padded by `cropPadding`, clipped, cropped from the capped image,
  fitted by `cropFit` (pad to square with the mean colour, or centre crop),
  normalised and embedded. The embedding's length is checked against
  `embeddingSize`. A crop under 2 pixels a side is skipped, as in Swift.
- A JPEG thumbnail of each crop, fitted in `cropThumbnailSize`, quality 0.85,
  encoded in the worker.

The resampling filter for each resize is the builder's choice; the accuracy
gate judges it. Core ML's path draws with CoreGraphics' high quality
interpolation.

**Settled by the gate (D1, 2026-11-21).** The first gate run failed: the
ONNX engine named 586 held-out photos right against Core ML's 602, and on
the same pixels the two engines' models agree (embedding cosine 0.99999),
so the gap was all in the pixels. Two causes, both fixed in the engine:

- The filter. CoreGraphics' high quality interpolation, measured, blends
  the two nearest pixels on a curve stepped in eighths when it enlarges,
  and uses a cubic widened by the scale, with the first and last pixels
  mapped to the first and last, when it shrinks. The engine now draws the
  same way (`pipeline/resampling.dart`), to within a level or two.
- Colour. Flutter's decoder ignores a photo's embedded colour profile,
  which ImageIO converts to sRGB, so Display P3 photos reached the ONNX
  models about 9 levels redder. The engine converts matrix profiles to sRGB
  itself (`pipeline/colour_profile.dart`); a profile it cannot read leaves
  the pixels as decoded.

With both, ONNX names 602 right, as Core ML does. What remains is JPEG
decoding: ImageIO and the decoder Flutter uses (as on Android, Windows and
Linux) differ by about a level, which the engine cannot remove.

Drawing as CoreGraphics does costs more than the filter it replaced: a
12 MP photo's shrink reads about 25 source pixels across and 19 down for
each output pixel. Measured on a Mac in one process, the two detector
inputs take about 1.5 times as long as before (they share their first
pass, and the arithmetic is in whole numbers), and converting a Display P3
photo adds about as much again (fixed point, as littleCMS does it). On a
phone this is still well under the models' seconds, but it is no longer
tens of milliseconds.

**Precision.** The pack carries the ONNX models with 16-bit weights, so the
download is about Core ML's. Whether the engine widens them to 32-bit when it
loads them, or computes in 16-bit where the processor supports it, is the
builder's call, settled by the accuracy gate and the phone measurement.
Widened, the three models hold about 1.5 GB of memory; with a decoded 50 MP
photo and the app itself, the peak is expected between 1.5 and 2.5 GB.

**Threads and battery.** ONNX Runtime's own threads are limited so that
playback and scrolling stay smooth while a scan runs, and idle threads do not
spin. The count per platform is the builder's.

**`load` and `unload`.** `load` creates the sessions in the worker and is a
no-op for the same files. `unload` releases them, and memory returns close to
where it was before loading. The service's existing idle unload applies.
When Flutter reports memory pressure (`didHaveMemoryPressure`, which Android's
trim and low memory callbacks drive), the engine unloads, as the Swift engine
does on a memory warning; the next call gets `not_loaded` and the service
reloads once, as today.

**`availability`.** `available` when the library loads, the process is
64-bit and the device has at least the floor's memory (section 5); otherwise
`deviceNotEligible`, or `unsupportedPlatform` where there is no library. A
build made with `--dart-define=MARINE_LIFE_ID_IGNORE_FLOOR=true` skips the
memory check, for the Pixel 6a measurement only; no released build sets it.

**`memory`** feeds the existing debug log readout:

- Android and Linux read `/proc/self/status` (`VmRSS` for the footprint,
  `VmHWM` for its peak) and `/proc/meminfo` (`MemAvailable`).
- Android also reports the system's low memory flag and threshold
  (`ActivityManager.MemoryInfo`), through the Kotlin part. `VisionMemory`
  gains a nullable `lowMemory` field for it.
- Windows reads `GetProcessMemoryInfo` and `GlobalMemoryStatusEx` through FFI.
- The Neural Engine fields are null.

**`excludeFromBackup`** is a no-op on all three. Windows and Linux have no
device backup. On Android, Auto Backup includes the app's files directory,
where application support lives, and no runtime call can exclude a folder:
the app gains backup rules (`fullBackupContent` for Android 11 and earlier,
`dataExtractionRules` for 12 and later) that exclude `species_id/pack/` and
include everything else as today. Without them the pack would push the app
over Auto Backup's 25 MB limit and the diver's whole backup would be skipped.

**Background and heat (Android).** Video work is refused with
`not_foreground` when the app is not in the foreground, and with `too_hot`
when Android reports a severe thermal status or worse (API 29 and later).
Both are checked when a call starts and again between frames
**(proposed)**. Swift checks heat only when a call starts, which suits a
chunk that takes seconds; on a phone's processor one chunk can take
minutes. The viewer's scan already ends on either code and resumes on the
next opening, and a Find species run already pauses on either
(`DiveRunPause`). Windows and Linux check neither, as the Mac does not.

### 2a. Windows: the GPU through Windows ML

**(decided: Windows ML, any engine Windows offers; the rest proposed)**

Windows ML is a way of getting ONNX Runtime and hardware engines onto a PC,
not a different runtime. The model files, the Dart pipeline and the ONNX
Runtime calls are the same as on Android and Linux. What Windows adds:

- **Finding an engine.** Before creating sessions, the engine asks Windows
  ML's catalogue (its C interface, `WinMLEpCatalog.h`, through FFI) for the
  hardware engines Windows offers for this PC, and registers each one that is
  ready with ONNX Runtime's environment. A session then attaches a hardware
  engine's GPU devices (else its NPU devices) explicitly, then DirectML by
  name, then the processor. DirectML and the processor come with Windows ML
  and are always there. *(Amended 2026-11-20 after the spike: the first
  design let ONNX Runtime's selection policy prefer the GPU, but on a PC
  whose only graphics device is Windows' software renderer that policy, and
  any explicit attach of that device, ends the process. The engine picks
  devices itself and never the software renderer;
  [findings](../findings/2026-11-20-windows-ml-unpackaged.md).)*
- **Which engines.** Any engine Windows offers is used, whether or not it
  has been checked against the bars **(decided)**. The debug log records
  which engine ran each session.
- **Fetching a vendor engine** (Windows 11 24H2 and later only). Windows ML
  can download a vendor's engine for the PC's GPU or NPU from Microsoft
  (NVIDIA's was just under 200 MB at launch). That download happens only as
  part of the diver's Download of the pack, and the confirmation says so, so
  the app uses no network after that one step **(proposed)**. An engine
  that fails to arrive does not fail the pack's download; the PC uses DirectML
  or the processor. Windows Update keeps vendor engines current afterwards,
  on its own schedule.
- **Falling back.** If a session cannot be created on the chosen engine, or a
  run fails there, the engine tries DirectML, then the processor, and stays
  on the one that worked until the models are next loaded.
- **Memory.** On a GPU the models live in its memory; an integrated GPU
  shares the PC's. The 8 GB PC floor stands.
- **First load.** Some vendor engines compile the models for the GPU the
  first time and cache the result, so the first load on a PC can take much
  longer than later ones.
- **Deployment.** Windows ML is part of the Windows App SDK. Whether the
  Windows installer installs the Windows App SDK runtime, or the app carries
  what it needs itself, is the builder's call; either way the app keeps
  working on Windows 10, with DirectML and the processor only. The first step
  of building this is a spike that proves the catalogue works from the app as
  it is packaged today, an unpackaged Win32 app. *(Settled 2026-11-20 by the
  spike: the app carries Windows ML's three libraries beside the executable,
  with no Windows App SDK runtime or bootstrapper.)*

The accuracy gate (section 6) covers the processor path, which every
Windows PC can fall back to. The GPU and NPU paths are not gated
**(decided)**. Where a Windows PC with a GPU is to hand, the 100-photo
comparison of section 6 is run on it too and its agreement recorded in the
findings, for information.

### 3. Video frames (Android and Windows)

The only native code with logic of its own. `packages/submersion_vision`
gains an Android part (Kotlin) and a Windows part (C++), each on a channel of
its own, separate from the Swift channel **(proposed)**. They read frames and
know nothing about models.

- **Pass 1:** the frames of a stretch of video in order, the one nearest each
  sample time, with the longer side at most 960. The decoder runs through the
  stretch in order rather than seeking for each sample, so decoding stays
  well under the detectors' time. Android: `MediaExtractor` and `MediaCodec`;
  Windows: Media Foundation's source reader, as the transcoder's
  `color_encoder.cpp` uses it.
- **Pass 2:** one exact frame for each moment, capped at 4096. Android:
  `MediaMetadataRetriever` with `OPTION_CLOSEST`, as the transcoder's
  `FrameExtractor.kt` uses it; Windows: a seek and read with the source
  reader.
- **Orientation.** Frames are rotated as the player shows them, and the
  reported size matches `VideoPlayerController.value.size`. Android reads the
  rotation from the video's metadata; Windows from `MF_MT_VIDEO_ROTATION`.
- **Paths.** Whatever the player opened: a file path, or on Android a
  `content://` URI, as `FrameExtractor.kt` accepts.
- **Memory.** Frames are handed over one at a time as RGBA, never a chunk's
  worth at once. Whether the worker isolate calls the channel itself (through
  the background isolate messenger) or the main isolate relays is the
  builder's.
- Cut short (the app leaves the foreground, the device gets hot, the reader
  fails), a pass reports the failure; a chunk cut short is never returned as
  whole, as in Swift.

### 4. The pack

**Files.** Each detector and the classifier gain an ONNX file beside the
Core ML one: `<stem>.onnx.zip` with engine `onnx`, holding the model, which
unpacks into `<stem>/` as Core ML models do. The manifest format does not
change, and neither do the detector ids, the classifier id or the bars: the
same models, converted to another format. Today's apps download only
`coreml` and `all` files and ignore the rest.

**Conversion,** in submersion-app/species-pack (`models.py`,
`build_pack.py`):

- The fish detector through `rfdetr`'s own ONNX exporter.
- Megalodon through ultralytics' ONNX export.
- BioCLIP 2's image tower by tracing it and exporting it with PyTorch, as
  the spike did.
- 16-bit weights; an operator set the pinned ONNX Runtime runs.
- Each converted model is checked against the original's output, as the
  Core ML conversions are.

`build_pack.py` builds both engines' files by default. A pack without ONNX
files stays valid; those platforms then show "not available on this device".

**Publishing (proposed).** The ONNX files are added to the live pack's
release and its manifest is republished under the same pack version. An
iPhone or Mac then sees the same version, offers no update and downloads
nothing. This needs the maintainer's go, like every publish.

**Taking republished manifests in place.** Today
`SpeciesPackManifest.adoptableFrom` compares every file, so once a manifest
lists ONNX files, an installed Core ML pack can no longer take a later
same-version republish (new naming levels or credits) in place. It changes to
compare only the files for the device's engine and the shared ones. This goes
in its own small pull request, ahead of the release that first turns the
feature on, so no released app lacks it **(proposed)**. If it misses that
release, those apps simply need a new pack version for such a change.

### 5. Which devices get it

- **Android:** 64-bit, with at least the floor's memory, read from
  `/proc/meminfo` (`MemTotal`), which reports a little less than the phone is
  sold with, as on iPhone.
- **Windows and Linux:** at least 8 GB, read from `GlobalMemoryStatusEx` and
  `/proc/meminfo`, with the same 6.5 GiB cut-off as iPhone **(proposed)**. A
  smaller PC would not crash; it would swap and slow everything while a photo
  is open.
- **Macs** keep no floor. Core ML maps its models from disk; ONNX Runtime
  holds them in memory.

**The Android floor (decided 2026-11-19: "Yes, measure the 6a").** The
maintainer's phone is a Pixel 6a, which has 6 GB. A measurement build made
with `MARINE_LIFE_ID_ONNX` and `MARINE_LIFE_ID_IGNORE_FLOOR` lets the 6a run
the feature. It reaches the phone as an update to the installed app (the
beta track, or a build signed as the installed one is), never by
uninstalling, which would remove the log on the phone. Debug mode is turned
on for the readout, and the 6a is measured with a 50 MP photo and a 4K
video:

- it **passes** if the app is never killed and Android never reports low
  memory while identification runs;
- if it passes, Android launches with a 6 GB floor, with the cut-off between
  4 GB and 6 GB devices (the builder sets it from what such phones report);
- if it fails, Android launches at 8 GB, the 6.5 GiB cut-off.

**Settled by the run (D2, 2026-11-22): it failed.** Android's low memory
killer stopped the app twice on the 6a, both times within a second of the
camera opening, with identification holding the app at 3.0 to 3.3 GB. So
Android launches at 8 GB. The build went on by uninstalling the Play copy,
the maintainer's choice that day. Figures in
[the phone memory findings](../findings/2026-11-17-marine-life-phone-memory.md#on-a-pixel-6a).

The same run was to record the 6a's times (model load, a photo, a video
chunk) in the findings, as a mid-range reference. It could not: the app does
not log when a stage starts, and the video scanned was a single 2 second
chunk, so the 6a's times are still unmeasured.

### 6. The accuracy gate

The new engine is done only when it names the test set as well as Core ML
**(proposed rule; the maintainer set the aim: same names on every device)**.

**The scoring runner.** A runner in this repository that runs
`OnnxVisionEngine`'s own code on a Mac, under Flutter's headless test host
so that photos are decoded by Flutter's own decoder, as in the app. It speaks
`vision_cli`'s protocol (paths in, one JSON line per photo out, the same
fields, `--detector-boxes` included), so `score.py` can run it. The scorer
gains an engine option; how it builds or calls the runner is the builder's.

Before the ONNX files are published, on the held-out half of the natural
sample, with the pack's own bars and detector set:

1. The pack's bars pass `held_out_gate` (`bars.py`) on the ONNX engine's
   output, as they do on Core ML's.
2. The ONNX engine names right no fewer photos than Core ML, by the paired
   McNemar test the scorer already uses (`bars.mcnemar_p`, p < 0.05 counts as
   fewer).
3. No group (fish, coral and so on) is significantly worse, by the same test.
4. Junk (divers' hands, fins and the like) is named within the pack's own
   junk limit (`JUNK_LIMIT` in `gate.py`, measured as the pack measures it),
   and not significantly more often than by Core ML, by the paired test.
   Junk crops are paired by their labelled box (overlap 0.9 or more). The
   rows were labelled on Core ML's boxes, so a crop only one run found is
   left out of the pairing, and the check fails when more than 5% of the
   crops are left out in a way that could hide junk named: found only by
   ONNX, or lost by ONNX with a box still over the same object (overlap
   0.5 or more). A crop ONNX drew no box over names nothing there
   **(decided 2026-11-21: "Count moved boxes too"; D1's last four lost
   crops were boxes Core ML scored just over the 0.30 cut-off and ONNX
   just under it, from JPEG decoding)**.

A report beside it shows, for diagnosis only, how far the two engines' boxes
and embeddings differ per photo.

If the gate fails, the engine is fixed (its resizing, its precision), never
the bars.

**Other processors.** The gate measures ONNX Runtime's ARM64 code on a Mac;
PCs run its x64 code. Before publishing, the runner is also run on a Linux
x64 machine over 100 held-out photos and compared with the Mac's ONNX output:
each crop's embedding must agree (cosine similarity 0.999 or more), and at
least 99 in 100 crops must get the same top name and the same suggestion
outcome. A shortfall is investigated before publishing **(proposed)**.

**Every later pack (decided 2026-11-19: "Every pack").** Every pack carries
both engines' files and passes this gate as well as its Core ML checks
before it is published; a pack that fails either is not published.
`build_pack.py` always builds both engines' files, and the naming layer's
gate (`gate.py`) runs the ONNX checks too. The scorer caches each engine's
run by its models and photos, so a pack that changes only its naming files
is gated again in minutes; a full ONNX run is needed only when a model
changes. The naming layer's check that a trained pack carries exactly the
baseline's files (`confirm_same_base`) must keep working once the baseline
lists ONNX files.

### 7. The phone and the PCs, by hand

The Dart pipeline is tested in CI. What only a device shows is checked by
hand on the maintainer's Pixel 6a, a Windows PC and a Linux PC:

- the download, install and first load;
- a photo's suggestions; a rotated photo's boxes in the right place;
- on the 6a and Windows, a portrait and a landscape video scanned and
  labelled, live naming, and a scan stopping when the app goes to the
  background (6a);
- the 6a's memory run (section 5);
- on a Windows PC with a GPU: which engine ran (a vendor engine on Windows 11
  24H2 and later, DirectML otherwise), the vendor engine fetched as part of
  the Download, and the fall back to the processor when the GPU engine is
  made to fail; the comparison of section 2a, for information;
- on Windows 10, that DirectML and the processor still work.

**Run in CI instead (D3, 2026-11-22).** With no Windows or Linux PC to hand,
the maintainer chose GitHub's hosted runners. On both, the download,
install, load, photos and rotated photos passed, and the two builds gave
the same detections; Windows scanned both clips, and Linux refused video
as designed. The runners have no GPU, so the models ran on the processor,
and nothing above that needs a GPU or Windows 10 has been checked. One
open point: on Linux the app kept its 3.8 GB after the models were
unloaded. Figures in
[the Windows and Linux findings](../findings/2026-11-22-marine-life-windows-linux-ci.md).

## Order of work

**(proposed)**

1. The small adoption pull request (section 4), in this repository.
2. The engine pull request, in this repository, with the three platforms
   behind `MARINE_LIFE_ID_ONNX` (off by default). Everything in "The parts".
   It starts with the Windows ML spike of section 2a, since its result can
   change the Windows part.
3. The pack pull request, in submersion-app/species-pack: the ONNX
   conversion, the scorer's engine option, the ONNX checks in the naming
   layer's gate, and the x64 comparison.
4. The gate run, from the engine branch, and the 6a measurement, from a
   measurement build of it. The floor is set from the result.
5. With the maintainer's go, the ONNX files are published into the live
   pack's release. Then a small change makes `MARINE_LIFE_ID_ONNX` default to
   true, with the floor from step 4.

## Testing

Tests are written first. Run only the test files written or changed, by path.

- **Pure Dart pipeline:** each detector's reading of raw outputs (computed
  test vectors, not hand-typed), the letterbox, suppression, the merge on
  `boxes_test.py`'s cases, padding and clipping, both crop fits,
  normalisation, the embedding length check, the thumbnail size.
- **Real ONNX Runtime in CI:** a tiny ONNX model of known output, loaded and
  run through the bindings and the build hook's library on the Linux test
  runner, so a broken binding or a missing library fails CI.
- **Engine:** `analyze` with path and with bytes; decode failure;
  `not_loaded` after unload and after memory pressure; availability on each
  platform, below the floor, with `MARINE_LIFE_ID_IGNORE_FLOOR`, and on
  32-bit Android.
- **Linux and video:** the service queues no video on Linux; a Find species
  run passes over videos without counting them as failed; the engine's video
  calls fail with `unsupported`.
- **Native library checks:** the Android check requires ONNX Runtime on
  arm64-v8a and x86_64 only, with tests beside the script, as it has today.
- **Video:** `detectVideo` and `embedMoments` against a fake frame reader:
  sampling, chunk ends, `not_foreground`, `too_hot`, a reader failing part
  way.
- **Windows engine choice:** against a fake catalogue: engines registered
  when ready, the vendor engine fetched only during the Download, a failed
  fetch leaving the Download whole, and the fall back from a failing GPU
  engine to DirectML and then the processor.
- **Frame readers:** the channel contract, with mock handlers restored in
  teardown. The Kotlin and C++ themselves are checked by hand (section 7).
- **Pack:** file selection for `onnx`; `supportsEngine`; adoption ignoring
  other engines' files, and still refusing a changed file of this engine.
- **Backup rules:** a test that the Android rules files exclude
  `species_id/pack/` and nothing else.
- **Flag:** the three platforms on only with `MARINE_LIFE_ID_ONNX`, off on
  the web, and `MARINE_LIFE_ID=false` still turning it off everywhere.
- **Widgets:** the Linux wording; nothing else on screen changes.
- **Pack repository:** the conversion checks, the scorer's engine option and
  the gate's four checks, with Python tests beside them.

## Screenshots for the pull request

Light and dark where colours differ; phone and desktop widths where layout
differs.

- **After only**, since these platforms have never shown the feature: the
  settings page on Android (not downloaded, downloading, installed), a
  photo's suggestions on Android and Windows, a labelled video on Android and
  Windows, and the Linux settings page with its photos-only wording.

## Left to the builder

- Internal names, file layout and provider shapes.
- The pinned ONNX Runtime version, the operator set, and how the hook fetches
  each platform's library.
- The resampling filters, and whether models are widened to 32-bit at load,
  both judged by the gate (the filters settled by D1, under the detectors
  above).
- ONNX Runtime's thread counts and session options.
- Whether the worker calls the frame channel directly.
- Pass 1's decoder on Android (`MediaCodec` is proposed; anything that
  decodes in order and stays well under the detectors' time will do).
- The Android cut-off value for a 6 GB floor, if the 6a passes (not
  needed: it failed).
- How the scorer builds or calls the scoring runner, and how it finds ONNX
  Runtime's macOS library.
- How the measurement build reaches the 6a as an update.
- How Windows ML is deployed with the Windows build, and the exact order in
  which ONNX Runtime is asked to prefer devices.
- Exact wording of the four Linux strings and the Windows download note, in
  all 11 languages.

## Calls made by the designer, for the maintainer to check

1. Linux gets photos only: the service, Find species runs and the engine all
   pass over videos there, and four settings strings say "photos". The
   review and auto-apply strings stay as they are.
2. Windows and Linux PCs need 8 GB, with iPhone's 6.5 GiB cut-off.
3. (Decided since: the Pixel 6a is measured, and Android launches at 6 GB if
   it passes and 8 GB if not.) What counts as passing: the app never killed,
   and Android never reporting low memory, while identification runs.
4. The floor is lifted by a build define for the measurement build, not by
   debug mode as first proposed, so no diver can get past it with five taps.
   The build reaches the 6a as an update, never by uninstalling.
5. The three platforms stay behind a second build define,
   `MARINE_LIFE_ID_ONNX`, until the pack carries ONNX files and the floor is
   measured.
6. The accuracy gate's four checks, with the bars never changed to make it
   pass, plus a comparison on an x64 machine.
7. The ONNX files are added to the live pack under the same pack version, so
   Apple devices download nothing.
8. `adoptableFrom` compares only the device's own engine's files, in its own
   small pull request first.
9. Android gains backup rules that leave the pack out of Auto Backup.
10. Video work on Android stops in the background and on a hot phone,
    checked between frames as well as when a call starts; PCs check neither.
11. Find species runs on Android and Windows include videos, pausing on heat
    and in the background as runs already do.
12. The frame readers use channels of their own, separate from the Swift
    channel.
13. ONNX Runtime arrives through a build hook in `submersion_vision`, fetched
    from its official releases (Windows ML's package on Windows) and checked
    against pinned hashes. The Mac app carries none; Mac tests and the
    scoring runner load it from a path.
14. A Windows vendor engine is fetched only as part of the diver's Download,
    and the confirmation says so; a failed fetch leaves the PC on DirectML or
    the processor.
15. On Windows a failing GPU engine falls back to DirectML, then the
    processor.
16. Android and Linux use the ONNX Runtime version that Windows ML ships.
17. The Windows part starts with a spike proving Windows ML's catalogue works
    in the app as it is packaged today; if it cannot, DirectML through plain
    ONNX Runtime is the fallback, with the maintainer's say.

## Still open

- On Linux the app holds about 3 GB after it frees the models, until it
  quits (D3 run, 2026-11-22). Whether to look into it is the maintainer's
  call; see
  [the Windows and Linux findings](../findings/2026-11-22-marine-life-windows-linux-ci.md#open-linux-keeps-the-memory-after-unloading).

## Risks

- **Phone speed.** On the 6a's processor, a photo may take several seconds
  and video will run well behind playback. The decision is to accept that.
  The 6a run gave no measured figure (see section 5), so phone speed is
  still unmeasured.
- **Phone memory.** The 1.5 to 2.5 GB peak is an estimate. Android's limit is
  the phone's whole memory, shared with whatever else is open.
- **Load time.** Creating a session for a 600 MB model on a phone may take
  many seconds the first time after each launch.
- **App size.** ONNX Runtime adds roughly 10 to 20 MB to each platform's app
  (an estimate); the GitHub APK, which carries every Android ABI, grows the
  most.
- **Decoder parity.** The gate assumes Flutter decodes a JPEG to the same
  pixels on a Mac as on Android and Windows (the same codec library on each).
  A check on a few photos confirms it.
- **The build hook** fetches binaries at build time, as sqlite3's does; a
  build without network access fails, as it already does for sqlite3.
- **Heat and battery** while a video stays open on a phone. The thermal stop
  limits it; nothing else does.
- **Unchecked Windows engines.** A vendor engine or DirectML may name a fish
  differently from Core ML, and Windows Update can replace a vendor engine
  without the app changing. Accepted by the maintainer, as Core ML's GPU and
  Neural Engine are trusted across Apple chips and OS updates.
- **Windows ML in an unpackaged app.** Microsoft documents Windows ML mainly
  for packaged apps; whether its catalogue works from the app as packaged
  today, and what the Windows App SDK adds to the installer, is unproven. The
  spike in section 2a settles it first; if it cannot be made to work, the
  fallback is DirectML through plain ONNX Runtime, which needs the
  maintainer's say.
- **Windows download size.** Windows ML's package carries DirectML and its
  own library besides ONNX Runtime, so the Windows app grows more than the
  others (tens of megabytes; an estimate), and a vendor engine adds its own
  download inside the diver's Download.
