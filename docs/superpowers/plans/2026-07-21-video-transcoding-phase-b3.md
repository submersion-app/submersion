# Video Transcoding Phase B3 — Android Media3 Transformer

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an Android engine to `submersion_transcoder` (Media3 `Transformer`) so a non-`Original` video level transcodes natively on Android.

**Architecture:** B2's `DarwinAvfEngine` is a *platform-agnostic* channel client (it only talks to `submersion_transcoder/methods` + `/progress`). B3 renames it to `ChannelTranscodeEngine` and reuses it on Android — the Dart side is identical; only the native code differs. Then B3 adds the Android platform to the plugin: a Kotlin `SubmersionTranscoderPlugin` implementing the same channel contract, with transcoding via `androidx.media3` `Transformer`.

**Tech Stack:** Kotlin, AndroidX Media3 (`transformer`, `common`, `effect`), Flutter platform channels. Template: `packages/submersion_ocr/android`.

**Spec:** `docs/superpowers/specs/2026-07-21-video-transcoding-phase-b-design.md` (§9 channel shape, §10 Android notes, §15). Scope = Android ONLY; Windows is B4.

## Global Constraints

- Branch `worktree-media-upload-quality-phase-b3`, stacked on B2 (PR #669). Build-ready.
- **Verification reality — native Kotlin is NOT run by `flutter test`.** So: the Dart `ChannelTranscodeEngine` is unit-tested against mock channels (the B2 test, renamed); the Kotlin is **compile-verified** with `flutter build apk --debug`; real transcoding is an `integration_test` run on an Android emulator/device (`flutter test integration_test -d <android>`), tagged so plain `flutter test` never runs it. **Never claim runtime transcode success from `flutter test`.**
- Channel contract (identical to B2, both sides): MethodChannel `submersion_transcoder/methods` (`isAvailable`→bool; `probe {path}`→`{width,height,durationMs,overallBitrateKbps}`|null; `transcode {source,output,maxHeight,videoBitrateKbps,audioBitrateKbps,progressId}`→null|error). EventChannel `submersion_transcoder/progress` streams `{progressId,fraction}`.
- Output: H.264 + AAC `.mp4`, scale to `maxHeight` (never upscale), write `<output>.tmp` then rename.
- `dart format .` clean; `flutter analyze` clean (info lints fatal). CI: CodeQL java/kotlin autobuild is OFF; Android instrumented tests need JBR21.
- `*.g.dart` gitignored.

---

### Task 1: DRY — rename `DarwinAvfEngine` → `ChannelTranscodeEngine`; dispatch on Android

**Files:**
- Rename: `packages/submersion_transcoder/lib/src/darwin_avf_engine.dart` → `channel_transcode_engine.dart` (class `DarwinAvfEngine` → `ChannelTranscodeEngine`)
- Modify: `packages/submersion_transcoder/lib/submersion_transcoder.dart` (export)
- Modify: `packages/submersion_transcoder/lib/src/transcode_engine.dart` (`engineForThisPlatform`: Apple + Android → `ChannelTranscodeEngine`)
- Rename: `test/features/media_store/darwin_avf_engine_test.dart` → `channel_transcode_engine_test.dart` (update class name + description)
- Modify: `test/features/media_store/engine_for_platform_test.dart` (expect `ChannelTranscodeEngine` on Apple)

**Interfaces:**
- Produces: `class ChannelTranscodeEngine implements TranscodeEngine` (byte-identical logic to B2's `DarwinAvfEngine`, just renamed). `engineForThisPlatform()` returns it on iOS/macOS **and Android**.

- [ ] **Step 1: Rename the implementation** — `git mv` then swap the class name:
```bash
git mv packages/submersion_transcoder/lib/src/darwin_avf_engine.dart \
       packages/submersion_transcoder/lib/src/channel_transcode_engine.dart
```
In the renamed file, change `class DarwinAvfEngine` to `class ChannelTranscodeEngine` and update the ctor name and the doc comment (drop "AVFoundation", say "native platforms (iOS/macOS/Android) whose plugin implements the transcoder channels").

- [ ] **Step 2: Update the export + dispatch**

`packages/submersion_transcoder/lib/submersion_transcoder.dart`: replace `export 'src/darwin_avf_engine.dart';` with `export 'src/channel_transcode_engine.dart';`.

`transcode_engine.dart`: replace the import `darwin_avf_engine.dart` with `channel_transcode_engine.dart`, and:
```dart
TranscodeEngine? engineForThisPlatform() {
  if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
    return ChannelTranscodeEngine();
  }
  if (Platform.isLinux) return LinuxFfmpegEngine();
  return null;
}
```

- [ ] **Step 3: Rename + update the tests**
```bash
git mv test/features/media_store/darwin_avf_engine_test.dart \
       test/features/media_store/channel_transcode_engine_test.dart
```
In it, replace every `DarwinAvfEngine` with `ChannelTranscodeEngine`. In `engine_for_platform_test.dart`, replace `isA<DarwinAvfEngine>()` with `isA<ChannelTranscodeEngine>()` and add an Android arm:
```dart
    if (Platform.isMacOS || Platform.isIOS || Platform.isAndroid) {
      expect(engine, isA<ChannelTranscodeEngine>());
    } else if (Platform.isLinux) {
      expect(engine, isA<LinuxFfmpegEngine>());
    } else {
      expect(engine, isNull);
    }
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/media_store/channel_transcode_engine_test.dart test/features/media_store/engine_for_platform_test.dart`
Expected: PASS (6 + 1).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(transcoder): generalize DarwinAvfEngine to ChannelTranscodeEngine (shared by Apple+Android)"
```

---

### Task 2: Android plugin scaffold + Media3 deps — compile gate

**Files:**
- Modify: `packages/submersion_transcoder/pubspec.yaml` (add `android:` platform)
- Create: `packages/submersion_transcoder/android/build.gradle`
- Create: `packages/submersion_transcoder/android/src/main/AndroidManifest.xml`
- Create: `packages/submersion_transcoder/android/src/main/kotlin/app/submersion/transcoder/SubmersionTranscoderPlugin.kt` (channels registered; `probe`/`transcode` stubbed)

**Interfaces:**
- Produces: a loadable Android plugin `SubmersionTranscoderPlugin` (package `app.submersion.transcoder`) registering the same two channels.

- [ ] **Step 1: Add the `android:` platform to the plugin block** (in `pubspec.yaml`, under `flutter: plugin: platforms:`, beside `ios`/`macos`):
```yaml
      android:
        package: app.submersion.transcoder
        pluginClass: SubmersionTranscoderPlugin
```

- [ ] **Step 2: Create `android/build.gradle`** (mirrors `submersion_ocr`, swaps the dependency for Media3):
```gradle
group = "app.submersion.transcoder"
version = "0.1.0"

buildscript {
    repositories { google(); mavenCentral() }
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.22")
    }
}

rootProject.allprojects {
    repositories { google(); mavenCentral() }
}

apply plugin: "com.android.library"
apply plugin: "kotlin-android"

android {
    namespace = "app.submersion.transcoder"
    compileSdk = 34
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions { jvmTarget = "1.8" }
    defaultConfig { minSdk = 24 }
    sourceSets { main.java.srcDirs += "src/main/kotlin" }
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib:1.8.22"
    def media3 = "1.4.1"
    implementation "androidx.media3:media3-transformer:$media3"
    implementation "androidx.media3:media3-common:$media3"
    implementation "androidx.media3:media3-effect:$media3"
}
```
Note: `minSdk = 24` (Media3 Transformer needs API 24+; the app's minSdk must be ≥ 24 — verify `android/app/build.gradle` in the app and raise it if needed as part of this task).

- [ ] **Step 3: Create `android/src/main/AndroidManifest.xml`**:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="app.submersion.transcoder" />
```

- [ ] **Step 4: Create the Kotlin plugin stub**:
```kotlin
// packages/submersion_transcoder/android/src/main/kotlin/app/submersion/transcoder/SubmersionTranscoderPlugin.kt
package app.submersion.transcoder

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val METHODS = "submersion_transcoder/methods"
private const val PROGRESS = "submersion_transcoder/progress"

class SubmersionTranscoderPlugin :
    FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methods: MethodChannel
    private lateinit var progress: EventChannel
    private lateinit var context: Context
    private var progressSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, METHODS)
        methods.setMethodCallHandler(this)
        progress = EventChannel(binding.binaryMessenger, PROGRESS)
        progress.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        progress.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        progressSink = events
    }

    override fun onCancel(arguments: Any?) {
        progressSink = null
    }
}
```

- [ ] **Step 5: Compile-verify**

Run: `flutter build apk --debug 2>&1 | tail -20`
Expected: BUILD SUCCESSFUL. (If `minSdk` conflicts: raise `android/app/build.gradle`'s `minSdkVersion`/`minSdk` to 24.)

- [ ] **Step 6: Commit**

```bash
git add packages/submersion_transcoder/pubspec.yaml packages/submersion_transcoder/android android/app/build.gradle
git commit -m "feat(transcoder): Android plugin scaffold + Media3 deps"
```

---

### Task 3: Kotlin probe + Media3 Transformer transcode + progress

**Files:**
- Create: `packages/submersion_transcoder/android/src/main/kotlin/app/submersion/transcoder/Media3Transcoder.kt`
- Modify: `SubmersionTranscoderPlugin.kt` (dispatch `probe`/`transcode`)

**Interfaces:**
- Produces: `Media3Transcoder.probe(context, path) -> Map?`; `Media3Transcoder.transcode(...)` writing `<output>.tmp` then renaming, with progress + a completion callback.

- [ ] **Step 1: Write `Media3Transcoder.kt`**:
```kotlin
package app.submersion.transcoder

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File

object Media3Transcoder {
    fun probe(context: Context, path: String): Map<String, Any>? {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            val w = r.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            val h = r.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
            if (w == null || h == null || w == 0 || h == 0) return null
            // Rotation swaps reported width/height for the display orientation.
            val rot = r.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            val dispW = if (rot == 90 || rot == 270) h else w
            val dispH = if (rot == 90 || rot == 270) w else h
            val durationMs = r.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val bitrate = r.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toLongOrNull() ?: 0L
            mapOf(
                "width" to dispW, "height" to dispH,
                "durationMs" to durationMs.toInt(),
                "overallBitrateKbps" to (bitrate / 1000).toInt(),
            )
        } catch (e: Exception) {
            null
        } finally {
            r.release()
        }
    }

    /** Must be called on the main (Looper) thread. onDone(errorOrNull). */
    @androidx.annotation.OptIn(markerClass = [androidx.media3.common.util.UnstableApi::class])
    fun transcode(
        context: Context,
        source: String, output: String,
        maxHeight: Int, videoBitrateKbps: Int, audioBitrateKbps: Int,
        onProgress: (Double) -> Unit,
        onDone: (String?) -> Unit,
    ) {
        val tmp = File("$output.tmp")
        if (tmp.exists()) tmp.delete()

        val encoderFactory = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(
                VideoEncoderSettings.Builder()
                    .setBitrate(videoBitrateKbps * 1000)
                    .build())
            .build()

        val videoEffects = listOf<Effect>(Presentation.createForHeight(maxHeight))
        val edited = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(source))))
            .setEffects(Effects(/* audioProcessors= */ listOf(), videoEffects))
            .build()

        val handler = Handler(Looper.getMainLooper())
        lateinit var transformer: Transformer
        val progressHolder = ProgressHolder()
        val poll = object : Runnable {
            override fun run() {
                if (transformer.getProgress(progressHolder)
                    != Transformer.PROGRESS_STATE_NOT_STARTED) {
                    onProgress(progressHolder.progress / 100.0)
                    handler.postDelayed(this, 200)
                }
            }
        }

        transformer = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoderFactory)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, result: ExportResult) {
                    handler.removeCallbacks(poll)
                    onProgress(1.0)
                    val renamed = tmp.renameTo(File(output))
                    onDone(if (renamed) null else "rename failed")
                }
                override fun onError(
                    composition: Composition, result: ExportResult,
                    exception: ExportException
                ) {
                    handler.removeCallbacks(poll)
                    tmp.delete()
                    onDone(exception.message ?: "transform failed")
                }
            })
            .build()

        transformer.start(edited, tmp.absolutePath)
        handler.postDelayed(poll, 200)
    }
}
```

- [ ] **Step 2: Dispatch in the plugin** — replace `onMethodCall`:
```kotlin
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            "probe" -> {
                val path = call.argument<String>("path")
                if (path == null) { result.success(null); return }
                result.success(Media3Transcoder.probe(context, path))
            }
            "transcode" -> {
                val source = call.argument<String>("source")
                val output = call.argument<String>("output")
                val maxHeight = call.argument<Int>("maxHeight")
                val vk = call.argument<Int>("videoBitrateKbps")
                val ak = call.argument<Int>("audioBitrateKbps")
                val progressId = call.argument<String>("progressId")
                if (source == null || output == null || maxHeight == null ||
                    vk == null || ak == null || progressId == null) {
                    result.error("bad_args", "transcode args", null); return
                }
                Handler(Looper.getMainLooper()).post {
                    Media3Transcoder.transcode(
                        context, source, output, maxHeight, vk, ak,
                        onProgress = { f ->
                            progressSink?.success(
                                mapOf("progressId" to progressId, "fraction" to f))
                        },
                        onDone = { err ->
                            if (err == null) result.success(null)
                            else result.error("transcode_failed", err, null)
                        })
                }
            }
            else -> result.notImplemented()
        }
    }
```
Add imports to the plugin: `import android.os.Handler`, `import android.os.Looper`.

- [ ] **Step 3: Compile-verify**

Run: `flutter build apk --debug 2>&1 | tail -20`
Expected: BUILD SUCCESSFUL (fix any Media3 API mismatches surfaced here — the version is pinned at 1.4.1; adjust API calls to that version if needed).

- [ ] **Step 4: Commit**

```bash
git add packages/submersion_transcoder/android/src
git commit -m "feat(transcoder): Android Media3 probe + transcode (Kotlin)"
```

---

### Task 4: Android integration test + full gates

**Files:**
- Create: `integration_test/android_transcode_test.dart`

- [ ] **Step 1: Write the integration test** (mirrors the darwin one; needs a device/emulator with a real clip — bundle-free by generating with the source app's assets is not possible, so this test skips unless a clip is present at a known path pushed by the harness; keep it robust):
```dart
// integration_test/android_transcode_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

/// Real-engine integration test for Android Media3 (spec §14). Runs on an
/// emulator/device (`flutter test integration_test -d <android>`); NOT part
/// of plain `flutter test`. Skips unless a source clip has been placed at
/// the app's temp dir as `it_input.mp4` (the CI/emulator harness pushes one),
/// since Android cannot spawn ffmpeg to synthesize input.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Media3 transcodes a real clip smaller', (tester) async {
    if (!Platform.isAndroid) {
      markTestSkipped('android transcode integration runs on Android only');
      return;
    }
    final engine = engineForThisPlatform()!;
    expect(engine, isA<ChannelTranscodeEngine>());
    expect(await engine.isAvailable(), isTrue);

    final tmp = Directory.systemTemp;
    final input = File('${tmp.path}/it_input.mp4');
    if (!await input.exists()) {
      markTestSkipped('no it_input.mp4 pushed to ${input.path}; skipping');
      return;
    }
    final probe = (await engine.probe(input))!;
    expect(probe.height, greaterThan(0));

    final output = File('${tmp.path}/it_out.mp4');
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
    final outProbe = (await engine.probe(output))!;
    expect(outProbe.height, lessThanOrEqualTo(240));
    expect(await output.length(), lessThan(await input.length()));
  });
}
```

- [ ] **Step 2: Gates**

Run:
```bash
dart format .
flutter analyze
flutter test test/features/media_store/ test/features/media/data/
flutter build apk --debug 2>&1 | tail -5
```
Expected: format clean, analyzer clean, Dart suites PASS, APK BUILD SUCCESSFUL. Then run the full `flutter test` in the background and confirm all-pass (the one known flaky backup-crypto test may fail in the full run — re-run it isolated to confirm it is the flake, not a regression).

- [ ] **Step 3: Commit**

```bash
git add integration_test/android_transcode_test.dart
git commit -m "test(transcoder): Android Media3 integration test"
```

---

## Self-Review notes

- **Spec coverage:** §9 channel shape → Task 2/3 (same channels/contract as darwin); §10 Android (Media3 Transformer, `VideoEncoderSettings` bitrate, `Presentation.createForHeight`, H.264/AAC, tmp-rename, progress) → Task 3; §15 (Android after darwin) → this plan. Windows (B4) out of scope.
- **DRY:** Task 1 removes the duplicate-channel-client risk by generalizing `DarwinAvfEngine` → `ChannelTranscodeEngine`, used by all native platforms; the Dart unit tests carry over unchanged (just renamed).
- **Verification honesty:** Kotlin gates are `flutter build apk`; runtime is the Android integration test on an emulator/device, never plain `flutter test`.
- **Known risks flagged in-plan:** Media3 Transformer API can differ across versions (pinned 1.4.1; the `flutter build apk` gate surfaces mismatches); `minSdk` must be ≥ 24 for Transformer (raise the app's if needed); the Android integration test needs a pushed input clip (Android can't synthesize with ffmpeg), so it skips without one.
