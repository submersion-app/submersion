# Android backup & custom DB-location under scoped storage (issue #300)

Status: approved 2026-06-21
Date: 2026-06-20
Issue: https://github.com/submersion-app/submersion/issues/300

## 1. Problem & root cause

A user on Android 16 (Samsung A52s, LineageOS, no Play Services) sets a custom
backup folder, grants access, and every backup — manual and automatic — fails:

```
Backup failed: PathAccessException: Cannot copy file to <folder>
path = '/data/user/0/app.submersion/app_flutter/Submersion/submersion.db'
(OS Error: Operation not permitted, errno = 1)
```

Root cause (verified end-to-end in the code and plugin sources):

1. The folder is picked with `FilePicker.getDirectoryPath()`. In `file_picker`
   11.0.2 that resolves the SAF tree URI down to a raw `/storage/...` path
   (`FileUtils.getFullPathFromTreeUri`, FileUtils.kt:612) and **discards the
   `content://` URI** — it never calls `takePersistableUriPermission`.
2. The raw path is stored in `SharedPreferences` as `backup_location`.
3. At backup time `BackupService.resolveBackupsDirectoryLeased` treats the
   stored value as a bare writable directory (the comment literally says
   *"Desktop/Android: bare custom paths persist and work without scoping"*).
4. `DatabaseService.backup` does `File(sourceDb).copy(dest)` into it.

On Android 11+ an app cannot write to arbitrary shared-storage paths with
`dart:io`. The manifest has only `READ_EXTERNAL_STORAGE` (maxSdkVersion 32) and
no `MANAGE_EXTERNAL_STORAGE`, so the copy is `EPERM`. The grant the user gave is
a SAF `content://` tree-URI permission, which `File` cannot use.

The identical bug exists for the **custom database location**
(`DatabaseLocationService.pickCustomFolder` → `getDirectoryPath` →
`getDatabasePath` opens the live DB at `customFolderPath/submersion.db`). Its
comment even claims "Android: Uses Storage Access Framework (SAF)" — it does not.

## 2. Goals / non-goals

Goals:
- Manual **and automatic** backups to a user-chosen folder succeed on Android 11+.
- Restore, delete, prune, and history validation work for those backups.
- Custom DB location works on Android (the reporter specifically wants the SD card).
- No broad permissions (`MANAGE_EXTERNAL_STORAGE`); no third-party SAF library.
- Existing iOS / macOS / Windows / Linux behavior unchanged.
- Existing already-broken Android configs self-heal (no bricking, no lost backups).

Non-goals:
- Arbitrary-folder placement of the *live database* (SQLite needs a real lockable
  path; SAF streams cannot back a live DB). DB location is a curated choice.
- Cloud backup changes (a custom location and cloud backup remain mutually
  exclusive, as today).

## 3. Why two different mechanisms

A **backup** is a one-shot file write — SAF (`content://` + `DocumentFile` +
`ContentResolver` streams) is the correct Android tool. The **live database** is
opened by SQLite via a POSIX path and relies on byte-range locks, `mmap`, and
`-wal`/`-shm` sidecars, none of which work over a SAF stream. So:

| Feature        | Android mechanism                                        |
| -------------- | -------------------------------------------------------- |
| Backups        | SAF: persisted tree URI + DocumentFile writes (new plugin) |
| DB location    | App-specific external dirs (`getExternalStorageDirectories`) — real writable paths |

## 3.1 Platform impact

This change is **Android-only in behavior**. iOS, macOS, Windows, and Linux are
unchanged by design. Desktop does not need the fix: a user-picked folder there is
a normal writable POSIX path, so `File.copy` already works.

Gating contract the implementation and review MUST honor: every new behavior is
guarded by `Platform.isAndroid`, and `submersion_saf` is declared Android-only
(not registered, no native code, never called elsewhere; all call sites are
`Platform.isAndroid`-gated).

The risk is not new behavior on other platforms but the fact that Android is
currently **lumped into the same branch** as desktop in three shared code points.
Each must be split so only Android changes:

| Shared code point | Today Android shares with | Change | Must stay identical |
| ----------------- | ------------------------- | ------ | ------------------- |
| Backup picker (`backup_settings_page.dart`) | `else` = Android + macOS + Win + Linux | add `else if (isAndroid)` → SAF | macOS file_picker+bookmark; Win/Linux file_picker |
| `resolveBackupsDirectoryLeased` `!isSupported` branch | Android + Win + Linux (bare path) | gate SAF + self-heal on `isAndroid` | Win/Linux bare-path behavior |
| DB picker (`database_location_service.dart`) | `else` = Android + macOS + Win + Linux | add `else if (isAndroid)` → external-dir chooser | macOS/Win/Linux file_picker |

Two guardrails contain the refactor risk: (1) `BackupTarget` / `BackupRecord`
ref-routing keeps the filesystem path behavior-identical — a non-`content://` ref
always takes the old path; (2) the existing backup test suite runs on **Linux
CI**, so any regression to the shared filesystem path is caught automatically.
iOS/macOS security-scoped paths are not modified.

## 4. Part A — SAF backups

### 4.1 In-repo plugin `submersion_saf` (the linchpin)

Automatic backups run in Workmanager's background isolate. That isolate's
`FlutterEngine(applicationContext)` (workmanager_android `BackgroundWorker.kt:68`)
auto-registers **pub plugins** via `GeneratedPluginRegistrant`, but app-local
channels declared in `MainActivity.configureFlutterEngine` are not in
`GeneratedPluginRegistrant` and are therefore **absent** in the background engine.

To make SAF reachable from both the UI engine and the background isolate, the
native SAF code lives in a small **in-repo Flutter plugin** (path dependency,
our own Kotlin — not a third-party SAF package). Being a "plugin", `flutter pub
get` adds it to `GeneratedPluginRegistrant`, so it auto-registers in every
engine, including Workmanager's.

Layout:
```
packages/submersion_saf/
  pubspec.yaml                       # flutter.plugin.platforms.android only
  lib/submersion_saf.dart            # Dart facade (MethodChannel)
  android/build.gradle
  android/src/main/kotlin/app/submersion/saf/SubmersionSafPlugin.kt
```
App `pubspec.yaml` gains `submersion_saf: { path: packages/submersion_saf }`.

The plugin is `FlutterPlugin` + `ActivityAware`:
- `onAttachedToEngine` registers the channel using `binding.applicationContext`.
  All non-UI methods use `applicationContext` + `contentResolver`, so they work
  in the background isolate with no Activity.
- `onAttachedToActivity` stores the Activity only for `pickFolder` (UI-only).

Channel `app.submersion/saf`, methods:
- `pickFolder() -> {uri: String, displayName: String}?` — launches
  `ACTION_OPEN_DOCUMENT_TREE`, `takePersistableUriPermission(READ|WRITE)`,
  returns the tree URI + the folder's display name. Uses an
  `ActivityResultListener` (the pattern `file_picker`'s `FilePickerDelegate`
  uses). Returns null on user-cancel. This is the only method needing an Activity.
- `writeBackup(treeUri, fileName, sourcePath) -> String` (the created document
  URI) — `DocumentFile.fromTreeUri(...).createFile("application/octet-stream",
  fileName)`, then stream-copy `File(sourcePath)` (app-private, natively readable)
  into `contentResolver.openOutputStream(doc.uri)`. **Streamed, not bytes over the
  channel** (the DB can be many MB). `application/octet-stream` is used so the
  provider keeps the supplied `*.db` display name (verify on device — some
  providers rewrite extensions by MIME; fall back to a `.db`-mapped MIME if so).
- `readBackup(documentUri, destPath) -> String` — `openInputStream(uri)` copied
  to `File(destPath)` (a temp file), for restore/validation.
- `delete(documentUri) -> bool` — `DocumentFile.fromSingleUri(uri).delete()`.
- `exists(documentUri) -> bool` — `DocumentFile.fromSingleUri(uri).exists()`.
- `resolveTree(treeUri) -> String?` (display name, or null if the grant is gone)
  — used for the settings label and self-heal.

`SecurityException`/`IllegalArgumentException` map to typed channel errors that
the Dart side treats as "location unusable" (triggers self-heal), never a raw
`PathAccessException`.

The child document URI is reachable under the persisted **tree** grant across
restarts, so only the tree URI is persisted as the location; per-backup child
URIs live in the backup history records.

### 4.2 Dart seam — `BackupTarget`

Replace the leaky "return a directory path, caller does `File.copy`" seam with a
polymorphic target. `resolveBackupsDirectoryLeased` (which returns a path today)
becomes `resolveBackupTargetLeased` returning a `BackupTarget`:

- `FilesystemBackupTarget(dir)` — current behavior verbatim: default sandbox dir,
  desktop bare paths, Apple security-scoped bookmarked dirs. `write` = `File.copy`.
- `SafBackupTarget(treeUri, port)` — `write` calls `port.writeBackup(...)`.

```dart
abstract class BackupTarget {
  /// Writes the source DB as [fileName]; returns a ref (path or content URI).
  Future<String> write(String sourceDbPath, String fileName);
  Future<void> release();
}
```

`_performBackupInto` is rewritten to ask the target to `write` and to store the
returned ref as `BackupRecord.localPath` (a path for filesystem, a `content://`
document URI for SAF). The recorded `sizeBytes` is taken from
`File(sourceDbPath).length()` — the backup is a byte copy of the source DB, so
its size equals the source's. This removes today's `File(localPath).length()`,
which would fail on a `content://` ref, and needs no SAF stat call.

The SAF channel is wrapped behind a `BackupSafPort` interface (mirroring the
existing `BackupBookmarkPort`) so `SafBackupTarget` and the record helpers are
unit-tested against a fake with no native channel.

### 4.3 Ref-aware record handling

`BackupRecord.localPath` is already nullable `String`; it now may hold a
`content://` URI. Add a small helper:

```dart
bool isSafRef(String ref) => ref.startsWith('content://');
```

Touch points that currently assume a filesystem path, each routed through the
port when `isSafRef`:
- `restoreFromBackup` / `restoreFromFile`: if the source ref is a SAF URI,
  `port.readBackup(uri, tempPath)` first, then validate + restore from the temp
  file (existing path-based `validateBackupFile` is reused on the temp copy).
- `deleteBackup`: `port.delete(uri)` instead of `File(...).delete()`.
- `getValidatedBackupHistory`: `port.exists(uri)` instead of `File(...).exists()`
  (otherwise SAF backups would be wrongly pruned from history).

Size is recorded at write time from the source DB length (see 4.2), so no
read-back of a `content://` ref is needed for sizing.

### 4.4 Picker wiring & storage

`backup_settings_page.dart`: on Android call `SubmersionSaf.pickFolder()` instead
of `FilePicker.getDirectoryPath()`. iOS keeps `BackupBookmarkService.pickFolder`;
desktop keeps `file_picker`. Store the tree URI in the existing `backup_location`
key and add `backup_location_label` (the display name) so the settings subtitle
shows e.g. "Backups" rather than a raw `content://…` string.

### 4.5 Migration / self-heal

Existing Android users have a dead `/storage/...` string in `backup_location`.
In `resolveBackupTargetLeased`, on Android:
- If the stored location is not a `content://` URI, or `resolveTree` returns null
  (grant gone / folder deleted), reset to the sandbox default
  (`setBackupLocation(null)`) so backups keep working, and flag the settings row
  to prompt a re-pick. This mirrors the Apple dead-bookmark reset already present.

### 4.6 Background isolate

No code change beyond 4.1: because `submersion_saf` is a registered plugin, the
Workmanager engine has the `app.submersion/saf` channel, and `writeBackup` uses
`applicationContext`. Automatic backups write straight to the chosen folder with
the app closed. The persisted URI permission is app-global, so it is valid in the
worker process.

### 4.7 Pre-migration backups (unchanged)

`PreMigrationBackupService` writes to the sandbox default (never the custom
location) and is unaffected.

## 5. Part B — DB location (Internal / SD card)

Single surgical change in `DatabaseLocationService.pickCustomFolder()` on Android:
replace `FilePicker.getDirectoryPath()` with a curated chooser over
`getExternalStorageDirectories()` (path_provider), which returns app-specific
dirs on each volume — internal emulated storage and the removable SD card — as
real, writable paths with no permissions. The chosen path is
`<extDir>/Submersion` (created if needed), consistent with the default layout.

Labeling without native code: index/volume heuristic — a path segment of
`emulated` → "Internal storage"; otherwise "SD card". Presented via a simple
selection dialog/sheet.

Everything downstream is unchanged and path-based:
`verifyFolderAccessible` (writes a `.submersion_test` file — succeeds on these
dirs), `migrateToCustomFolder` → `_copyDatabaseFiles` (`File.copy` of
`.db`/`-wal`/`-shm`), `getDatabasePath` (`join(path, 'submersion.db')`). Fix the
stale `isCustomFolderSupported` comment.

Caveat surfaced in UI copy: app-specific external dirs are cleared on uninstall
(appropriate for a live DB; backups handle portability).

## 6. Error handling & edge cases

- Pick cancelled → no-op, location unchanged.
- Grant revoked / folder deleted between backups → typed error → self-heal to
  default + re-pick prompt; the in-app backup history `exists` check prunes the
  now-unreadable record only if it has no other copy.
- Large DB → streamed natively, never marshalled through Dart.
- SAF MIME/extension quirk → validated on device (4.1).
- Custom location + cloud backup remain mutually exclusive (no SAF read needed
  for cloud upload).
- DB-location SD card removed → `verifyFolderAccessible` fails on next switch;
  existing migration error handling applies (no silent data loss; the live DB is
  only ever *moved* after a verified copy).

## 7. Testing

Dart unit tests (no native channel — use fakes):
- `SafBackupTarget.write` calls the port and returns the document URI.
- Ref routing: restore/delete/history-validation pick SAF vs filesystem paths
  from a fake `BackupSafPort` and a fake filesystem.
- Self-heal: a non-`content://` Android location resets to default.
- `FilesystemBackupTarget` keeps all existing backup tests green (old path
  unchanged).
- DB-location: Android picker returns an external-dir path; migration reuses
  existing covered logic.

Native (device-verified, not in the Dart suite): `DocumentFile` create/write/
read/delete, `takePersistableUriPermission` persistence across restart, and an
**automatic** (Workmanager) backup landing in the chosen folder with the app
closed — on the reporter's Android 16 device class.

## 8. Out of scope / follow-ups

- Nicer SD-card labels via `StorageManager.getStorageVolumes()` (would add native
  code; heuristic labels ship first).
- Migrating existing media-source SAF handling to the new plugin (LocalMediaHandler
  stays as-is; no behavior change intended).

## 9. Rollout

Code + Dart tests land in this PR. Hardware verification (manual + automatic
backup to internal and SD card, restore, and DB relocation) is pending on a real
Android 11+ device, consistent with how other native Android work in this repo is
validated. The reporter offered to test.
