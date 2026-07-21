# Video Transcoding Phase B1 — Transcoder Package, Linux Engine, Pipeline Integration

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the `submersion_transcoder` package with the pure-Dart Linux (system ffmpeg) engine and integrate video transcoding into the upload pipeline — the first platform where a non-`Original` video level actually compresses.

**Architecture:** A pure-Dart package (`packages/submersion_transcoder`) defines app-agnostic DTOs (`VideoProbe`, `TranscodeTarget`), a `TranscodeEngine` seam, and `LinuxFfmpegEngine` (ffmpeg/ffprobe on PATH via an injectable process runner). The app-side `PlatformVideoTranscoder` adapter maps `MediaUploadQuality` presets to engine calls and applies the ceiling rule. The pipeline gains deterministic transcode staging (`<cacheRoot>/transcode/<hash>_<level>.mp4`, tmp+rename, delete-on-markDone) so a clip is never re-transcoded because an upload failed.

**Tech Stack:** Dart (`dart:io` `Process`), ffmpeg/ffprobe CLI (system-installed, Linux), Drift/Riverpod app patterns from Phase A.

**Spec:** `docs/superpowers/specs/2026-07-21-video-transcoding-phase-b-design.md` (commit 09c8a47ebde). Scope = spec delivery-order steps 1–2 ONLY; darwin/Android/Windows engines are later plans.

## Global Constraints

- Branch `worktree-media-upload-quality-phase-b` (worktree `.claude/worktrees/media-upload-quality-phase-b`), stacked on Phase A. Worktree is build-ready.
- Presets (spec §6): high = 1080p / 8000 kbps video / 128 kbps audio; balanced = 720p / 4000 / 128; small = 480p / 1800 / 96. Output contract: H.264 + AAC `.mp4`, faststart, never upscale.
- Ceiling rule (spec §7): return null (upload original) when `sourceHeight <= preset.maxHeight` AND `sourceOverallBitrateKbps <= 1.25 * (preset.videoBitrateKbps + preset.audioBitrateKbps)`. Probe failure → null.
- Staging (spec §8): deterministic path `<MediaCacheStore root>/transcode/<contentHash>_<level>.mp4`; engines write `<path>.tmp` then rename; an existing final file is always complete; deleted only on markDone (all same-hash siblings); upload failure preserves it. Photo renditions get cleaned on attempt failure too (Phase A leak fix).
- Engine failure semantics (spec §13): unavailable engine / probe failure / unsupported input → null (original uploads); genuine transcode failure (non-zero ffmpeg exit) → throw `TranscodeException` → queue markFailed/backoff.
- `dart format .` clean; `flutter analyze` clean (info lints fatal); ≥ 90% patch coverage on media-store work.
- `*.g.dart` is gitignored (never commit); `lib/l10n/arb/app_localizations*.dart` IS tracked (commit after `flutter gen-l10n`). New l10n keys go into ALL 11 arb files (`en` template + ar de es fr he hu it nl pt zh).
- All new tests live under the app's `test/` tree (CI shards collect only there); package code is imported via path dependency.
- **Spec deviation (deliberate):** spec §14's "checked-in ~50 KB fixture video" is replaced by a smoke test that synthesizes its input with ffmpeg's `lavfi testsrc` — the test already requires ffmpeg (runtime-skips without it), so no binary fixture needs committing. Task 9 updates the spec text.

## Test Harness Reference

Reuse the **Pipeline Harness** exactly as in Phase A (`test/features/media_store/media_upload_pipeline_quality_test.dart:31-50`): `SharedPreferences.setMockInitialValues({})`, `setUpTestDatabase()`, in-memory `LocalCacheDatabase`, temp-dir `MediaCacheStore`, `InMemoryMediaObjectStore`, `MediaTransferQueueRepository(database: cacheDb)`, `FakeLocalFileResolver` registered for `MediaSourceType.localFile`.

Commands: single file `flutter test <path>`; media suite `flutter test test/features/media_store/ test/features/media/data/`; format `dart format .`; analyze `flutter analyze`.

---

### Task 1: Package scaffold — DTOs + ffprobe parser

**Files:**
- Create: `packages/submersion_transcoder/pubspec.yaml`
- Create: `packages/submersion_transcoder/lib/submersion_transcoder.dart`
- Create: `packages/submersion_transcoder/lib/src/transcode_target.dart`
- Create: `packages/submersion_transcoder/lib/src/video_probe.dart`
- Modify: `pubspec.yaml` (app; add path dependency)
- Test: `test/features/media_store/video_probe_test.dart`

**Interfaces:**
- Produces: `class TranscodeTarget { final int maxHeight; final int videoBitrateKbps; final int audioBitrateKbps; const TranscodeTarget({required ...}); }`; `class VideoProbe { final int width; final int height; final int durationMs; final int overallBitrateKbps; const VideoProbe({required ...}); }`; `VideoProbe? parseFfprobeJson(String json)` (null on malformed/missing video stream). Package import: `package:submersion_transcoder/submersion_transcoder.dart`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media_store/video_probe_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

const _ffprobeJson = '''
{
  "streams": [
    {"codec_type": "audio", "codec_name": "aac"},
    {"codec_type": "video", "codec_name": "h264", "width": 1920, "height": 1080}
  ],
  "format": {"duration": "12.480000", "bit_rate": "9600000"}
}
''';

void main() {
  test('parses dimensions, duration, and overall bitrate', () {
    final probe = parseFfprobeJson(_ffprobeJson)!;
    expect(probe.width, 1920);
    expect(probe.height, 1080);
    expect(probe.durationMs, 12480);
    expect(probe.overallBitrateKbps, 9600);
  });

  test('returns null when no video stream exists', () {
    expect(
      parseFfprobeJson('{"streams": [], "format": {"duration": "1"}}'),
      isNull,
    );
  });

  test('returns null on malformed json', () {
    expect(parseFfprobeJson('not json'), isNull);
  });
}
```

- [ ] **Step 2: Create the package + app dependency**

`packages/submersion_transcoder/pubspec.yaml`:
```yaml
name: submersion_transcoder
description: Video transcoding engines for Submersion's adjustable upload quality.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.10.0
```

App `pubspec.yaml` — add beside the existing path dependency for `libdivecomputer_plugin` (search `path: packages/` for the block; keep alphabetical order within the dependencies map):
```yaml
  submersion_transcoder:
    path: packages/submersion_transcoder
```

`packages/submersion_transcoder/lib/submersion_transcoder.dart`:
```dart
export 'src/transcode_target.dart';
export 'src/video_probe.dart';
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter pub get && flutter test test/features/media_store/video_probe_test.dart`
Expected: FAIL (parseFfprobeJson undefined).

- [ ] **Step 4: Write minimal implementation**

`packages/submersion_transcoder/lib/src/transcode_target.dart`:
```dart
/// Encoder-agnostic rendition target: a resolution ceiling and bitrates.
/// The app maps its quality presets onto this; engines never see app types.
class TranscodeTarget {
  const TranscodeTarget({
    required this.maxHeight,
    required this.videoBitrateKbps,
    required this.audioBitrateKbps,
  });
  final int maxHeight;
  final int videoBitrateKbps;
  final int audioBitrateKbps;
}
```

`packages/submersion_transcoder/lib/src/video_probe.dart`:
```dart
import 'dart:convert';

/// Source-video metadata used by the ceiling rule and progress reporting.
class VideoProbe {
  const VideoProbe({
    required this.width,
    required this.height,
    required this.durationMs,
    required this.overallBitrateKbps,
  });
  final int width;
  final int height;
  final int durationMs;
  final int overallBitrateKbps;
}

/// Parses `ffprobe -print_format json -show_format -show_streams` output.
/// Returns null for anything that is not a probeable video (malformed JSON,
/// no video stream, missing dimensions) — the caller uploads the original.
VideoProbe? parseFfprobeJson(String json) {
  try {
    final root = jsonDecode(json) as Map<String, dynamic>;
    final streams = (root['streams'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final video = streams.firstWhere(
      (s) => s['codec_type'] == 'video',
      orElse: () => const {},
    );
    final width = video['width'] as int?;
    final height = video['height'] as int?;
    if (width == null || height == null) return null;
    final format = root['format'] as Map<String, dynamic>? ?? const {};
    final durationSec = double.tryParse('${format['duration']}') ?? 0;
    final bitRateBps = int.tryParse('${format['bit_rate']}') ?? 0;
    return VideoProbe(
      width: width,
      height: height,
      durationMs: (durationSec * 1000).round(),
      overallBitrateKbps: (bitRateBps / 1000).round(),
    );
  } on FormatException {
    return null;
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/media_store/video_probe_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/submersion_transcoder pubspec.yaml test/features/media_store/video_probe_test.dart
git commit -m "feat(transcoder): scaffold submersion_transcoder with probe DTOs"
```

---

### Task 2: Process-runner seam + `LinuxFfmpegEngine` + platform dispatcher

**Files:**
- Create: `packages/submersion_transcoder/lib/src/process_runner.dart`
- Create: `packages/submersion_transcoder/lib/src/transcode_engine.dart`
- Create: `packages/submersion_transcoder/lib/src/linux_ffmpeg_engine.dart`
- Modify: `packages/submersion_transcoder/lib/submersion_transcoder.dart` (exports)
- Test: `test/features/media_store/linux_ffmpeg_engine_test.dart`

**Interfaces:**
- Produces:
  - `class ProcessRunResult { final int exitCode; final String stdout; final String stderr; }`
  - `abstract class TranscoderProcessRunner { Future<ProcessRunResult> run(String executable, List<String> arguments); Future<int> stream(String executable, List<String> arguments, {void Function(String line)? onStdoutLine}) }` + `class SystemProcessRunner implements TranscoderProcessRunner` (dart:io).
  - `class TranscodeException implements Exception { final String message; }`
  - `abstract class TranscodeEngine { Future<bool> isAvailable(); Future<VideoProbe?> probe(File source); Future<void> transcode({required File source, required File output, required TranscodeTarget target, VideoProbe? probe, void Function(double fraction)? onProgress}); }` — `transcode` writes `<output>.tmp` then renames; throws `TranscodeException` on engine failure.
  - `class LinuxFfmpegEngine implements TranscodeEngine` with ctor `LinuxFfmpegEngine({TranscoderProcessRunner? runner})`.
  - `TranscodeEngine? engineForThisPlatform()` — `LinuxFfmpegEngine()` on Linux, null elsewhere (B1).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media_store/linux_ffmpeg_engine_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

class _FakeRunner implements TranscoderProcessRunner {
  final Map<String, ProcessRunResult> runResults = {};
  final List<(String, List<String>)> runCalls = [];
  final List<(String, List<String>)> streamCalls = [];
  int streamExitCode = 0;
  List<String> streamStdoutLines = [];
  void Function(String exe, List<String> args)? onStream;

  @override
  Future<ProcessRunResult> run(String executable, List<String> arguments) async {
    runCalls.add((executable, arguments));
    return runResults[executable] ??
        ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<int> stream(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  }) async {
    streamCalls.add((executable, arguments));
    onStream?.call(executable, arguments);
    for (final line in streamStdoutLines) {
      onStdoutLine?.call(line);
    }
    return streamExitCode;
  }
}

void main() {
  late _FakeRunner runner;
  late LinuxFfmpegEngine engine;
  late Directory dir;

  setUp(() async {
    runner = _FakeRunner();
    engine = LinuxFfmpegEngine(runner: runner);
    dir = await Directory.systemTemp.createTemp('lfe_test');
  });
  tearDown(() => dir.delete(recursive: true));

  const target = TranscodeTarget(
    maxHeight: 720,
    videoBitrateKbps: 4000,
    audioBitrateKbps: 128,
  );

  test('isAvailable requires both ffmpeg and ffprobe', () async {
    expect(await engine.isAvailable(), isTrue);
    runner.runResults['ffprobe'] =
        ProcessRunResult(exitCode: 127, stdout: '', stderr: 'not found');
    expect(await engine.isAvailable(), isFalse);
  });

  test('transcode builds the spec ffmpeg args and renames tmp to output',
      () async {
    final source = File('${dir.path}/in.mov');
    final output = File('${dir.path}/out.mp4');
    // The fake writes the tmp the way a real ffmpeg run would.
    runner.onStream = (exe, args) {
      File(args.last).writeAsBytesSync([1, 2, 3]);
    };
    await engine.transcode(source: source, output: output, target: target);

    final (exe, args) = runner.streamCalls.single;
    expect(exe, 'ffmpeg');
    expect(args.last, '${output.path}.tmp');
    expect(args, containsAllInOrder(['-c:v', 'libx264', '-b:v', '4000k']));
    expect(args, containsAllInOrder(['-c:a', 'aac', '-b:a', '128k']));
    expect(args, containsAllInOrder(['-movflags', '+faststart']));
    expect(args.join(' '), contains("scale=w=-2:h='min(720,ih)'"));
    expect(await output.exists(), isTrue);
    expect(await File('${output.path}.tmp').exists(), isFalse);
  });

  test('non-zero exit throws TranscodeException and leaves no tmp', () async {
    final output = File('${dir.path}/out.mp4');
    runner.streamExitCode = 1;
    await expectLater(
      engine.transcode(
        source: File('${dir.path}/in.mov'),
        output: output,
        target: target,
      ),
      throwsA(isA<TranscodeException>()),
    );
    expect(await File('${output.path}.tmp').exists(), isFalse);
    expect(await output.exists(), isFalse);
  });

  test('progress fractions derive from out_time_us over probe duration',
      () async {
    final fractions = <double>[];
    runner.streamStdoutLines = [
      'out_time_us=5000000',
      'progress=continue',
      'out_time_us=10000000',
      'progress=end',
    ];
    runner.onStream = (exe, args) {
      File(args.last).writeAsBytesSync([1]);
    };
    await engine.transcode(
      source: File('${dir.path}/in.mov'),
      output: File('${dir.path}/out.mp4'),
      target: target,
      probe: const VideoProbe(
        width: 1280, height: 720, durationMs: 10000, overallBitrateKbps: 9000,
      ),
      onProgress: fractions.add,
    );
    expect(fractions, [0.5, 1.0, 1.0]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/linux_ffmpeg_engine_test.dart`
Expected: FAIL (types undefined).

- [ ] **Step 3: Write minimal implementation**

`packages/submersion_transcoder/lib/src/process_runner.dart`:
```dart
import 'dart:convert';
import 'dart:io';

/// Completed-process result (a dart:io-free mirror of ProcessResult so
/// fakes need no dart:io types).
class ProcessRunResult {
  const ProcessRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
  final int exitCode;
  final String stdout;
  final String stderr;
}

/// Injectable seam over dart:io Process so engines are unit-testable
/// without external binaries.
abstract class TranscoderProcessRunner {
  Future<ProcessRunResult> run(String executable, List<String> arguments);

  /// Starts the process, forwarding each stdout line, and returns the exit
  /// code. Stderr is collected internally by implementations for error text.
  Future<int> stream(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  });
}

class SystemProcessRunner implements TranscoderProcessRunner {
  /// Stderr of the last [stream] call, for error messages.
  String lastStderr = '';

  @override
  Future<ProcessRunResult> run(String executable, List<String> arguments) async {
    try {
      final result = await Process.run(executable, arguments);
      return ProcessRunResult(
        exitCode: result.exitCode,
        stdout: result.stdout as String,
        stderr: result.stderr as String,
      );
    } on ProcessException catch (e) {
      return ProcessRunResult(exitCode: 127, stdout: '', stderr: e.message);
    }
  }

  @override
  Future<int> stream(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  }) async {
    final Process process;
    try {
      process = await Process.start(executable, arguments);
    } on ProcessException catch (e) {
      lastStderr = e.message;
      return 127;
    }
    final stderrBuf = StringBuffer();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => onStdoutLine?.call(line));
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach(stderrBuf.write);
    final code = await process.exitCode;
    await stdoutDone;
    await stderrDone;
    lastStderr = stderrBuf.toString();
    return code;
  }
}
```

`packages/submersion_transcoder/lib/src/transcode_engine.dart`:
```dart
import 'dart:io';

import 'package:submersion_transcoder/src/linux_ffmpeg_engine.dart';
import 'package:submersion_transcoder/src/transcode_target.dart';
import 'package:submersion_transcoder/src/video_probe.dart';

/// A genuine engine failure (as opposed to "input this engine cannot
/// handle", which is reported as a null probe). Callers surface it to the
/// transfer queue's normal retry/backoff.
class TranscodeException implements Exception {
  const TranscodeException(this.message);
  final String message;
  @override
  String toString() => 'TranscodeException: $message';
}

/// One platform transcoder. Contract:
/// - [transcode] writes to '<output>.tmp' (overwriting any debris) and
///   renames to [output] only on success, so an existing [output] is always
///   a complete rendition.
/// - Throws [TranscodeException] on engine failure; never leaves a .tmp.
abstract class TranscodeEngine {
  Future<bool> isAvailable();
  Future<VideoProbe?> probe(File source);
  Future<void> transcode({
    required File source,
    required File output,
    required TranscodeTarget target,
    VideoProbe? probe,
    void Function(double fraction)? onProgress,
  });
}

/// The engine for the current platform, or null when none exists yet.
/// B1 ships Linux only; darwin/Android/Windows arrive in later plans.
TranscodeEngine? engineForThisPlatform() =>
    Platform.isLinux ? LinuxFfmpegEngine() : null;
```

`packages/submersion_transcoder/lib/src/linux_ffmpeg_engine.dart`:
```dart
import 'dart:io';

import 'package:submersion_transcoder/src/process_runner.dart';
import 'package:submersion_transcoder/src/transcode_engine.dart';
import 'package:submersion_transcoder/src/transcode_target.dart';
import 'package:submersion_transcoder/src/video_probe.dart';

/// System-ffmpeg engine (spec section 10, Linux): shells out to ffmpeg and
/// ffprobe found on PATH. Zero vendored binaries; absence means unavailable
/// and the caller uploads originals.
class LinuxFfmpegEngine implements TranscodeEngine {
  LinuxFfmpegEngine({TranscoderProcessRunner? runner})
    : _runner = runner ?? SystemProcessRunner();

  final TranscoderProcessRunner _runner;

  @override
  Future<bool> isAvailable() async {
    final ffmpeg = await _runner.run('ffmpeg', const ['-version']);
    if (ffmpeg.exitCode != 0) return false;
    final ffprobe = await _runner.run('ffprobe', const ['-version']);
    return ffprobe.exitCode == 0;
  }

  @override
  Future<VideoProbe?> probe(File source) async {
    final result = await _runner.run('ffprobe', [
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      source.path,
    ]);
    if (result.exitCode != 0) return null;
    return parseFfprobeJson(result.stdout);
  }

  @override
  Future<void> transcode({
    required File source,
    required File output,
    required TranscodeTarget target,
    VideoProbe? probe,
    void Function(double fraction)? onProgress,
  }) async {
    final tmp = File('${output.path}.tmp');
    final durationMs = probe?.durationMs ?? 0;
    final exitCode = await _runner.stream(
      'ffmpeg',
      [
        '-y',
        '-i',
        source.path,
        '-c:v',
        'libx264',
        '-b:v',
        '${target.videoBitrateKbps}k',
        '-vf',
        "scale=w=-2:h='min(${target.maxHeight},ih)'",
        '-c:a',
        'aac',
        '-b:a',
        '${target.audioBitrateKbps}k',
        '-movflags',
        '+faststart',
        '-progress',
        'pipe:1',
        '-nostats',
        tmp.path,
      ],
      onStdoutLine: (line) {
        if (onProgress == null || durationMs <= 0) return;
        if (line.startsWith('out_time_us=')) {
          final us = int.tryParse(line.substring('out_time_us='.length));
          if (us != null) {
            onProgress((us / 1000 / durationMs).clamp(0.0, 1.0));
          }
        } else if (line == 'progress=end') {
          onProgress(1.0);
        }
      },
    );
    if (exitCode != 0) {
      try {
        await tmp.delete();
      } on FileSystemException {
        // Nothing to clean.
      }
      final stderr = _runner is SystemProcessRunner
          ? (_runner as SystemProcessRunner).lastStderr
          : '';
      throw TranscodeException(
        'ffmpeg exited $exitCode${stderr.isEmpty ? '' : ': $stderr'}',
      );
    }
    await tmp.rename(output.path);
  }
}
```

Update `packages/submersion_transcoder/lib/submersion_transcoder.dart`:
```dart
export 'src/linux_ffmpeg_engine.dart';
export 'src/process_runner.dart';
export 'src/transcode_engine.dart';
export 'src/transcode_target.dart';
export 'src/video_probe.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/linux_ffmpeg_engine_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/submersion_transcoder test/features/media_store/linux_ffmpeg_engine_test.dart
git commit -m "feat(transcoder): Linux ffmpeg engine with process-runner seam"
```

---

### Task 3: Bitrate-based presets + ceiling rule

**Files:**
- Modify: `lib/features/media_store/data/quality_presets.dart`
- Test: `test/features/media_store/quality_presets_test.dart` (update in place)

**Interfaces:**
- Produces: `VideoQualityPreset { final int maxHeight; final int videoBitrateKbps; final int audioBitrateKbps; }` (the `crf` field is REMOVED — verified: no consumer outside this file and its test); `bool videoWithinCeiling(VideoProbe probe, VideoQualityPreset preset)`.
- Consumes: `VideoProbe` from Task 1.

- [ ] **Step 1: Update the test (write failing)** — replace the video expectations in `test/features/media_store/quality_presets_test.dart` and add ceiling tests:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media_store/data/quality_presets.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

void main() {
  test('original has no preset', () {
    expect(photoPresetFor(MediaUploadQuality.original), isNull);
    expect(videoPresetFor(MediaUploadQuality.original), isNull);
  });

  test('photo presets shrink with level', () {
    expect(photoPresetFor(MediaUploadQuality.high)!.maxDimension, 3072);
    expect(photoPresetFor(MediaUploadQuality.balanced)!.maxDimension, 2048);
    expect(photoPresetFor(MediaUploadQuality.small)!.maxDimension, 1280);
    expect(photoPresetFor(MediaUploadQuality.small)!.jpegQuality, 75);
  });

  test('video presets are bitrate-based', () {
    final high = videoPresetFor(MediaUploadQuality.high)!;
    expect(high.maxHeight, 1080);
    expect(high.videoBitrateKbps, 8000);
    expect(high.audioBitrateKbps, 128);
    expect(videoPresetFor(MediaUploadQuality.balanced)!.videoBitrateKbps, 4000);
    final small = videoPresetFor(MediaUploadQuality.small)!;
    expect(small.videoBitrateKbps, 1800);
    expect(small.audioBitrateKbps, 96);
  });

  test('ceiling: small-and-cheap source is within ceiling', () {
    final preset = videoPresetFor(MediaUploadQuality.balanced)!;
    const probe = VideoProbe(
      width: 1280, height: 720, durationMs: 10000, overallBitrateKbps: 3000);
    expect(videoWithinCeiling(probe, preset), isTrue);
  });

  test('ceiling: high-bitrate source at target resolution still compresses',
      () {
    final preset = videoPresetFor(MediaUploadQuality.balanced)!;
    const probe = VideoProbe(
      width: 1280, height: 720, durationMs: 10000, overallBitrateKbps: 20000);
    expect(videoWithinCeiling(probe, preset), isFalse);
  });

  test('ceiling: larger resolution always compresses', () {
    final preset = videoPresetFor(MediaUploadQuality.balanced)!;
    const probe = VideoProbe(
      width: 3840, height: 2160, durationMs: 10000, overallBitrateKbps: 3000);
    expect(videoWithinCeiling(probe, preset), isFalse);
  });

  test('enum round-trips through name', () {
    expect(
      MediaUploadQuality.values.byName('balanced'),
      MediaUploadQuality.balanced,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/quality_presets_test.dart`
Expected: FAIL (no `videoBitrateKbps`, no `videoWithinCeiling`).

- [ ] **Step 3: Write minimal implementation** — in `quality_presets.dart`, add the import, replace `VideoQualityPreset` and the `_video` map, append `videoWithinCeiling`:

```dart
import 'package:submersion_transcoder/submersion_transcoder.dart';
```
```dart
/// Video rendition target (spec section 6): a resolution ceiling and
/// average bitrates. Bitrate-based (not CRF) because the native engines
/// (VideoToolbox, MediaCodec, Media Foundation) speak bitrate.
class VideoQualityPreset {
  const VideoQualityPreset({
    required this.maxHeight,
    required this.videoBitrateKbps,
    required this.audioBitrateKbps,
  });
  final int maxHeight;
  final int videoBitrateKbps;
  final int audioBitrateKbps;
}

const Map<MediaUploadQuality, VideoQualityPreset> _video = {
  MediaUploadQuality.high: VideoQualityPreset(
    maxHeight: 1080,
    videoBitrateKbps: 8000,
    audioBitrateKbps: 128,
  ),
  MediaUploadQuality.balanced: VideoQualityPreset(
    maxHeight: 720,
    videoBitrateKbps: 4000,
    audioBitrateKbps: 128,
  ),
  MediaUploadQuality.small: VideoQualityPreset(
    maxHeight: 480,
    videoBitrateKbps: 1800,
    audioBitrateKbps: 96,
  ),
};

/// Ceiling rule (spec section 7): true when the source is already within
/// the level's budget, so the original should upload untouched. Resolution
/// alone is insufficient (a 20 Mbps 720p clip should still compress); the
/// 1.25x headroom avoids pointless re-encodes and generation loss.
bool videoWithinCeiling(VideoProbe probe, VideoQualityPreset preset) {
  final budgetKbps =
      1.25 * (preset.videoBitrateKbps + preset.audioBitrateKbps);
  return probe.height <= preset.maxHeight &&
      probe.overallBitrateKbps <= budgetKbps;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/quality_presets_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/data/quality_presets.dart test/features/media_store/quality_presets_test.dart
git commit -m "feat(media-store): bitrate-based video presets + ceiling rule"
```

---

### Task 4: `MediaCacheStore` — deterministic transcode staging

**Files:**
- Modify: `lib/features/media_store/data/media_cache_store.dart`
- Test: `test/features/media_store/media_cache_store_transcode_test.dart`

**Interfaces:**
- Produces: `Future<File> transcodeFile(String contentHash, String levelName)` → `<root>/transcode/<hash>_<level>.mp4` (dir created); `Future<void> deleteTranscodeArtifacts(String contentHash)` → removes every file in `transcode/` whose basename starts with `<hash>_` (all levels + `.tmp` debris; best-effort).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media_store/media_cache_store_transcode_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('cache_transcode');
    cache = MediaCacheStore(database: db, root: root);
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('transcodeFile is deterministic per hash and level', () async {
    final a = await cache.transcodeFile('h1', 'balanced');
    final b = await cache.transcodeFile('h1', 'balanced');
    expect(a.path, b.path);
    expect(a.path, endsWith('transcode/h1_balanced.mp4'));
    expect(await a.parent.exists(), isTrue);
  });

  test('deleteTranscodeArtifacts removes all levels and tmp debris', () async {
    final balanced = await cache.transcodeFile('h1', 'balanced');
    await balanced.writeAsBytes([1]);
    final small = await cache.transcodeFile('h1', 'small');
    await small.writeAsBytes([2]);
    await File('${small.path}.tmp').writeAsBytes([3]);
    final other = await cache.transcodeFile('h2', 'small');
    await other.writeAsBytes([4]);

    await cache.deleteTranscodeArtifacts('h1');

    expect(await balanced.exists(), isFalse);
    expect(await small.exists(), isFalse);
    expect(await File('${small.path}.tmp').exists(), isFalse);
    expect(await other.exists(), isTrue, reason: 'other hashes untouched');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_cache_store_transcode_test.dart`
Expected: FAIL (`transcodeFile` undefined).

- [ ] **Step 3: Write minimal implementation** — append to `MediaCacheStore` (after `stagingFile()`):

```dart
  /// Deterministic transcode output path (spec section 8):
  /// <root>/transcode/<hash>_<level>.mp4. Engines write '<path>.tmp' and
  /// rename, so an existing file here is always a COMPLETE rendition; it
  /// survives upload retries and app restarts and is removed only via
  /// [deleteTranscodeArtifacts] on markDone.
  Future<File> transcodeFile(String contentHash, String levelName) async {
    final dir = Directory(p.join(_root.path, 'transcode'));
    await dir.create(recursive: true);
    return File(p.join(dir.path, '${contentHash}_$levelName.mp4'));
  }

  /// Removes every transcode artifact for [contentHash]: all levels'
  /// renditions plus any .tmp debris. Best-effort.
  Future<void> deleteTranscodeArtifacts(String contentHash) async {
    final dir = Directory(p.join(_root.path, 'transcode'));
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File &&
          p.basename(entity.path).startsWith('${contentHash}_')) {
        try {
          await entity.delete();
        } on FileSystemException {
          // Best-effort cleanup.
        }
      }
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/media_cache_store_transcode_test.dart` and `flutter test test/features/media_store/media_cache_store_rendition_test.dart` (no regression).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/data/media_cache_store.dart test/features/media_store/media_cache_store_transcode_test.dart
git commit -m "feat(media-store): deterministic transcode staging in cache store"
```

---

### Task 5: `VideoTranscoder` signature + pipeline transcode-once integration

**Files:**
- Modify: `lib/features/media_store/data/video_transcoder.dart`
- Modify: `lib/features/media_store/data/media_upload_pipeline.dart`
- Test: `test/features/media_store/media_upload_pipeline_video_test.dart`

**Interfaces:**
- Produces: `VideoTranscoder.transcode(MediaItem item, File source, MediaUploadQuality level, {required File output, void Function(double fraction)? onProgress})` (safe: Phase A shipped zero implementors); pipeline `_renditionFor(item, source, level, contentHash)` with video reuse of the deterministic file; success path deletes video artifacts via `deleteTranscodeArtifacts` (photos keep `_cleanupRendition`); failure path cleans photo renditions (Phase A leak fix) but preserves video renditions.
- Consumes: `transcodeFile`/`deleteTranscodeArtifacts` (Task 4).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media_store/media_upload_pipeline_video_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/media_store_policies.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/data/video_transcoder.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'support/fake_local_file_resolver.dart';
import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

class _FakeVideoTranscoder implements VideoTranscoder {
  int calls = 0;
  @override
  Future<CompressionResult?> transcode(
    MediaItem item,
    File source,
    MediaUploadQuality level, {
    required File output,
    void Function(double fraction)? onProgress,
  }) async {
    calls++;
    final tmp = File('${output.path}.tmp');
    await tmp.writeAsBytes([9, 9, 9, 9], flush: true);
    await tmp.rename(output.path);
    return CompressionResult(file: output, ext: 'mp4', sizeBytes: 4);
  }
}

void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late InMemoryMediaObjectStore fakeStore;
  late MediaCacheStore cache;
  late MediaTransferQueueRepository queue;
  late FakeLocalFileResolver resolver;
  late MediaSourceResolverRegistry registry;
  late _FakeVideoTranscoder transcoder;
  late MediaStorePolicies policies;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('pipeline_video');
    fakeStore = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: cacheDb, root: root);
    queue = MediaTransferQueueRepository(database: cacheDb);
    resolver = FakeLocalFileResolver();
    registry = MediaSourceResolverRegistry({
      MediaSourceType.localFile: resolver,
    });
    transcoder = _FakeVideoTranscoder();
    policies = MediaStorePolicies(prefs: await SharedPreferences.getInstance());
    await policies.setVideoUploadQuality(MediaUploadQuality.balanced);
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  MediaUploadPipeline pipeline() => MediaUploadPipeline(
    mediaRepository: mediaRepository,
    queue: queue,
    store: fakeStore,
    registry: registry,
    cache: cache,
    policies: policies,
    videoTranscoder: transcoder,
    now: () => DateTime(2026, 7, 21, 12),
  );

  MediaItem video(String id) => MediaItem(
    id: id,
    mediaType: MediaType.video,
    sourceType: MediaSourceType.localFile,
    originalFilename: 'clip.mp4',
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<File> sourceClip() async {
    final f = await cache.stagingFile();
    await f.writeAsBytes(List<int>.filled(4096, 5), flush: true);
    return f;
  }

  Future<MediaTransferQueueEntry> enqueue(String id) async {
    final rowId = await queue.enqueueUpload(mediaId: id);
    return (await queue.allForTesting()).firstWhere((e) => e.id == rowId);
  }

  test('compressed video uploads a transcoded rendition and cleans artifacts',
      () async {
    resolver.data = FileData(file: await sourceClip());
    await mediaRepository.createMedia(video('v1'));

    final outcome = await pipeline().process(await enqueue('v1'));

    expect(outcome, UploadOutcome.uploaded);
    expect(transcoder.calls, 1);
    expect(
      fakeStore.objects.keys.any(
        (k) => k.startsWith('smv1/renditions/') && k.endsWith('.mp4'),
      ),
      isTrue,
    );
    final got = await mediaRepository.getMediaById('v1');
    expect(got!.remoteCompressedUploadedAt, isNotNull);
    expect(got.remoteUploadedAt, isNull);
    // Artifacts removed on markDone.
    final transcodeDir = Directory('${root.path}/transcode');
    expect(
      await transcodeDir.exists() &&
          await transcodeDir.list().isEmpty == false,
      isFalse,
      reason: 'transcode dir empty after markDone',
    );
  });

  test('an existing deterministic rendition skips the transcoder', () async {
    resolver.data = FileData(file: await sourceClip());
    await mediaRepository.createMedia(video('v2'));

    // First pass transcodes and uploads.
    await pipeline().process(await enqueue('v2'));
    expect(transcoder.calls, 1);

    // Simulate a pre-existing rendition for a NEW item with identical bytes
    // (same hash): reset stamps by writing the deterministic file again.
    final got = await mediaRepository.getMediaById('v2');
    final hash = got!.contentHash!;
    final pre = await cache.transcodeFile(hash, 'balanced');
    await pre.writeAsBytes([9, 9, 9, 9], flush: true);
    await mediaRepository.clearRemoteCompressed('v2');
    fakeStore.objects.clear();

    await pipeline().process(await enqueue('v2'));

    expect(transcoder.calls, 1, reason: 'reused the persisted rendition');
    expect(
      fakeStore.objects.keys.any((k) => k.startsWith('smv1/renditions/')),
      isTrue,
    );
  });

  test('upload failure preserves the video rendition for retry', () async {
    resolver.data = FileData(file: await sourceClip());
    await mediaRepository.createMedia(video('v3'));
    fakeStore.failNextWith = Exception('network down'); // fails thumb head?
    // Thumb generation for a localFile video yields null (undecodable), so
    // the first store call IS the rendition head/put path.

    final outcome = await pipeline().process(await enqueue('v3'));

    expect(outcome, UploadOutcome.failed);
    final got = await mediaRepository.getMediaById('v3');
    final hash = got!.contentHash!;
    final persisted = await cache.transcodeFile(hash, 'balanced');
    expect(await persisted.exists(), isTrue, reason: 'kept for retry');

    // Retry succeeds WITHOUT re-transcoding.
    await queue.retry((await queue.allForTesting()).single.id);
    final entry = (await queue.allForTesting()).single;
    await pipeline().process(entry);
    expect(transcoder.calls, 1);
    expect(
      (await mediaRepository.getMediaById('v3'))!.remoteCompressedUploadedAt,
      isNotNull,
    );
  });

  test('photo rendition is cleaned up when the upload fails (leak fix)',
      () async {
    await policies.setPhotoUploadQuality(MediaUploadQuality.balanced);
    // Large decodable PNG so the ImageCompressor produces a rendition.
    final png = await cache.stagingFile();
    // 4000x3000 PNG via package:image is exercised in Phase A tests; a
    // stub compressor is unnecessary here — reuse the real one by giving
    // the resolver a real PNG.
    // (Import package:image as img at top of file.)
    await png.writeAsBytes(
      img.encodePng(img.Image(width: 4000, height: 3000)),
      flush: true,
    );
    resolver.data = FileData(file: png);
    // Make the thumbnail step produce nothing: otherwise failNextWith is
    // consumed by the thumb head() call, which the pipeline swallows by
    // design, and the rendition upload would then succeed.
    resolver.thumbnailData = const UnavailableData(
      kind: UnavailableKind.notFound,
    );
    await mediaRepository.createMedia(
      video('p1').copyWith(mediaType: MediaType.photo, originalFilename: 'a.png'),
    );
    fakeStore.failNextWith = Exception('network down');

    await pipeline().process(await enqueue('p1'));

    final staging = Directory('${root.path}/staging');
    final leftovers = await staging
        .list()
        .where((e) => e is File)
        .toList();
    // Only the materialized source may remain transiently deleted by the
    // pipeline finally-block; no rendition staging file survives.
    expect(leftovers, isEmpty, reason: 'no leaked rendition staging files');
  });
}
```

Note for the implementer: add `import 'package:image/image.dart' as img;` to the imports; the photo-leak test relies on the pipeline's `finally` deleting the materialized source and the new failure-path cleanup deleting the photo rendition, so the `staging/` dir ends empty.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_upload_pipeline_video_test.dart`
Expected: FAIL (transcode has no `output` parameter; artifacts not cleaned; photo rendition leaks).

- [ ] **Step 3: Update `video_transcoder.dart`**

```dart
import 'dart:io';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// Video transcoding seam. Implementations write the rendition to
/// '<output>.tmp' and rename to [output] on success (an existing [output]
/// is always complete), report progress as a 0..1 fraction when the engine
/// supports it, and throw on genuine engine failure. Returning null means
/// "upload the original instead" (engine unavailable, probe failure, or
/// the source is within the level's ceiling).
abstract class VideoTranscoder {
  Future<CompressionResult?> transcode(
    MediaItem item,
    File source,
    MediaUploadQuality level, {
    required File output,
    void Function(double fraction)? onProgress,
  });
}
```

- [ ] **Step 4: Update the pipeline** — three edits in `media_upload_pipeline.dart`:

(a) Hoist the rendition variable and pass the hash. Replace (current line ~161):
```dart
      final rendition = await _renditionFor(item, staged, level);
```
with — and declare `CompressionResult? rendition;` beside `File? staged;` before the `try`:
```dart
      rendition = await _renditionFor(item, staged, level, digest.hash);
```

(b) Replace the success-path cleanup (current line ~182, `await _cleanupRendition(rendition.file);`) with:
```dart
        if (item.mediaType == MediaType.video) {
          // Spec section 8: the deterministic rendition (and any stale
          // same-hash siblings from a level change) go away only once the
          // upload is confirmed.
          await _cache.deleteTranscodeArtifacts(digest.hash);
        } else {
          await _cleanupRendition(rendition.file);
        }
```

(c) In the `on Exception catch` block, after `await _queue.markFailed(entry.id, e.toString());`, add the photo-leak fix:
```dart
      // Photos re-compress cheaply, so their rendition staging file is
      // discarded on failure (Phase A leaked it). Video renditions are
      // deterministic and PRESERVED for the retry (spec section 8).
      final failedRendition = rendition;
      if (failedRendition != null && item.mediaType != MediaType.video) {
        await _cleanupRendition(failedRendition.file);
      }
```

(d) Replace `_renditionFor` (current line ~295):
```dart
  /// Chooses the compressor by media type; returns null for the Original
  /// level, when the compressor declines (ceiling/undecodable), or when a
  /// video has no transcoder registered (upload the original).
  Future<CompressionResult?> _renditionFor(
    MediaItem item,
    File source,
    MediaUploadQuality level,
    String contentHash,
  ) async {
    if (level == MediaUploadQuality.original) return null;
    if (item.mediaType == MediaType.video) {
      final transcoder = _videoTranscoder;
      if (transcoder == null) return null;
      final output = await _cache.transcodeFile(contentHash, level.name);
      if (await output.exists()) {
        // Transcode-once: a completed rendition survives retries and app
        // restarts; only markDone deletes it.
        return CompressionResult(
          file: output,
          ext: 'mp4',
          sizeBytes: await output.length(),
        );
      }
      return transcoder.transcode(item, source, level, output: output);
    }
    return _imageCompressor.compress(item, source, level);
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/media_store/media_upload_pipeline_video_test.dart test/features/media_store/media_upload_pipeline_test.dart test/features/media_store/media_upload_pipeline_quality_test.dart test/features/media_store/media_upload_pipeline_override_test.dart`
Expected: PASS (new file + zero regressions in the three Phase A pipeline files).

- [ ] **Step 6: Commit**

```bash
git add lib/features/media_store/data/video_transcoder.dart lib/features/media_store/data/media_upload_pipeline.dart test/features/media_store/media_upload_pipeline_video_test.dart
git commit -m "feat(media-store): transcode-once pipeline integration for video"
```

---

### Task 6: `PlatformVideoTranscoder` adapter

**Files:**
- Create: `lib/features/media_store/data/platform_video_transcoder.dart`
- Test: `test/features/media_store/platform_video_transcoder_test.dart`

**Interfaces:**
- Produces: `class PlatformVideoTranscoder implements VideoTranscoder { PlatformVideoTranscoder({TranscodeEngine? engine}); Future<bool> isAvailable(); }` — default engine = `engineForThisPlatform()`.
- Consumes: `TranscodeEngine`, `VideoProbe`, `TranscodeTarget`, `videoPresetFor`, `videoWithinCeiling`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media_store/platform_video_transcoder_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/platform_video_transcoder.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

class _FakeEngine implements TranscodeEngine {
  bool available = true;
  VideoProbe? probeResult = const VideoProbe(
    width: 3840, height: 2160, durationMs: 10000, overallBitrateKbps: 40000);
  TranscodeTarget? lastTarget;
  bool throwOnTranscode = false;

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<VideoProbe?> probe(File source) async => probeResult;
  @override
  Future<void> transcode({
    required File source,
    required File output,
    required TranscodeTarget target,
    VideoProbe? probe,
    void Function(double fraction)? onProgress,
  }) async {
    lastTarget = target;
    if (throwOnTranscode) throw const TranscodeException('boom');
    final tmp = File('${output.path}.tmp');
    await tmp.writeAsBytes([1, 2, 3], flush: true);
    await tmp.rename(output.path);
  }
}

void main() {
  late _FakeEngine engine;
  late PlatformVideoTranscoder transcoder;
  late Directory dir;

  setUp(() async {
    engine = _FakeEngine();
    transcoder = PlatformVideoTranscoder(engine: engine);
    dir = await Directory.systemTemp.createTemp('pvt_test');
  });
  tearDown(() => dir.delete(recursive: true));

  final item = MediaItem(
    id: 'v1',
    mediaType: MediaType.video,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<CompressionResultLike> run() async {
    final result = await transcoder.transcode(
      item,
      File('${dir.path}/in.mov'),
      MediaUploadQuality.balanced,
      output: File('${dir.path}/out.mp4'),
    );
    return CompressionResultLike(result?.ext, result?.sizeBytes);
  }

  test('maps the preset to a TranscodeTarget and returns the rendition',
      () async {
    final like = await run();
    expect(like.ext, 'mp4');
    expect(like.sizeBytes, 3);
    expect(engine.lastTarget!.maxHeight, 720);
    expect(engine.lastTarget!.videoBitrateKbps, 4000);
    expect(engine.lastTarget!.audioBitrateKbps, 128);
  });

  test('returns null when the engine is unavailable', () async {
    engine.available = false;
    expect((await run()).ext, isNull);
  });

  test('returns null when the probe fails', () async {
    engine.probeResult = null;
    expect((await run()).ext, isNull);
  });

  test('returns null when the source is within the ceiling', () async {
    engine.probeResult = const VideoProbe(
      width: 1280, height: 720, durationMs: 10000, overallBitrateKbps: 3000);
    expect((await run()).ext, isNull);
  });

  test('original level never transcodes', () async {
    final result = await transcoder.transcode(
      item,
      File('${dir.path}/in.mov'),
      MediaUploadQuality.original,
      output: File('${dir.path}/out.mp4'),
    );
    expect(result, isNull);
  });

  test('engine failure propagates as an exception', () async {
    engine.throwOnTranscode = true;
    await expectLater(run(), throwsA(isA<TranscodeException>()));
  });

  test('a null engine (no platform support) yields null', () async {
    final none = PlatformVideoTranscoder(engine: null, useDefaultEngine: false);
    final result = await none.transcode(
      item,
      File('${dir.path}/in.mov'),
      MediaUploadQuality.balanced,
      output: File('${dir.path}/out.mp4'),
    );
    expect(result, isNull);
    expect(await none.isAvailable(), isFalse);
  });
}

class CompressionResultLike {
  CompressionResultLike(this.ext, this.sizeBytes);
  final String? ext;
  final int? sizeBytes;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/platform_video_transcoder_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/media_store/data/platform_video_transcoder.dart
import 'dart:io';

import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/data/quality_presets.dart';
import 'package:submersion/features/media_store/data/video_transcoder.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// The app-side adapter between the upload pipeline's [VideoTranscoder]
/// seam and the platform's [TranscodeEngine] (spec section 9). Maps quality
/// presets to engine-agnostic targets, applies the ceiling rule, and
/// translates "no engine / probe failure / within ceiling" into null so the
/// pipeline uploads the original.
class PlatformVideoTranscoder implements VideoTranscoder {
  PlatformVideoTranscoder({TranscodeEngine? engine, bool useDefaultEngine = true})
    : _engine = engine ?? (useDefaultEngine ? engineForThisPlatform() : null);

  final TranscodeEngine? _engine;
  final _log = LoggerService.forClass(PlatformVideoTranscoder);

  /// Whether this platform can transcode right now (used by the settings
  /// hint; on Linux this reflects ffmpeg's presence on PATH).
  Future<bool> isAvailable() async {
    final engine = _engine;
    if (engine == null) return false;
    return engine.isAvailable();
  }

  @override
  Future<CompressionResult?> transcode(
    MediaItem item,
    File source,
    MediaUploadQuality level, {
    required File output,
    void Function(double fraction)? onProgress,
  }) async {
    final preset = videoPresetFor(level);
    if (preset == null) return null; // original: no transcode
    final engine = _engine;
    if (engine == null || !await engine.isAvailable()) return null;
    final probe = await engine.probe(source);
    if (probe == null) {
      _log.warning('Video probe failed for ${item.id}; uploading original');
      return null;
    }
    if (videoWithinCeiling(probe, preset)) return null;
    await engine.transcode(
      source: source,
      output: output,
      target: TranscodeTarget(
        maxHeight: preset.maxHeight,
        videoBitrateKbps: preset.videoBitrateKbps,
        audioBitrateKbps: preset.audioBitrateKbps,
      ),
      probe: probe,
      onProgress: onProgress,
    );
    return CompressionResult(
      file: output,
      ext: 'mp4',
      sizeBytes: await output.length(),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/platform_video_transcoder_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/data/platform_video_transcoder.dart test/features/media_store/platform_video_transcoder_test.dart
git commit -m "feat(media-store): PlatformVideoTranscoder adapter with ceiling rule"
```

---

### Task 7: Provider wiring + availability providers

**Files:**
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (add `isLinuxPlatformProvider` beside `isApplePlatformProvider` at line ~72)
- Test: `test/features/media_store/media_store_video_providers_test.dart`

**Interfaces:**
- Produces: `final videoTranscodeAvailableProvider = FutureProvider<bool>(...)`; `final isLinuxPlatformProvider = Provider<bool>((ref) => Platform.isLinux);`; `mediaStoreRuntimeProvider` constructs the pipeline with `videoTranscoder: PlatformVideoTranscoder()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media_store/media_store_video_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

void main() {
  test('videoTranscodeAvailableProvider resolves to a bool', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // On the test host there is no engine (non-Linux) or ffmpeg may exist
    // (Linux CI): either way the provider must resolve without throwing.
    final available = await container.read(
      videoTranscodeAvailableProvider.future,
    );
    expect(available, isA<bool>());
  });

  test('isLinuxPlatformProvider is overridable for widget tests', () {
    final container = ProviderContainer(
      overrides: [isLinuxPlatformProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);
    expect(container.read(isLinuxPlatformProvider), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_store_video_providers_test.dart`
Expected: FAIL (providers undefined).

- [ ] **Step 3: Write minimal implementation**

In `sync_providers.dart`, after `isApplePlatformProvider` (line ~74):
```dart
/// Whether the host is Linux, where video transcoding depends on a system
/// ffmpeg. A provider (not Platform.isLinux inline) so widget tests can
/// simulate Linux on any CI host — same pattern as [isApplePlatformProvider].
final isLinuxPlatformProvider = Provider<bool>((ref) => Platform.isLinux);
```

In `media_store_providers.dart`:
- Add import: `import 'package:submersion/features/media_store/data/platform_video_transcoder.dart';`
- In `mediaStoreRuntimeProvider`'s pipeline construction (the `MediaUploadPipeline(...)` call), add:
```dart
        videoTranscoder: PlatformVideoTranscoder(),
```
- Add beside `mediaStoreReuploadProvider`:
```dart
/// Whether this device can transcode video right now (spec section 12).
/// Drives the Linux settings hint; false on platforms without an engine.
final videoTranscodeAvailableProvider = FutureProvider<bool>(
  (ref) => PlatformVideoTranscoder().isAvailable(),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/media_store_video_providers_test.dart` and `flutter analyze`
Expected: PASS; analyzer clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/presentation/providers/media_store_providers.dart lib/features/settings/presentation/providers/sync_providers.dart test/features/media_store/media_store_video_providers_test.dart
git commit -m "feat(media-store): wire PlatformVideoTranscoder + availability providers"
```

---

### Task 8: Linux settings hint + l10n (11 locales)

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb` + regenerate tracked `lib/l10n/arb/app_localizations*.dart` (`flutter gen-l10n`)
- Modify: `lib/features/media_store/presentation/pages/media_storage_page.dart` (below the video-quality `ListTile`, before the caveat `Padding`)
- Test: `test/features/media_store/media_storage_page_test.dart` (append)

**Interfaces:**
- Produces: l10n getter `settings_mediaStorage_quality_linuxFfmpegHint`; hint `Text` with `key: Key('media-quality-linux-ffmpeg-hint')` rendered when `isLinux && _videoQuality != null && _videoQuality != MediaUploadQuality.original && !videoAvailable`.

- [ ] **Step 1: Add the l10n key to all 11 locales** — append to each `app_<loc>.arb` (same insertion mechanics as Phase A; keep JSON valid):

| locale | value |
| --- | --- |
| en | `Install ffmpeg to enable video compression. Originals are uploaded until then.` |
| de | `Installieren Sie ffmpeg, um Videokomprimierung zu aktivieren. Bis dahin werden Originale hochgeladen.` |
| es | `Instala ffmpeg para habilitar la compresión de vídeo. Hasta entonces se suben los originales.` |
| fr | `Installez ffmpeg pour activer la compression vidéo. Les originaux sont téléversés d'ici là.` |
| it | `Installa ffmpeg per abilitare la compressione video. Fino ad allora vengono caricati gli originali.` |
| nl | `Installeer ffmpeg om videocompressie in te schakelen. Tot die tijd worden originelen geüpload.` |
| pt | `Instale o ffmpeg para ativar a compressão de vídeo. Até lá, os originais são enviados.` |
| hu | `Telepítse az ffmpeg-et a videótömörítés engedélyezéséhez. Addig az eredetik kerülnek feltöltésre.` |
| ar | `ثبّت ffmpeg لتمكين ضغط الفيديو. حتى ذلك الحين يتم رفع النسخ الأصلية.` |
| he | `התקן ffmpeg כדי לאפשר דחיסת וידאו. עד אז מועלים קבצי המקור.` |
| zh | `安装 ffmpeg 以启用视频压缩。在此之前将上传原始文件。` |

Then run `flutter gen-l10n` and verify `grep -c linuxFfmpegHint lib/l10n/arb/app_localizations.dart` returns ≥ 1.

- [ ] **Step 2: Write the failing widget test** — append to `media_storage_page_test.dart` (mirror the Phase A quality-section tests; view size `Size(800, 2600)`):

```dart
  testWidgets('Linux hint shows when video level set and ffmpeg missing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'media_store_video_quality': 'small',
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaStoreRuntimeProvider.overrideWith((ref) async => null),
            mediaStoreCredentialsStoreProvider.overrideWithValue(
              MediaStoreCredentialsStore(storage: InMemoryKeychain()),
            ),
            mediaStoreServiceProvider.overrideWithValue(service),
            mediaBackfillServiceProvider.overrideWithValue(backfill),
            mediaStoreStatusHintProvider.overrideWith(
              (ref) async => 'dive-media @ minio',
            ),
            mediaTransferActiveCountProvider.overrideWith(
              (ref) => Stream.value(0),
            ),
            isApplePlatformProvider.overrideWithValue(false),
            isLinuxPlatformProvider.overrideWithValue(true),
            videoTranscodeAvailableProvider.overrideWith((ref) async => false),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaStoragePage(),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.ensureVisible(
      find.byKey(const Key('media-quality-linux-ffmpeg-hint')),
    );
    expect(
      find.byKey(const Key('media-quality-linux-ffmpeg-hint')),
      findsOneWidget,
    );
  });
```
(Add imports for `isLinuxPlatformProvider` — `sync_providers.dart` is already imported by the page test's existing imports; verify and add if absent.)

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_storage_page_test.dart`
Expected: FAIL (hint key not found).

- [ ] **Step 4: Implement the hint** — in `media_storage_page.dart`, insert between the video-quality `ListTile` and the caveat `Padding`:

```dart
                if (ref.watch(isLinuxPlatformProvider) &&
                    _videoQuality != null &&
                    _videoQuality != MediaUploadQuality.original &&
                    !(ref.watch(videoTranscodeAvailableProvider).value ?? true))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      l10n.settings_mediaStorage_quality_linuxFfmpegHint,
                      key: const Key('media-quality-linux-ffmpeg-hint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
```
Add the import for `sync_providers.dart` if not already present in the page.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/media_store/media_storage_page_test.dart`
Expected: PASS (all page tests including the new hint test).

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/arb/ lib/features/media_store/presentation/pages/media_storage_page.dart test/features/media_store/media_storage_page_test.dart
git commit -m "feat(media-store): Linux ffmpeg hint on the upload quality section"
```

---

### Task 9: Real-ffmpeg smoke test + spec touch-up + full gates

**Files:**
- Create: `test/features/media_store/linux_ffmpeg_engine_smoke_test.dart`
- Modify: `docs/superpowers/specs/2026-07-21-video-transcoding-phase-b-design.md` (section 14 fixture sentence)

- [ ] **Step 1: Write the smoke test** (runtime-skips wherever ffmpeg is absent, so plain `flutter test` stays engine-free on dev machines; ubuntu CI runners ship ffmpeg, so it runs there with no ci.yaml change):

```dart
// test/features/media_store/linux_ffmpeg_engine_smoke_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

/// Real-engine smoke (spec section 14): synthesizes a test clip with the
/// same ffmpeg it is testing (lavfi testsrc), then probes and transcodes
/// it. Skips wherever ffmpeg/ffprobe are not on PATH.
void main() {
  test('probe + transcode a synthesized clip end to end', () async {
    final engine = LinuxFfmpegEngine();
    if (!await engine.isAvailable()) {
      markTestSkipped('ffmpeg/ffprobe not on PATH; smoke skipped');
      return;
    }
    final dir = await Directory.systemTemp.createTemp('ffmpeg_smoke');
    addTearDown(() => dir.delete(recursive: true));

    // Synthesize a 2s 640x480 H.264+AAC input clip.
    final input = File('${dir.path}/input.mp4');
    final gen = await Process.run('ffmpeg', [
      '-y',
      '-f', 'lavfi', '-i', 'testsrc=duration=2:size=640x480:rate=15',
      '-f', 'lavfi', '-i', 'sine=frequency=440:duration=2',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
      '-c:a', 'aac', '-shortest',
      input.path,
    ]);
    expect(gen.exitCode, 0, reason: 'fixture generation: ${gen.stderr}');

    final probe = (await engine.probe(input))!;
    expect(probe.height, 480);
    expect(probe.durationMs, greaterThan(1500));

    final output = File('${dir.path}/output.mp4');
    final fractions = <double>[];
    await engine.transcode(
      source: input,
      output: output,
      target: const TranscodeTarget(
        maxHeight: 240, videoBitrateKbps: 300, audioBitrateKbps: 64),
      probe: probe,
      onProgress: fractions.add,
    );

    expect(await output.exists(), isTrue);
    expect(await File('${output.path}.tmp').exists(), isFalse);
    final outProbe = (await engine.probe(output))!;
    expect(outProbe.height, 240);
    expect(
      await output.length(),
      lessThan(await input.length()),
      reason: 'compressed output smaller than input',
    );
    expect(fractions, isNotEmpty);
    expect(fractions.last, 1.0);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
```

- [ ] **Step 2: Run it locally**

Run: `flutter test test/features/media_store/linux_ffmpeg_engine_smoke_test.dart`
Expected: PASS if ffmpeg is installed locally, otherwise SKIPPED — both acceptable.

- [ ] **Step 3: Update the spec's fixture sentence** — in `docs/superpowers/specs/2026-07-21-video-transcoding-phase-b-design.md` section 14, replace the "Fixture:" bullet with:

```markdown
- **Fixture:** the smoke test synthesizes its own input clip with ffmpeg's
  `lavfi testsrc` (it already requires ffmpeg and skips without it), so no
  binary fixture is committed. (Revised from the original checked-in-fixture
  plan during B1 planning.)
```

- [ ] **Step 4: Full gates**

Run:
```bash
dart format .
flutter analyze
flutter test test/features/media_store/ test/features/media/data/ test/core/database/ test/core/services/media_store/
```
Expected: format clean, analyzer clean, all listed suites PASS. Then run the full suite in the background (`flutter test`) and confirm exit 0 before pushing.

- [ ] **Step 5: Commit**

```bash
git add test/features/media_store/linux_ffmpeg_engine_smoke_test.dart docs/superpowers/specs/2026-07-21-video-transcoding-phase-b-design.md
git commit -m "test(transcoder): real-ffmpeg smoke test with synthesized fixture"
```

---

## Self-Review notes

- **Spec coverage (B1 scope):** §5 package/dispatcher → Tasks 1–2; §6 presets → Task 3; §7 ceiling → Tasks 3, 6; §8 staging + photo-leak fix → Tasks 4–5; §9 interface/onProgress → Tasks 2, 5, 6; §10 Linux engine → Task 2; §11 wiring → Task 7; §12 hint → Task 8; §13 error semantics → Tasks 2 (TranscodeException), 5 (failure preserves rendition), 6 (null paths); §14 testing → Tasks 1–9 (smoke = Task 9, fixture deviation documented). darwin/Android/Windows engines (§10 remainder) are explicitly out of scope.
- **Type consistency:** `TranscodeEngine.transcode` returns `Future<void>` + throws; adapter wraps into `CompressionResult`. `VideoTranscoder.transcode` gains `{required File output, onProgress}` — safe because Phase A has zero implementors (verified). `_renditionFor` gains `contentHash` param; all call sites updated in Task 5.
- **Known judgment calls recorded:** ffmpeg progress uses `out_time_us`; scale filter `scale=w=-2:h='min(H,ih)'` (validated by the Task 9 real-engine smoke); smoke test self-synthesizes its fixture (spec §14 deviation, Task 9 updates spec).
