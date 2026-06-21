# Android SAF backups + DB-location fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make manual and automatic backups, and the custom database location, work on Android 11+ (scoped storage) — fixing issue #300.

**Architecture:** Backups to a user-chosen folder go through the Storage Access Framework (a new in-repo `submersion_saf` Flutter plugin: persisted `content://` tree URI + `DocumentFile` streamed writes), routed via a `BackupTarget` abstraction so the existing filesystem path is untouched. The live database — which SQLite must open by real path — relocates to an app-specific external dir (internal or SD card) via `path_provider`, reusing the existing path-based migration machinery.

**Tech Stack:** Flutter, Dart, Kotlin (`androidx.documentfile`), `path_provider`, MethodChannel, Workmanager.

## Global Constraints

- Android-only behavior. Every new code path is gated on `Platform.isAndroid`; `submersion_saf` declares only the `android` platform.
- No third-party SAF library; no `MANAGE_EXTERNAL_STORAGE` permission.
- Preserve existing branches verbatim for iOS / macOS / Windows / Linux (see spec §3.1 table). A non-`content://` backup ref must always take the pre-existing filesystem path.
- SAF MethodChannel name: `app.submersion/saf`. Plugin Kotlin package: `app.submersion.saf`.
- Plugin gradle: `minSdk = 21`, `compileSdk = 34` (match `packages/libdivecomputer_plugin`).
- `dart format .` clean and `flutter analyze` (whole project) clean before each commit.
- New user-facing strings added to `lib/l10n/arb/app_en.arb` AND all 10 non-en locale ARBs, then `flutter gen-l10n` run — never leave English fallbacks.
- Do not auto-commit outside these tasks; each task ends with one commit on branch `worktree-worktree-issue-300-android-backup`.

Spec: `docs/superpowers/specs/2026-06-20-android-saf-backup-and-db-location-design.md`

---

## File Structure

New (plugin):
- `packages/submersion_saf/pubspec.yaml` — Android-only plugin manifest
- `packages/submersion_saf/android/build.gradle`
- `packages/submersion_saf/android/src/main/AndroidManifest.xml`
- `packages/submersion_saf/android/src/main/kotlin/app/submersion/saf/SubmersionSafPlugin.kt`
- `packages/submersion_saf/lib/submersion_saf.dart` — Dart facade

New (app):
- `lib/features/backup/data/services/backup_saf_port.dart` — `BackupSafPort` seam + channel impl
- `lib/features/backup/data/services/backup_target.dart` — `BackupTarget`, `FilesystemBackupTarget`, `SafBackupTarget`, `isSafRef`, `BackupTargetLease`
- `test/.../submersion_saf_facade_test.dart`, `backup_target_test.dart`, `backup_target_lease_test.dart`, `backup_service_saf_refs_test.dart`, `database_location_external_dirs_test.dart`

Modified (app):
- `pubspec.yaml` — add `submersion_saf` path dep
- `lib/features/backup/data/services/backup_service.dart` — inject `BackupSafPort`; add `resolveBackupTargetLeased`; rewire `performBackup`; ref-aware size/restore/delete/history
- `lib/features/backup/data/repositories/backup_preferences.dart` — `backup_location_label` get/set
- `lib/features/backup/presentation/providers/backup_providers.dart` — Saf location setter
- `lib/features/backup/presentation/pages/backup_settings_page.dart` — Android SAF picker branch + label subtitle
- `lib/core/services/database_location_service.dart` — Android external-dir chooser; fix stale comment
- `lib/l10n/arb/*.arb` — DB-location strings

---

# Part A — SAF backups

## Task A1: Scaffold the `submersion_saf` plugin (Android-only)

**Files:**
- Create: `packages/submersion_saf/pubspec.yaml`
- Create: `packages/submersion_saf/android/build.gradle`
- Create: `packages/submersion_saf/android/src/main/AndroidManifest.xml`
- Create: `packages/submersion_saf/android/src/main/kotlin/app/submersion/saf/SubmersionSafPlugin.kt`
- Create: `packages/submersion_saf/lib/submersion_saf.dart`
- Modify: `pubspec.yaml` (app, dependencies)

**Interfaces:**
- Produces (Dart facade, used by A2 and the settings page):
  - `class SafFolder { final String uri; final String displayName; }`
  - `SubmersionSaf.pickFolder() -> Future<SafFolder?>`
  - `SubmersionSaf.writeBackup({required String treeUri, required String fileName, required String sourcePath}) -> Future<String>` (document URI)
  - `SubmersionSaf.readBackup({required String documentUri, required String destPath}) -> Future<void>`
  - `SubmersionSaf.delete(String documentUri) -> Future<bool>`
  - `SubmersionSaf.exists(String documentUri) -> Future<bool>`
  - `SubmersionSaf.resolveTree(String treeUri) -> Future<String?>`

- [ ] **Step 1: Create the plugin pubspec**

`packages/submersion_saf/pubspec.yaml`:
```yaml
name: submersion_saf
description: Android Storage Access Framework helpers (persisted tree URIs, DocumentFile writes) for Submersion backups.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.10.0
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  plugin:
    platforms:
      android:
        package: app.submersion.saf
        pluginClass: SubmersionSafPlugin
```

- [ ] **Step 2: Create the plugin gradle** (mirrors `packages/libdivecomputer_plugin/android/build.gradle`, minus NDK/CMake)

`packages/submersion_saf/android/build.gradle`:
```gradle
group = "app.submersion.saf"
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
    namespace = "app.submersion.saf"
    compileSdk = 34
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions { jvmTarget = "1.8" }
    defaultConfig { minSdk = 21 }
    sourceSets { main.java.srcDirs += "src/main/kotlin" }
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib:1.8.22"
    implementation "androidx.documentfile:documentfile:1.0.1"
}
```

- [ ] **Step 3: Create the plugin manifest**

`packages/submersion_saf/android/src/main/AndroidManifest.xml`:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android" />
```

- [ ] **Step 4: Create the native plugin** (FlutterPlugin + ActivityAware; write/read/delete/exists/resolveTree use applicationContext so they work in the Workmanager isolate; pickFolder needs the Activity)

`packages/submersion_saf/android/src/main/kotlin/app/submersion/saf/SubmersionSafPlugin.kt`:
```kotlin
package app.submersion.saf

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

private const val CHANNEL = "app.submersion/saf"
private const val OPEN_TREE_REQUEST = 0xC0DE

class SubmersionSafPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPick: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFolder" -> pickFolder(result)
            "writeBackup" -> writeBackup(call, result)
            "readBackup" -> readBackup(call, result)
            "delete" -> delete(call, result)
            "exists" -> exists(call, result)
            "resolveTree" -> resolveTree(call, result)
            else -> result.notImplemented()
        }
    }

    private fun pickFolder(result: MethodChannel.Result) {
        val act = activity ?: return result.error("NO_ACTIVITY", "No foreground activity", null)
        if (pendingPick != null) return result.error("BUSY", "A pick is already in progress", null)
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        act.startActivityForResult(intent, OPEN_TREE_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != OPEN_TREE_REQUEST) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        return try {
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            context.contentResolver.takePersistableUriPermission(uri, flags)
            val name = DocumentFile.fromTreeUri(context, uri)?.name ?: ""
            result.success(mapOf("uri" to uri.toString(), "displayName" to name))
            true
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
            true
        }
    }

    private fun writeBackup(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = call.argument<String>("treeUri")!!
        val fileName = call.argument<String>("fileName")!!
        val sourcePath = call.argument<String>("sourcePath")!!
        try {
            val tree = DocumentFile.fromTreeUri(context, Uri.parse(treeUri))
                ?: return result.error("NO_TREE", "Tree URI did not resolve", null)
            // Replace an existing same-name file so retries don't accumulate "(1)" copies.
            tree.findFile(fileName)?.delete()
            val doc = tree.createFile("application/octet-stream", fileName)
                ?: return result.error("CREATE_FAILED", "createFile returned null", null)
            context.contentResolver.openOutputStream(doc.uri).use { out ->
                if (out == null) return result.error("OPEN_FAILED", "openOutputStream null", null)
                File(sourcePath).inputStream().use { it.copyTo(out) }
            }
            result.success(doc.uri.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
        } catch (e: Exception) {
            result.error("WRITE_FAILED", e.localizedMessage, null)
        }
    }

    private fun readBackup(call: MethodCall, result: MethodChannel.Result) {
        val documentUri = call.argument<String>("documentUri")!!
        val destPath = call.argument<String>("destPath")!!
        try {
            context.contentResolver.openInputStream(Uri.parse(documentUri)).use { input ->
                if (input == null) return result.error("OPEN_FAILED", "openInputStream null", null)
                File(destPath).outputStream().use { input.copyTo(it) }
            }
            result.success(null)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
        } catch (e: Exception) {
            result.error("READ_FAILED", e.localizedMessage, null)
        }
    }

    private fun delete(call: MethodCall, result: MethodChannel.Result) {
        val documentUri = call.argument<String>("documentUri")!!
        val ok = try {
            DocumentFile.fromSingleUri(context, Uri.parse(documentUri))?.delete() ?: false
        } catch (_: Exception) { false }
        result.success(ok)
    }

    private fun exists(call: MethodCall, result: MethodChannel.Result) {
        val documentUri = call.argument<String>("documentUri")!!
        val ok = try {
            DocumentFile.fromSingleUri(context, Uri.parse(documentUri))?.exists() ?: false
        } catch (_: Exception) { false }
        result.success(ok)
    }

    private fun resolveTree(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = call.argument<String>("treeUri")!!
        val name = try {
            val df = DocumentFile.fromTreeUri(context, Uri.parse(treeUri))
            if (df != null && df.exists() && df.canWrite()) (df.name ?: "") else null
        } catch (_: Exception) { null }
        result.success(name)
    }
}
```

- [ ] **Step 5: Create the Dart facade**

`packages/submersion_saf/lib/submersion_saf.dart`:
```dart
import 'package:flutter/services.dart';

/// A picked SAF directory: the persisted tree URI and its human display name.
class SafFolder {
  const SafFolder({required this.uri, required this.displayName});
  final String uri;
  final String displayName;
}

/// Thin Dart facade over the Android `app.submersion/saf` channel.
///
/// Android-only. Callers MUST guard with `Platform.isAndroid`; on other
/// platforms the channel has no handler and calls throw MissingPluginException.
class SubmersionSaf {
  const SubmersionSaf._();
  static const MethodChannel _channel = MethodChannel('app.submersion/saf');

  static Future<SafFolder?> pickFolder() async {
    final res = await _channel.invokeMapMethod<String, dynamic>('pickFolder');
    if (res == null) return null;
    return SafFolder(
      uri: res['uri'] as String,
      displayName: res['displayName'] as String,
    );
  }

  static Future<String> writeBackup({
    required String treeUri,
    required String fileName,
    required String sourcePath,
  }) async {
    final uri = await _channel.invokeMethod<String>('writeBackup', {
      'treeUri': treeUri,
      'fileName': fileName,
      'sourcePath': sourcePath,
    });
    return uri!;
  }

  static Future<void> readBackup({
    required String documentUri,
    required String destPath,
  }) =>
      _channel.invokeMethod<void>('readBackup', {
        'documentUri': documentUri,
        'destPath': destPath,
      });

  static Future<bool> delete(String documentUri) async =>
      await _channel.invokeMethod<bool>('delete', {'documentUri': documentUri}) ??
      false;

  static Future<bool> exists(String documentUri) async =>
      await _channel.invokeMethod<bool>('exists', {'documentUri': documentUri}) ??
      false;

  static Future<String?> resolveTree(String treeUri) =>
      _channel.invokeMethod<String?>('resolveTree', {'treeUri': treeUri});
}
```

- [ ] **Step 6: Add the path dependency to the app** — in `pubspec.yaml`, under `dependencies:`, beside the existing `libdivecomputer_plugin`:
```yaml
  submersion_saf:
    path: packages/submersion_saf
```

- [ ] **Step 7: Resolve, analyze, build**

Run: `flutter pub get`
Expected: resolves; `submersion_saf` linked.

Run: `flutter analyze`
Expected: No issues.

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL (proves the plugin + `GeneratedPluginRegistrant` compile on Android).

- [ ] **Step 8: Commit**
```bash
git add packages/submersion_saf pubspec.yaml pubspec.lock docs/superpowers
git commit -m "feat(android): scaffold submersion_saf plugin for SAF backups (#300)"
```

---

## Task A2: `BackupSafPort` seam + facade-delegation test

**Files:**
- Create: `lib/features/backup/data/services/backup_saf_port.dart`
- Test: `test/features/backup/data/services/submersion_saf_facade_test.dart`

**Interfaces:**
- Consumes: `SubmersionSaf` (A1).
- Produces:
  - `abstract class BackupSafPort { Future<String> writeBackup({required String treeUri, required String fileName, required String sourcePath}); Future<void> readBackup({required String documentUri, required String destPath}); Future<bool> delete(String documentUri); Future<bool> exists(String documentUri); Future<String?> resolveTree(String treeUri); }`
  - `class MethodChannelBackupSafPort implements BackupSafPort` (delegates to `SubmersionSaf`).

- [ ] **Step 1: Write the failing test** (mock the channel, prove the facade marshals args/results)

`test/features/backup/data/services/submersion_saf_facade_test.dart`:
```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_saf/submersion_saf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.submersion/saf');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('writeBackup passes args and returns the document URI', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return 'content://doc/1';
    });

    final uri = await SubmersionSaf.writeBackup(
      treeUri: 'content://tree/1',
      fileName: 'b.db',
      sourcePath: '/data/x.db',
    );

    expect(uri, 'content://doc/1');
    expect(seen!.method, 'writeBackup');
    expect((seen!.arguments as Map)['fileName'], 'b.db');
  });

  test('pickFolder maps a null channel result to null', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await SubmersionSaf.pickFolder(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/submersion_saf_facade_test.dart`
Expected: FAIL (until `submersion_saf` is importable — passes once A1's pub get is in effect; if it already passes, that is acceptable since it validates the A1 facade. Treat a compile error about the import as the expected initial failure.)

- [ ] **Step 3: Create the port**

`lib/features/backup/data/services/backup_saf_port.dart`:
```dart
import 'package:submersion_saf/submersion_saf.dart';

/// Narrow seam over [SubmersionSaf] so backup logic is unit-testable with a
/// fake (no native channel). Android-only in practice; callers gate on platform.
abstract class BackupSafPort {
  Future<String> writeBackup({
    required String treeUri,
    required String fileName,
    required String sourcePath,
  });
  Future<void> readBackup({
    required String documentUri,
    required String destPath,
  });
  Future<bool> delete(String documentUri);
  Future<bool> exists(String documentUri);
  Future<String?> resolveTree(String treeUri);
}

class MethodChannelBackupSafPort implements BackupSafPort {
  const MethodChannelBackupSafPort();

  @override
  Future<String> writeBackup({
    required String treeUri,
    required String fileName,
    required String sourcePath,
  }) =>
      SubmersionSaf.writeBackup(
        treeUri: treeUri,
        fileName: fileName,
        sourcePath: sourcePath,
      );

  @override
  Future<void> readBackup({
    required String documentUri,
    required String destPath,
  }) =>
      SubmersionSaf.readBackup(documentUri: documentUri, destPath: destPath);

  @override
  Future<bool> delete(String documentUri) => SubmersionSaf.delete(documentUri);

  @override
  Future<bool> exists(String documentUri) => SubmersionSaf.exists(documentUri);

  @override
  Future<String?> resolveTree(String treeUri) =>
      SubmersionSaf.resolveTree(treeUri);
}
```

- [ ] **Step 4: Run test + analyze**

Run: `flutter test test/features/backup/data/services/submersion_saf_facade_test.dart`
Expected: PASS.
Run: `flutter analyze` — Expected: No issues.

- [ ] **Step 5: Commit**
```bash
git add lib/features/backup/data/services/backup_saf_port.dart test/features/backup/data/services/submersion_saf_facade_test.dart
git commit -m "feat(backup): add BackupSafPort seam over the SAF facade (#300)"
```

---

## Task A3: `BackupTarget` abstraction + `isSafRef`

**Files:**
- Create: `lib/features/backup/data/services/backup_target.dart`
- Test: `test/features/backup/data/services/backup_target_test.dart`

**Interfaces:**
- Consumes: `BackupDatabaseAdapter` (existing, `backup_service.dart`), `BackupSafPort` (A2).
- Produces:
  - `bool isSafRef(String ref)` — true iff `ref.startsWith('content://')`.
  - `abstract class BackupTarget { Future<String> write(BackupDatabaseAdapter adapter, String fileName); }`
  - `class FilesystemBackupTarget implements BackupTarget` (ctor `FilesystemBackupTarget(String dir)`).
  - `class SafBackupTarget implements BackupTarget` (ctor `SafBackupTarget(String treeUri, BackupSafPort port)`).
  - `class BackupTargetLease { final BackupTarget target; Future<void> release(); }`

- [ ] **Step 1: Write the failing test**

`test/features/backup/data/services/backup_target_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/backup_target.dart';

class _FakeAdapter implements BackupDatabaseAdapter {
  _FakeAdapter(this.dbPath);
  final String dbPath;
  String? copiedTo;
  @override
  Future<void> backup(String destinationPath) async {
    copiedTo = destinationPath;
    await File(dbPath).copy(destinationPath);
  }
  @override
  Future<void> restore(String backupPath) async {}
  @override
  Future<String> get databasePath async => dbPath;
  @override
  AppDatabase get database => throw UnimplementedError();
}

class _FakeSafPort implements BackupSafPort {
  String? wroteSource;
  String? wroteName;
  @override
  Future<String> writeBackup({required String treeUri, required String fileName, required String sourcePath}) async {
    wroteSource = sourcePath;
    wroteName = fileName;
    return 'content://tree/1/doc/$fileName';
  }
  @override
  Future<void> readBackup({required String documentUri, required String destPath}) async {}
  @override
  Future<bool> delete(String documentUri) async => true;
  @override
  Future<bool> exists(String documentUri) async => true;
  @override
  Future<String?> resolveTree(String treeUri) async => 'Backups';
}

void main() {
  test('isSafRef detects content URIs', () {
    expect(isSafRef('content://x/y'), isTrue);
    expect(isSafRef('/storage/emulated/0/x.db'), isFalse);
  });

  test('FilesystemBackupTarget delegates to adapter.backup and returns the path', () async {
    final tmp = await Directory.systemTemp.createTemp('fbt_');
    addTearDown(() => tmp.delete(recursive: true));
    final src = File(p.join(tmp.path, 'src.db'));
    await src.writeAsString('db');
    final adapter = _FakeAdapter(src.path);

    final ref = await FilesystemBackupTarget(tmp.path).write(adapter, 'out.db');

    expect(ref, p.join(tmp.path, 'out.db'));
    expect(adapter.copiedTo, ref);
    expect(File(ref).existsSync(), isTrue);
  });

  test('SafBackupTarget writes the source DB via the port, returns the doc URI', () async {
    final port = _FakeSafPort();
    final adapter = _FakeAdapter('/data/live.db');

    final ref = await SafBackupTarget('content://tree/1', port).write(adapter, 'out.db');

    expect(ref, 'content://tree/1/doc/out.db');
    expect(port.wroteSource, '/data/live.db');
    expect(port.wroteName, 'out.db');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_target_test.dart`
Expected: FAIL — `backup_target.dart` not found / symbols undefined.

- [ ] **Step 3: Implement `backup_target.dart`**
```dart
import 'package:path/path.dart' as p;

import 'package:submersion/features/backup/data/services/backup_saf_port.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';

/// True iff [ref] is a SAF document/tree URI rather than a filesystem path.
/// Only Android's picker produces these, so it doubles as the platform branch.
bool isSafRef(String ref) => ref.startsWith('content://');

/// Where a backup is written. Two implementations: a filesystem directory
/// (default sandbox, desktop, Apple bookmarked dirs) and an Android SAF tree.
abstract class BackupTarget {
  /// Writes a backup named [fileName] using [adapter] to produce the bytes.
  /// Returns the stored ref: a filesystem path or a `content://` document URI.
  Future<String> write(BackupDatabaseAdapter adapter, String fileName);
}

/// Filesystem target. Delegates to [BackupDatabaseAdapter.backup] verbatim so
/// existing behavior (and its tests) are unchanged.
class FilesystemBackupTarget implements BackupTarget {
  const FilesystemBackupTarget(this.dir);
  final String dir;

  @override
  Future<String> write(BackupDatabaseAdapter adapter, String fileName) async {
    final dest = p.join(dir, fileName);
    await adapter.backup(dest);
    return dest;
  }
}

/// Android SAF target. Streams the live DB into the persisted tree via the port.
class SafBackupTarget implements BackupTarget {
  const SafBackupTarget(this.treeUri, this.port);
  final String treeUri;
  final BackupSafPort port;

  @override
  Future<String> write(BackupDatabaseAdapter adapter, String fileName) async {
    final source = await adapter.databasePath;
    return port.writeBackup(
      treeUri: treeUri,
      fileName: fileName,
      sourcePath: source,
    );
  }
}

/// A resolved target plus a release callback (arms/releases Apple security-scoped
/// access for filesystem targets; a no-op for SAF and the default location).
class BackupTargetLease {
  const BackupTargetLease(this.target, this._release);
  final BackupTarget target;
  final Future<void> Function() _release;
  Future<void> release() => _release();
}
```

- [ ] **Step 4: Run test + analyze**

Run: `flutter test test/features/backup/data/services/backup_target_test.dart`
Expected: PASS.
Run: `flutter analyze` — Expected: No issues.

- [ ] **Step 5: Commit**
```bash
git add lib/features/backup/data/services/backup_target.dart test/features/backup/data/services/backup_target_test.dart
git commit -m "feat(backup): add BackupTarget abstraction (filesystem + SAF) (#300)"
```

---

## Task A4: `resolveBackupTargetLeased` + rewire `performBackup`

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart`
- Test: `test/features/backup/data/services/backup_target_lease_test.dart`

**Interfaces:**
- Consumes: `BackupTarget`/`SafBackupTarget`/`FilesystemBackupTarget`/`BackupTargetLease`/`isSafRef` (A3), `BackupSafPort` (A2), existing `resolveBackupsDirectoryLeased`.
- Produces:
  - `BackupService` gains constructor param `BackupSafPort? safPort` (defaults to `const MethodChannelBackupSafPort()`).
  - `static Future<BackupTargetLease> BackupService.resolveBackupTargetLeased(BackupPreferences preferences, {BackupBookmarkPort? bookmarks, BackupSafPort? saf})`.

- [ ] **Step 1: Write the failing test** (SAF branch + self-heal; filesystem delegation)

`test/features/backup/data/services/backup_target_lease_test.dart`:
```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/backup_bookmark_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/backup_target.dart';

class _FakeSafPort implements BackupSafPort {
  _FakeSafPort({this.tree});
  final String? tree; // resolveTree result
  @override
  Future<String> writeBackup({required String treeUri, required String fileName, required String sourcePath}) async => 'content://doc';
  @override
  Future<void> readBackup({required String documentUri, required String destPath}) async {}
  @override
  Future<bool> delete(String documentUri) async => true;
  @override
  Future<bool> exists(String documentUri) async => true;
  @override
  Future<String?> resolveTree(String treeUri) async => tree;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupPreferences preferences;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = BackupPreferences(await SharedPreferences.getInstance());
  });
  tearDown(() => BackupBookmarkService.debugSupportedOverride = null);

  test('content:// location + live grant -> SafBackupTarget', () async {
    await preferences.setBackupLocation('content://tree/1');
    final lease = await BackupService.resolveBackupTargetLeased(
      preferences,
      saf: _FakeSafPort(tree: 'Backups'),
    );
    expect(lease.target, isA<SafBackupTarget>());
    await lease.release();
  });

  test('content:// location + dead grant -> self-heal to filesystem default', () async {
    await preferences.setBackupLocation('content://tree/gone');
    final lease = await BackupService.resolveBackupTargetLeased(
      preferences,
      saf: _FakeSafPort(tree: null),
    );
    expect(lease.target, isA<FilesystemBackupTarget>());
    expect(preferences.getSettings().backupLocation, isNull);
  });

  test('filesystem location -> FilesystemBackupTarget (delegates to existing resolver)', () async {
    final tmp = await Directory.systemTemp.createTemp('btl_');
    addTearDown(() => tmp.delete(recursive: true));
    await preferences.setBackupLocation(tmp.path);
    BackupBookmarkService.debugSupportedOverride = false;
    final lease = await BackupService.resolveBackupTargetLeased(preferences);
    expect(lease.target, isA<FilesystemBackupTarget>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_target_lease_test.dart`
Expected: FAIL — `resolveBackupTargetLeased` undefined.

- [ ] **Step 3: Add the import + field + method, and rewire `performBackup`**

In `backup_service.dart` add imports:
```dart
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';
import 'package:submersion/features/backup/data/services/backup_target.dart';
```
Add field + constructor param (place beside `_cloudProvider`):
```dart
  final BackupSafPort _safPort;
```
```dart
    BackupSafPort? safPort,
```
```dart
       _safPort = safPort ?? const MethodChannelBackupSafPort(),
```
Add the wrapper resolver (immediately after `resolveBackupsDirectoryLeased`):
```dart
  /// Resolves where the next backup goes as a [BackupTarget]. A `content://`
  /// custom location (Android SAF) yields a [SafBackupTarget] after confirming
  /// the persisted tree grant still resolves; a dead grant self-heals to the
  /// sandbox default. Everything else delegates to the existing filesystem
  /// resolver, leaving iOS/macOS/Windows/Linux behavior untouched.
  static Future<BackupTargetLease> resolveBackupTargetLeased(
    BackupPreferences preferences, {
    BackupBookmarkPort? bookmarks,
    BackupSafPort? saf,
  }) async {
    final custom = preferences.getSettings().backupLocation;
    if (custom != null && isSafRef(custom)) {
      final port = saf ?? const MethodChannelBackupSafPort();
      final label = await port.resolveTree(custom);
      if (label == null) {
        // Grant revoked or folder deleted: reset to default so backups keep
        // working (mirrors the Apple dead-bookmark self-heal). The settings
        // subtitle reverts to the default, signaling a re-pick is needed.
        await preferences.setBackupLocation(null);
        final dir = await resolveDefaultBackupsDirectory();
        return BackupTargetLease(FilesystemBackupTarget(dir), _noRelease);
      }
      return BackupTargetLease(SafBackupTarget(custom, port), _noRelease);
    }
    final lease = await resolveBackupsDirectoryLeased(
      preferences,
      bookmarks: bookmarks,
    );
    return BackupTargetLease(FilesystemBackupTarget(lease.path), lease.release);
  }
```
Rewrite `performBackup` to use the target, and change `_performBackupInto` to accept a `BackupTarget`:
```dart
  Future<BackupRecord> performBackup({bool isAutomatic = false}) async {
    _log.info('Starting backup (automatic: $isAutomatic)');
    final lease = await BackupService.resolveBackupTargetLeased(
      _preferences,
      saf: _safPort,
    );
    try {
      return await _performBackupInto(lease.target, isAutomatic: isAutomatic);
    } finally {
      await lease.release();
    }
  }

  Future<BackupRecord> _performBackupInto(
    BackupTarget target, {
    required bool isAutomatic,
  }) async {
    final filename = _generateFilename();
    final ref = await target.write(_dbAdapter, filename);

    // SAF refs are content URIs (no File length); the backup is a byte copy of
    // the live DB, so its size equals the source's. Filesystem refs keep the
    // existing File(ref).length() behavior.
    final sizeBytes = isSafRef(ref)
        ? await File(await _dbAdapter.databasePath).length()
        : await File(ref).length();

    final counts = await _getDiveSiteCounts();

    String? cloudFileId;
    var location = BackupLocation.local;
    final settings = _preferences.getSettings();
    if (settings.cloudBackupEnabled && _cloudProvider != null) {
      try {
        cloudFileId = await _uploadToCloud(ref, filename);
        location = BackupLocation.both;
        _log.info('Backup uploaded to cloud: $cloudFileId');
      } catch (e, stack) {
        _log.error('Cloud upload failed, backup is local-only',
            error: e, stackTrace: stack);
      }
    }

    final record = BackupRecord(
      id: _uuid.v4(),
      filename: filename,
      timestamp: DateTime.now(),
      sizeBytes: sizeBytes,
      location: location,
      diveCount: counts.diveCount,
      siteCount: counts.siteCount,
      cloudFileId: cloudFileId,
      localPath: ref,
      isAutomatic: isAutomatic,
    );

    await _preferences.addRecord(record);
    await _preferences.setLastBackupTime(record.timestamp);
    await pruneOldBackups(settings.retentionCount);
    _log.info('Backup completed: ${record.filename} (${record.formattedSize})');
    return record;
  }
```
(Note: cloud + custom location are mutually exclusive, so `_uploadToCloud(ref, …)` only ever receives a filesystem ref — no SAF read needed.)

- [ ] **Step 4: Run new + existing backup tests + analyze**

Run: `flutter test test/features/backup/data/services/backup_target_lease_test.dart test/features/backup/data/services/backup_service_leased_test.dart test/features/backup/data/services/backup_service_test.dart`
Expected: PASS (new SAF cases pass; the 9 leased cases and the service cases stay green — the old resolver is untouched).
Run: `flutter analyze` — Expected: No issues.

- [ ] **Step 5: Commit**
```bash
git add lib/features/backup/data/services/backup_service.dart test/features/backup/data/services/backup_target_lease_test.dart
git commit -m "feat(backup): route performBackup through BackupTarget with SAF self-heal (#300)"
```

---

## Task A5: Ref-aware restore / delete / history

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart`
- Test: `test/features/backup/data/services/backup_service_saf_refs_test.dart`

**Interfaces:**
- Consumes: `_safPort` (A4), `isSafRef` (A3).
- Produces: behavior changes only (no new public symbols).

- [ ] **Step 1: Write the failing test** (delete + history route SAF refs to the port; restore reads SAF to a temp file)

`test/features/backup/data/services/backup_service_saf_refs_test.dart`:
```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

class _NoopAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async {}
  @override
  Future<void> restore(String backupPath) async {}
  @override
  Future<String> get databasePath async => '/data/live.db';
  @override
  AppDatabase get database => throw UnimplementedError();
}

class _RecordingSafPort implements BackupSafPort {
  final List<String> deleted = [];
  final Set<String> existing = {};
  @override
  Future<String> writeBackup({required String treeUri, required String fileName, required String sourcePath}) async => 'content://doc';
  @override
  Future<void> readBackup({required String documentUri, required String destPath}) async {}
  @override
  Future<bool> delete(String documentUri) async { deleted.add(documentUri); return true; }
  @override
  Future<bool> exists(String documentUri) async => existing.contains(documentUri);
  @override
  Future<String?> resolveTree(String treeUri) async => 'Backups';
}

BackupRecord _saf(String id, String uri) => BackupRecord(
      id: id, filename: 'f.db', timestamp: DateTime(2026), sizeBytes: 1,
      location: BackupLocation.local, diveCount: 0, siteCount: 0, localPath: uri);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupPreferences prefs;
  late _RecordingSafPort port;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = BackupPreferences(await SharedPreferences.getInstance());
    port = _RecordingSafPort();
  });

  BackupService service() =>
      BackupService(dbAdapter: _NoopAdapter(), preferences: prefs, safPort: port);

  test('deleteBackup routes a SAF ref to the port', () async {
    final r = _saf('1', 'content://doc/1');
    await prefs.addRecord(r);
    await service().deleteBackup(r);
    expect(port.deleted, ['content://doc/1']);
  });

  test('getValidatedBackupHistory keeps a SAF record whose doc still exists', () async {
    port.existing.add('content://doc/keep');
    await prefs.addRecord(_saf('keep', 'content://doc/keep'));
    await prefs.addRecord(_saf('gone', 'content://doc/gone'));
    final valid = await service().getValidatedBackupHistory();
    expect(valid.map((r) => r.id), ['keep']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_service_saf_refs_test.dart`
Expected: FAIL — `deleteBackup` calls `File('content://…').delete()` (no-op, record not pruned by the port) and history uses `File.exists`.

- [ ] **Step 3: Make `deleteBackup`, `getValidatedBackupHistory`, and restore ref-aware**

In `deleteBackup`, replace the local-file block:
```dart
    if (record.localPath != null) {
      final ref = record.localPath!;
      if (isSafRef(ref)) {
        await _safPort.delete(ref);
        _log.info('Deleted SAF backup: $ref');
      } else {
        final file = File(ref);
        if (await file.exists()) {
          await file.delete();
          _log.info('Deleted local file: $ref');
        }
      }
    }
```
In `getValidatedBackupHistory`, replace the existence check:
```dart
      if (record.localPath != null && record.cloudFileId == null) {
        final ref = record.localPath!;
        final stillThere =
            isSafRef(ref) ? await _safPort.exists(ref) : await File(ref).exists();
        if (!stillThere) {
          _log.info('Pruning stale backup record: ${record.filename}');
          pruned = true;
          continue;
        }
      }
```
In `restoreFromBackup`, make the local source SAF-aware (read to a temp file before validating/restoring). Replace the source-path resolution block:
```dart
    String sourcePath;
    final localRef = record.localPath;
    if (localRef != null && isSafRef(localRef)) {
      if (!await _safPort.exists(localRef)) {
        throw const BackupException('Backup file not found locally or in cloud');
      }
      final tempDir = await getTemporaryDirectory();
      sourcePath = p.join(tempDir.path, record.filename);
      await _safPort.readBackup(documentUri: localRef, destPath: sourcePath);
    } else if (localRef != null && await File(localRef).exists()) {
      sourcePath = localRef;
    } else if (record.cloudFileId != null && _cloudProvider != null) {
      _log.info('Downloading backup from cloud');
      sourcePath = await _downloadFromCloud(record.cloudFileId!, record.filename);
    } else {
      throw const BackupException('Backup file not found locally or in cloud');
    }
```

- [ ] **Step 4: Run new + existing restore tests + analyze**

Run: `flutter test test/features/backup/data/services/backup_service_saf_refs_test.dart test/features/backup/data/services/backup_service_test.dart test/features/backup/presentation/providers/backup_providers_restore_test.dart`
Expected: PASS.
Run: `flutter analyze` — Expected: No issues.

- [ ] **Step 5: Commit**
```bash
git add lib/features/backup/data/services/backup_service.dart test/features/backup/data/services/backup_service_saf_refs_test.dart
git commit -m "feat(backup): ref-aware restore/delete/history for SAF backups (#300)"
```

---

## Task A6: Backup-settings picker (Android SAF branch) + label

**Files:**
- Modify: `lib/features/backup/data/repositories/backup_preferences.dart`
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart`
- Modify: `lib/features/backup/presentation/pages/backup_settings_page.dart`
- Test: `test/features/backup/data/repositories/backup_preferences_test.dart` (extend)

**Interfaces:**
- Produces:
  - `BackupPreferences.setBackupLocationLabel(String?)` and `String? get backupLocationLabel` (key `backup_location_label`).
  - `BackupSettingsNotifier.setSafBackupLocation(String uri, String label)`.

- [ ] **Step 1: Write the failing test** (label round-trips and is cleared with the location)

Append to `backup_preferences_test.dart`:
```dart
  test('backup location label round-trips and clears with the location', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = BackupPreferences(await SharedPreferences.getInstance());
    await prefs.setBackupLocation('content://tree/1');
    await prefs.setBackupLocationLabel('Backups');
    expect(prefs.backupLocationLabel, 'Backups');
    await prefs.setBackupLocation(null);
    expect(prefs.backupLocationLabel, isNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/repositories/backup_preferences_test.dart`
Expected: FAIL — `setBackupLocationLabel` undefined.

- [ ] **Step 3: Implement label storage** in `backup_preferences.dart`

Add key constant:
```dart
  static const String _backupLocationLabelKey = 'backup_location_label';
```
In `setBackupLocation`, when clearing (`path == null`) also remove the label:
```dart
      await _prefs.remove(_backupLocationLabelKey);
```
Add accessors:
```dart
  Future<void> setBackupLocationLabel(String? label) async {
    if (label == null) {
      await _prefs.remove(_backupLocationLabelKey);
    } else {
      await _prefs.setString(_backupLocationLabelKey, label);
    }
  }

  String? get backupLocationLabel => _prefs.getString(_backupLocationLabelKey);
```

- [ ] **Step 4: Add the notifier setter** in `backup_providers.dart` (beside `setBackupLocationWithBookmark`)
```dart
  /// Android SAF: persist a content:// tree URI as the location plus its human
  /// label for display. Turns cloud backup off, like any custom location.
  Future<void> setSafBackupLocation(String uri, String label) async {
    await _prefs.setCloudBackupEnabled(false);
    await _prefs.setBackupLocation(uri);
    await _prefs.setBackupLocationLabel(label);
    state = _prefs.getSettings();
  }
```

- [ ] **Step 5: Wire the picker + subtitle** in `backup_settings_page.dart`

Add import:
```dart
import 'package:submersion_saf/submersion_saf.dart';
```
Replace the picker `onPressed` body's platform branch so Android uses SAF (keep iOS and desktop intact):
```dart
              final BackupFolderPick? picked;
              if (Platform.isIOS) {
                picked = await BackupBookmarkService.pickFolder();
              } else if (Platform.isAndroid) {
                final folder = await SubmersionSaf.pickFolder();
                if (folder != null) {
                  await ref
                      .read(backupSettingsProvider.notifier)
                      .setSafBackupLocation(folder.uri, folder.displayName);
                }
                return; // SAF path persists directly; skip the bookmark flow.
              } else {
                final path = await FilePicker.getDirectoryPath(
                  dialogTitle: context.l10n.backup_location_title,
                );
                picked = path == null
                    ? null
                    : BackupFolderPick(
                        path: path,
                        bookmark: BackupBookmarkService.isSupported
                            ? await BackupBookmarkService.createBookmark(path)
                            : null,
                      );
              }
              if (picked != null) {
                await ref
                    .read(backupSettingsProvider.notifier)
                    .setBackupLocationWithBookmark(picked.path, picked.bookmark);
              }
```
Update the subtitle so a SAF location shows its label, not the raw URI:
```dart
          subtitle: Text(
            cloudDestination ??
                ref.read(backupSettingsProvider.notifier).locationLabel ??
                settings.backupLocation ??
                context.l10n.backup_location_default,
```
Add a `locationLabel` getter to the notifier:
```dart
  String? get locationLabel => _prefs.backupLocationLabel;
```

- [ ] **Step 6: Run tests + analyze + format**

Run: `flutter test test/features/backup/data/repositories/backup_preferences_test.dart test/features/backup/presentation/pages/backup_settings_page_test.dart test/features/backup/presentation/providers/backup_settings_notifier_test.dart`
Expected: PASS (update notifier mock test expectations if the new method trips a mock).
Run: `dart format .` then `flutter analyze` — Expected: formatted, No issues.

- [ ] **Step 7: Commit**
```bash
git add lib/features/backup test/features/backup
git commit -m "feat(backup): Android SAF folder picker + label display (#300)"
```

---

# Part B — Custom DB location (Internal / SD card)

## Task B1: Android external-dir chooser for the DB location

**Files:**
- Modify: `lib/core/services/database_location_service.dart`
- Test: `test/core/services/database_location_external_dirs_test.dart`

**Interfaces:**
- Produces:
  - `class ExternalVolumeOption { final String path; final String label; }`
  - `List<ExternalVolumeOption> labelExternalDirs(List<String> dirPaths)` — pure, testable: index 0 / `emulated` segment → "Internal storage"; others → "SD card".

- [ ] **Step 1: Write the failing test**

`test/core/services/database_location_external_dirs_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_location_service.dart';

void main() {
  test('labels the emulated volume Internal and others SD card', () {
    final opts = labelExternalDirs([
      '/storage/emulated/0/Android/data/app.submersion/files',
      '/storage/1A2B-3C4D/Android/data/app.submersion/files',
    ]);
    expect(opts[0].label, 'Internal storage');
    expect(opts[1].label, 'SD card');
    expect(opts[1].path, contains('1A2B-3C4D'));
  });

  test('single volume is Internal', () {
    final opts = labelExternalDirs(['/storage/emulated/0/Android/data/x/files']);
    expect(opts.single.label, 'Internal storage');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/database_location_external_dirs_test.dart`
Expected: FAIL — `labelExternalDirs`/`ExternalVolumeOption` undefined.

- [ ] **Step 3: Implement the labeler + Android picker branch**

Add to `database_location_service.dart` (top-level, below the class or above it):
```dart
/// A selectable external volume for the database location (Android).
class ExternalVolumeOption {
  const ExternalVolumeOption({required this.path, required this.label});
  final String path;
  final String label;
}

/// Labels app-specific external dirs without native code: the primary emulated
/// volume is "Internal storage"; any other volume is "SD card".
List<ExternalVolumeOption> labelExternalDirs(List<String> dirPaths) {
  final out = <ExternalVolumeOption>[];
  for (var i = 0; i < dirPaths.length; i++) {
    final path = dirPaths[i];
    final isInternal = i == 0 || path.contains('/storage/emulated/');
    out.add(ExternalVolumeOption(
      path: path,
      label: isInternal ? 'Internal storage' : 'SD card',
    ));
  }
  return out;
}
```
Add `import 'package:flutter/material.dart';` if not present (for the chooser dialog) and a parameterized chooser hook. In `pickCustomFolder`, insert an Android branch before the existing `else` (file_picker), keeping iOS and desktop intact:
```dart
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories();
      if (dirs == null || dirs.isEmpty) return null;
      final options = labelExternalDirs(dirs.map((d) => d.path).toList());
      final chosen = await _chooseExternalVolume?.call(options) ??
          options.first; // _chooseExternalVolume injected by the UI; default first
      final dbDir = p.join(chosen.path, 'Submersion');
      await Directory(dbDir).create(recursive: true);
      return FolderPickResultWithBookmark(path: dbDir);
    }
```
Add an injectable chooser callback field (set by the settings UI; nullable so headless/default callers fall back to the first volume):
```dart
  /// UI hook to let the user choose among external volumes (Android). Injected
  /// by the storage settings page; when null the first (internal) volume is used.
  Future<ExternalVolumeOption?> Function(List<ExternalVolumeOption>)?
      _chooseExternalVolume;
  set externalVolumeChooser(
          Future<ExternalVolumeOption?> Function(List<ExternalVolumeOption>)? f) =>
      _chooseExternalVolume = f;
```
Fix the stale comment on `isCustomFolderSupported`:
```dart
  /// - Android: app-specific external storage (internal or SD card). The live
  ///   DB needs a real path; arbitrary SAF folders cannot back a SQLite file.
```
Add import:
```dart
import 'package:path_provider/path_provider.dart';
```
(`getExternalStorageDirectories` — already transitively available; ensure the symbol resolves.)

- [ ] **Step 4: Run test + analyze**

Run: `flutter test test/core/services/database_location_external_dirs_test.dart`
Expected: PASS.
Run: `flutter analyze` — Expected: No issues.

- [ ] **Step 5: Commit**
```bash
git add lib/core/services/database_location_service.dart test/core/services/database_location_external_dirs_test.dart
git commit -m "feat(db-location): Android internal/SD-card chooser via external dirs (#300)"
```

---

## Task B2: Localize the DB-location strings + wire the chooser UI

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` + all non-en locale ARBs in `lib/l10n/arb/`
- Modify: the storage settings page that calls `pickCustomFolder` (set `externalVolumeChooser` to a real dialog using the localized strings)
- Modify: `lib/core/services/database_location_service.dart` (replace the hardcoded English labels with keys passed in from the UI, OR keep labels in UI layer)

**Interfaces:**
- Consumes: `labelExternalDirs`, `ExternalVolumeOption` (B1).

- [ ] **Step 1: Add English ARB keys** in `app_en.arb`:
```json
  "db_location_internal": "Internal storage",
  "db_location_sd_card": "SD card",
  "db_location_choose_volume": "Choose storage volume",
  "db_location_external_note": "Files here are removed if you uninstall the app."
```

- [ ] **Step 2: Add translations** for all 10 non-en locales (`app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`) — real translations, following the locale's existing entries. (Move the "Internal storage"/"SD card" literals out of `labelExternalDirs` into the UI chooser so they use these keys; `labelExternalDirs` returns a stable enum/flag the UI maps to a localized string. Adjust B1's labeler to return `isInternal` and let the UI pick the string, to avoid English in the service layer.)

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: `app_localizations*.dart` regenerated with the new getters.

- [ ] **Step 4: Wire the chooser** in the storage settings page: set `service.externalVolumeChooser` to show a dialog listing the localized volume labels + the uninstall note, returning the chosen `ExternalVolumeOption`.

- [ ] **Step 5: Run tests + analyze + format**

Run: `flutter test test/core/services/ test/features/settings/`
Expected: PASS.
Run: `dart format .` && `flutter analyze` — Expected: clean.

- [ ] **Step 6: Commit**
```bash
git add lib/l10n lib/core/services/database_location_service.dart lib/features/settings
git commit -m "feat(db-location): localized internal/SD-card chooser UI (#300)"
```

---

## Task C1: Full verification pass

**Files:** none (verification + spec/plan already committed)

- [ ] **Step 1: Format + analyze whole project**

Run: `dart format --set-exit-if-changed .`
Run: `flutter analyze`
Expected: both clean.

- [ ] **Step 2: Run the backup + DB-location + l10n test suites**

Run: `flutter test test/features/backup test/core/services test/core/database`
Expected: all PASS.

- [ ] **Step 3: Android build smoke**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Record device-verification checklist** (cannot be automated; the reporter offered to test):
  - Manual "Backup Now" to an internal folder and an SD-card folder → success, file visible in a file manager.
  - Automatic backup (toggle on, force the Workmanager task) lands in the chosen folder with the app backgrounded.
  - Restore from a SAF backup.
  - Relocate the DB to the SD card and back; data intact.
  - Revoke the folder permission → next backup self-heals to default.

- [ ] **Step 5: Final commit (if any formatting changes)**
```bash
git add -A
git commit -m "chore: format + verification pass for Android SAF backups (#300)"
```

---

## Self-review notes

- Spec §4 (SAF backups) → Tasks A1–A6. Spec §5 (DB location) → Tasks B1–B2. Spec §3.1 platform gating → enforced by `isSafRef` discrimination (A3/A4) and the Android-only picker branches (A6/B1).
- Background isolate (spec §4.6): satisfied by A1 making SAF a registered plugin (auto-registered in the Workmanager engine); no code beyond A1.
- Self-heal (spec §4.5): A4 `resolveBackupTargetLeased`.
- Open follow-ups (spec §8) intentionally not tasked: nicer SD labels via `StorageManager`; migrating media SAF to the new plugin.
- Note: B2 refines B1 by moving the English volume labels into the UI layer for localization; implement B1's labeler returning an `isInternal` flag if you prefer to avoid the small churn (either is acceptable; B2 step 2 calls this out).
