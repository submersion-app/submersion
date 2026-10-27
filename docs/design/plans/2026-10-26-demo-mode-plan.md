# Demo Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let anyone open a downloaded, anonymised sample logbook in a sealed demo mode, explore every part of the app, and exit back to their own data exactly as it was.

**Architecture:** Demo mode is a separate SQLite file under the app support directory, opened through the existing `DatabaseService.reinitializeAtPath` and `restartApp()` path, with a persisted state file as the single source of truth. All app-wide SharedPreferences are snapshotted on entry and restored on exit. A process-wide `DemoModeGate` seals every import, export, backup, restore, sync and database-file operation at the engine level, while the router and a small UI guard explain the seal. The sample logbook is built by two `flutter test`-driven tools under `tool/demo_data/` (harvest real dive shapes, build the demo database) and published on a `demo-data` GitHub release.

**Tech Stack:** Flutter, Riverpod, Drift/SQLite (SQLCipher-capable), `http`, `crypto`, `archive`, go_router, flutter_test as the tool runner.

**Spec:** `docs/design/specs/2026-10-26-demo-mode-design.md` (issue #3708, release v1.8.4)

## Global Constraints

- Feature code lives under `lib/features/demo_mode/{data,domain,presentation}`; generator code under `tool/demo_data/`.
- Files stay 200 to 400 lines, 800 max.
- Every new string is added to `lib/l10n/arb/app_en.arb` and translated in all 10 other locales (ar, de, es, fr, he, hu, it, nl, pt, zh); run `flutter gen-l10n`; `test/l10n/` must stay green.
- Paths are built with `p.join`; temp space comes from `Directory.systemTemp`.
- Tests that change process-wide state (`DemoModeGate.instance`, `DatabaseService.instance`, `SharedPreferences` mocks, `HttpOverrides`) restore it in `addTearDown`.
- No attribution lines or tool names in any text. No em dashes in code, comments or docs.
- Manifest URL: `https://github.com/submersion-app/submersion/releases/download/demo-data/demo-manifest.json`.
- The `demo-data` release is created with `--latest=false`.
- Excluded generated sources, refused by name: `Synthetic dives 1000.uddf`, `submersion_multitank_500dives.uddf`, any path containing `scrubber-1500-dives`.
- Demo database download: 5 MB or less compressed; whole package (database plus photos): 15 MB or less.
- About 300 dives over six years; 8 to 12 CCR dives in the most recent phase.
- Dates shift by whole weeks so the latest dive lands 7 to 13 days before today.
- Before every commit: `dart format .`, `flutter analyze`, the affected tests, and `test/architecture/` plus `test/shared/` when files under `lib/` were added.
- Stage explicit paths only (never a directory) so throwaway screenshot tests never ride a commit.

## Review Focus

1. **The app is killed mid-entry or mid-exit.** On relaunch the user is either fully in demo mode or fully back in their logbook, prefs intact. Pinned in Task 6 (`resolveStartup` phase tests).
2. **The user has database encryption on.** Entering never applies their key to the plaintext demo file, startup's self-heal never flips `db_encryption_enabled`, and exit reopens the real file with the key. Pinned in Task 6.
3. **The user keeps their database in a custom folder.** Exit returns to that folder, and `db_storage_mode` / `db_custom_path` read the same after exit. Pinned in Task 6.
4. **The manifest is unreachable, malformed, or only lists newer schemas.** Both entry points stay hidden and nothing throws. Pinned in Tasks 4 and 12.
5. **A sync timer or background task is already scheduled when demo mode starts.** It fires and does nothing. Pinned in Tasks 7 and 8.

---

## Phase A: Demo state foundation

### Task 1: Domain models

**Files:**
- Create: `lib/features/demo_mode/domain/demo_state.dart`
- Create: `lib/features/demo_mode/domain/demo_manifest.dart`
- Create: `lib/features/demo_mode/domain/demo_sealed_feature.dart`
- Test: `test/features/demo_mode/domain/demo_state_test.dart`
- Test: `test/features/demo_mode/domain/demo_manifest_test.dart`

**Interfaces:**
- Produces:
  - `enum DemoPhase { entering, active, exiting }`
  - `class DemoState extends Equatable { final DemoPhase phase; final bool fromFirstRun; final DateTime enteredAt; DemoState copyWith({DemoPhase? phase}); Map<String, Object?> toJson(); factory DemoState.fromJson(Map<String, Object?>); }`
  - `class DemoPackage extends Equatable { final int schemaVersion; final Uri url; final String sha256; final int size; final DateTime generatedAt; factory DemoPackage.fromJson(Map<String, Object?>); Map<String, Object?> toJson(); }`
  - `class DemoManifest extends Equatable { static const currentFormatVersion = 1; final int formatVersion; final List<DemoPackage> packages; static DemoManifest? tryParse(String json); DemoPackage? bestFor(int appSchemaVersion); }`
  - `enum DemoSealedFeature { sync, sharedLibrary, backup, restore, fileImport, diveComputerDownload, cloudImport, mediaImport, export, share, databaseFile }`
  - `class DemoModeSealedException implements Exception { const DemoModeSealedException(this.feature); final DemoSealedFeature feature; }`

- [ ] **Step 1: Write the failing tests**

```dart
test('DemoState round-trips through JSON', () {
  final s = DemoState(phase: DemoPhase.active, fromFirstRun: true, enteredAt: DateTime.utc(2026, 10, 26, 9));
  expect(DemoState.fromJson(s.toJson()), s);
});

test('bestFor picks the newest schema not above the app', () {
  final m = DemoManifest.tryParse(manifestJson(schemas: [300, 318, 320]))!;
  expect(m.bestFor(318)!.schemaVersion, 318);
  expect(m.bestFor(310)!.schemaVersion, 300);
  expect(m.bestFor(299), isNull);
});

test('tryParse returns null for malformed JSON, a wrong formatVersion, or a bad entry', () {
  expect(DemoManifest.tryParse('{'), isNull);
  expect(DemoManifest.tryParse('{"formatVersion": 2, "packages": []}'), isNull);
  expect(DemoManifest.tryParse('{"formatVersion": 1, "packages": [{"schemaVersion": "x"}]}'), isNull);
});

test('tryParse rejects a package url that is not https', () {
  expect(DemoManifest.tryParse(manifestJson(schemas: [318], url: 'http://x/y.zip')), isNull);
});
```

`manifestJson` is a local helper in the test file building `{"formatVersion":1,"packages":[...]}` with `sha256` of 64 hex chars and `size` 1000.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/demo_mode/domain/`
Expected: FAIL (files do not exist)

- [ ] **Step 3: Implement the three domain files**

`tryParse` catches every `FormatException`/`TypeError` and returns null. `sha256` must match `^[0-9a-f]{64}$`.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/features/demo_mode/domain/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/demo_mode/domain/demo_state.dart lib/features/demo_mode/domain/demo_manifest.dart lib/features/demo_mode/domain/demo_sealed_feature.dart test/features/demo_mode/domain/demo_state_test.dart test/features/demo_mode/domain/demo_manifest_test.dart
git commit -m "feat(demo-mode): state, manifest and sealed-feature models"
```

### Task 2: Paths, state store and the gate

**Files:**
- Create: `lib/features/demo_mode/data/demo_paths.dart`
- Create: `lib/features/demo_mode/data/demo_state_store.dart`
- Create: `lib/features/demo_mode/data/demo_mode_gate.dart`
- Test: `test/features/demo_mode/data/demo_state_store_test.dart`
- Test: `test/features/demo_mode/data/demo_mode_gate_test.dart`

**Interfaces:**
- Consumes: Task 1 models.
- Produces:
  - `class DemoPaths { const DemoPaths(this.supportDir); final String supportDir; String get root; /* p.join(supportDir, 'demo_mode') */ String get stateFile; /* root/state.json */ String get prefsSnapshotFile; /* root/prefs_snapshot.json */ String get packageFile; /* root/package.zip */ String get databaseFile; /* root/submersion_demo.db */ String get photosDir; /* root/photos */ static Future<DemoPaths> resolve(); /* getApplicationSupportDirectory */ }`
  - `class DemoStateStore { DemoStateStore(this.paths); Future<DemoState?> read(); Future<void> write(DemoState state); Future<void> deleteAll(); }` (`write` writes `state.json.tmp` then renames; `deleteAll` removes `root` recursively; `read` returns null for a missing or unparseable file)
  - `class DemoModeGate { static final DemoModeGate instance; bool get isActive; Future<void> load(DemoStateStore store); void markActive(bool value); void ensureNotDemo(DemoSealedFeature feature); @visibleForTesting void resetForTesting(); }`. `isActive` is true for phases `active` and `exiting`. `ensureNotDemo` throws `DemoModeSealedException(feature)` when active.

- [ ] **Step 1: Write the failing tests**

```dart
test('write then read returns the same state, and a half-written tmp file is ignored', ...);
test('read returns null for a corrupt state file', ...);
test('deleteAll removes the whole demo directory', ...);
test('gate is active only for active and exiting phases', () async {
  for (final (phase, active) in [(DemoPhase.entering, false), (DemoPhase.active, true), (DemoPhase.exiting, true)]) {
    await store.write(stateWith(phase));
    await DemoModeGate.instance.load(store);
    expect(DemoModeGate.instance.isActive, active);
  }
});
test('ensureNotDemo throws DemoModeSealedException with the feature', () {
  DemoModeGate.instance.markActive(true);
  expect(() => DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.sync),
      throwsA(isA<DemoModeSealedException>().having((e) => e.feature, 'feature', DemoSealedFeature.sync)));
});
```

Each test uses `Directory.systemTemp.createTempSync()` and `addTearDown(DemoModeGate.instance.resetForTesting)`.

- [ ] **Step 2: Run to verify they fail** (`flutter test test/features/demo_mode/data/`, FAIL)
- [ ] **Step 3: Implement the three files**
- [ ] **Step 4: Run to verify they pass** (PASS)
- [ ] **Step 5: Add `DemoModeGate` to the global-state guard**

Check `test/architecture/test_global_state_restored_test.dart` and `docs/developer/testing.md`; register `DemoModeGate.instance.markActive` as a process-wide setter that must be restored, following how existing singletons are listed. Run `flutter test test/architecture/`. Expected: PASS.

- [ ] **Step 6: Commit** (`feat(demo-mode): demo state store and process-wide gate`)

### Task 3: Preferences snapshot

**Files:**
- Create: `lib/features/demo_mode/data/prefs_snapshot.dart`
- Test: `test/features/demo_mode/data/prefs_snapshot_test.dart`

**Interfaces:**
- Produces: `class PrefsSnapshot { static Future<void> capture(SharedPreferences prefs, File file); static Future<void> restore(SharedPreferences prefs, File file); }`. JSON shape: `{"version":1,"values":{"key":{"t":"bool|int|double|string|stringList","v":...}}}`. `restore` removes every key not in the snapshot, then writes each value with its type. A missing or unreadable snapshot throws `StateError` (exit must not silently wipe prefs).

- [ ] **Step 1: Write the failing tests**

```dart
test('restore brings back every key with its exact type and drops keys added since', () async {
  SharedPreferences.setMockInitialValues({'b': true, 'i': 3, 'd': 1.5, 's': 'x', 'l': ['a', 'b'], 'current_diver_id': 'real'});
  final prefs = await SharedPreferences.getInstance();
  await PrefsSnapshot.capture(prefs, file);
  await prefs.setString('current_diver_id', 'demo-diver');
  await prefs.setBool('sync_auto_enabled', true);
  await PrefsSnapshot.restore(prefs, file);
  expect(prefs.getString('current_diver_id'), 'real');
  expect(prefs.containsKey('sync_auto_enabled'), isFalse);
  expect(prefs.getDouble('d'), 1.5);
  expect(prefs.getStringList('l'), ['a', 'b']);
});
test('restore throws StateError when the snapshot is missing', ...);
```

- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS.**
- [ ] **Step 5: Commit** (`feat(demo-mode): snapshot and restore app-wide preferences`)

### Task 4: Manifest client, downloader and package extractor

**Files:**
- Create: `lib/features/demo_mode/data/demo_manifest_client.dart`
- Create: `lib/features/demo_mode/data/demo_downloader.dart`
- Create: `lib/features/demo_mode/data/demo_package_extractor.dart`
- Test: `test/features/demo_mode/data/demo_manifest_client_test.dart`
- Test: `test/features/demo_mode/data/demo_downloader_test.dart`
- Test: `test/features/demo_mode/data/demo_package_extractor_test.dart`

**Interfaces:**
- Consumes: `DemoManifest`, `DemoPackage`, `DemoPaths`.
- Produces:
  - `const kDemoManifestUrl = 'https://github.com/submersion-app/submersion/releases/download/demo-data/demo-manifest.json';`
  - `class DemoManifestClient { DemoManifestClient({http.Client? client, Uri? url, Duration timeout = const Duration(seconds: 8)}); Future<DemoPackage?> fetchBest(int appSchemaVersion); }` (any network error, non-200, timeout or parse failure returns null)
  - `class DemoDownloadException implements Exception { final DemoDownloadFailure reason; }` with `enum DemoDownloadFailure { network, httpStatus, checksumMismatch, sizeMismatch, cancelled }`
  - `class DemoDownloader { DemoDownloader({http.Client? client}); Future<File> download(DemoPackage pkg, File dest, {void Function(int received, int total)? onProgress, bool Function()? isCancelled}); }` (streams to `dest.tmp`, hashes with `sha256.startChunkedConversion`, renames only when size and hash match, deletes the tmp file on every failure)
  - `class DemoPackageExtractor { Future<void> extract(File zip, DemoPaths paths); }` (expects `submersion_demo.db` and `photos/*.jpg|png|webp`; rejects entries with `..`, absolute paths, or any other top-level name with `FormatException`)

- [ ] **Step 1: Write the failing tests**, using `MockClient` from `package:http/testing.dart`:
  - `fetchBest returns null on 404, on timeout, on malformed JSON, and when only newer schemas exist` (Review Focus 4)
  - `fetchBest returns the matching package on 200`
  - `download writes the file and reports progress that ends at total`
  - `download throws checksumMismatch and leaves neither dest nor dest.tmp`
  - `download throws cancelled when isCancelled returns true mid-stream`
  - `extract writes the database and photos into DemoPaths`
  - `extract refuses a zip-slip entry ../evil.txt`
- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS.**
- [ ] **Step 5: Commit** (`feat(demo-mode): fetch, verify and unpack the sample logbook`)

### Task 5: Date columns registry and database preparer

**Files:**
- Create: `lib/features/demo_mode/data/demo_date_columns.dart`
- Create: `lib/features/demo_mode/data/demo_database_preparer.dart`
- Test: `test/features/demo_mode/data/demo_date_columns_test.dart`
- Test: `test/features/demo_mode/data/demo_database_preparer_test.dart`

**Interfaces:**
- Produces:
  - `enum DemoDateUnit { epochMillis, epochSeconds }`
  - `class DemoDateColumn { const DemoDateColumn(this.table, this.column, this.unit); final String table, column; final DemoDateUnit unit; }`
  - `const List<DemoDateColumn> demoDateColumns` (every column holding a point in time; `DateTimeColumn`s are `epochSeconds`, int date columns `epochMillis`)
  - `const Map<String, String> demoNotDateColumns` (`'table.column'` to the reason, for date-like names that are not points in time: `dives.bottom_time` and `dives.runtime` are durations, `hlc` columns are sync clocks, and so on)
  - `Duration demoShiftFor({required DateTime latestDive, required DateTime now})`: whole weeks so `latestDive + shift` falls in `(now - 14 days, now - 7 days]`
  - `class DemoUnitSettings { final Map<String, Object?> values; }` holding the `diver_settings` columns `depth_unit, temperature_unit, pressure_unit, volume_unit, weight_unit, altitude_unit, distance_unit, coordinate_format, time_format, date_format, theme_mode`
  - `class DemoDatabasePreparer { Future<void> prepare(AppDatabase db, {required DateTime now, required String photosDir, required String? deviceId, DemoUnitSettings? units}); }`

`prepare` runs in one transaction: shift every registered column by `demoShiftFor(latest dives.dive_date_time, now)` (skip NULLs), rewrite `media.local_path` and `media.file_path` for `source_type = 'localFile'` to `p.join(photosDir, p.basename(old))`, set `media.origin_device_id` to `deviceId`, and apply `units` to every `diver_settings` row when given.

- [ ] **Step 1: Write the failing tests**

```dart
test('every date-like column is either registered or explained', () {
  final db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
  addTearDown(db.close);
  final pattern = RegExp(r'(_at|_date|_time|date|time)$');
  final unclassified = <String>[];
  for (final t in db.allTables) {
    for (final c in t.$columns) {
      final key = '${t.actualTableName}.${c.name}';
      final dateLike = c.type == DriftSqlType.dateTime || (c.type == DriftSqlType.int && pattern.hasMatch(c.name));
      final known = demoDateColumns.any((d) => '${d.table}.${d.column}' == key) || demoNotDateColumns.containsKey(key);
      if (dateLike && !known) unclassified.add(key);
    }
  }
  expect(unclassified, isEmpty, reason: 'Add each to demoDateColumns or demoNotDateColumns');
});

test('every registered column exists in the schema', ...);

test('demoShiftFor lands the latest dive 7 to 13 days ago and keeps the weekday', () {
  final now = DateTime(2026, 10, 26, 12);
  for (final latest in [DateTime(2024, 1, 3), DateTime(2026, 10, 20), DateTime(2026, 10, 25)]) {
    final shifted = latest.add(demoShiftFor(latestDive: latest, now: now));
    expect(now.difference(shifted).inDays, inInclusiveRange(7, 13));
    expect(shifted.weekday, latest.weekday);
  }
});

test('prepare shifts dives, trips and certifications by the same whole weeks', ...);
test('prepare relinks local photos into photosDir and stamps this device', ...);
test('prepare copies the unit settings onto the demo diver', ...);
```

- [ ] **Step 2: Run, FAIL.**
- [ ] **Step 3: Classify the columns.** Run the first test with an empty registry, then file each reported column under `demoDateColumns` or `demoNotDateColumns` with a reason. Then implement the preparer.
- [ ] **Step 4: Run, PASS.**
- [ ] **Step 5: Commit** (`feat(demo-mode): shift sample dates and relink sample photos`)

### Task 6: Enter, exit and startup

**Files:**
- Create: `lib/features/demo_mode/data/demo_mode_service.dart`
- Create: `lib/features/demo_mode/data/demo_startup.dart`
- Modify: `lib/core/services/database_service.dart` (`initialize`, line 190: add `String? pathOverride`)
- Modify: `lib/core/presentation/pages/startup_page.dart` (between the path resolve at about line 379 and the restore journal at about line 380; security gate at about 397; interrupted restore at about 408; pre-migration backup at about 433-460)
- Modify: `lib/main.dart` (load the gate after the support directory is known, about line 117)
- Modify: `lib/core/services/sync/sync_initializer.dart` (`reconcileDeviceIdentity`, about line 146: return early when the gate is active)
- Test: `test/features/demo_mode/data/demo_mode_service_test.dart`
- Test: `test/features/demo_mode/data/demo_startup_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 5. `DatabaseService.instance` (`reinitializeAtPath`, `close`, `databaseKeyHex`, `database`), `DatabaseSecurityService.instance.databaseKeyHex`, `DatabaseLocationService.getDatabasePath()`, `restartApp()` (`lib/main.dart:196`), `currentDiverIdKey` (`diver_providers.dart:74`).
- Produces:
  - `enum DemoEnterStage { downloading, preparing, opening }`
  - `class DemoEnterProgress { final DemoEnterStage stage; final int received; final int total; }`
  - `class DemoModeService { DemoModeService({required DemoPaths paths, required SharedPreferences prefs, required DemoStateStore store, required DemoManifestClient manifest, required DemoDownloader downloader, required DemoPackageExtractor extractor, required DemoDatabasePreparer preparer, required DatabaseService database, required Future<String> Function() realDatabasePath, required String? Function() realKeyHex, required String? Function() deviceId, required VoidCallback restart, DateTime Function() clock = DateTime.now}); Future<void> enter({required bool fromFirstRun, DemoUnitSettings? units, void Function(DemoEnterProgress)? onProgress, bool Function()? isCancelled}); Future<void> exit(); }`
  - `class DemoStartupDecision { final String? demoDatabasePath; /* null: open the real logbook */ }`
  - `class DemoStartup { static Future<DemoStartupDecision> resolve({required DemoStateStore store, required SharedPreferences prefs}); }`

`enter` order (the commit point is step 5):

1. write `entering`
2. fetch the best package (null throws `DemoDownloadException(network)`) and download it with progress
3. extract it
4. capture the prefs snapshot
5. write `active` and `DemoModeGate.instance.markActive(true)`
6. set `database.databaseKeyHex = null` and `reinitializeAtPath(paths.databaseFile)`
7. `preparer.prepare` with the photos dir, device id and units
8. set `current_diver_id` to the demo database's default diver
9. `restart()`

A failure before step 5 deletes the demo directory and rethrows. A failure after step 5 runs the exit sequence, then rethrows.

`exit` order:

1. write `exiting`
2. set `database.databaseKeyHex = realKeyHex()` and `reinitializeAtPath(await realDatabasePath())`
3. `PrefsSnapshot.restore`
4. `store.deleteAll()`
5. `markActive(false)`
6. `restart()`

`DemoStartup.resolve`:

- No state: open the real logbook.
- `entering`: `deleteAll`, then open the real logbook.
- `active`: open the demo database (the file must exist, otherwise treat the state as `exiting`).
- `exiting`: restore the prefs snapshot if present, `deleteAll`, then open the real logbook.

Startup changes when `demoDatabasePath != null`:

- call `DatabaseService.initialize(pathOverride: demoDatabasePath)`
- set `databaseKeyHex = null`
- skip the security gate's self-heal, the restore journal, the interrupted-restore check and the pre-migration backup
- leave app lock untouched

`main.dart` calls `DemoModeGate.instance.load(DemoStateStore(DemoPaths(supportDir)))` before `runApp`.

- [ ] **Step 1: Write the failing tests** (fakes for client, downloader and extractor; a real temp directory; `DatabaseService.instance` with `setTestDatabase`/`resetForTesting`, restored in tearDown)
  - `enter switches to the demo database, snapshots prefs and restarts once`
  - `enter failing during download leaves no demo directory and the gate inactive`
  - `enter failing after the commit point reopens the real database and restores prefs`
  - `enter never applies the real encryption key to the demo file; exit restores it` (Review Focus 2: `realKeyHex` returns a hex key; assert `databaseKeyHex` is null while active and equal to the key after exit)
  - `exit restores current_diver_id, sync and storage prefs exactly` (Review Focus 3: seed `db_storage_mode=customFolder`, `db_custom_path=/x`)
  - `exit deletes the demo database, package, photos and state`
  - `resolve: entering cleans up and opens the real logbook` (Review Focus 1)
  - `resolve: active opens the demo database`
  - `resolve: exiting finishes the exit and opens the real logbook` (Review Focus 1)
  - `resolve: active with a missing demo file finishes the exit`
  - `startup with demo active never writes db_encryption_enabled` (Review Focus 2; a startup test with `db_encryption_enabled=true` and a plaintext demo file)
- [ ] **Step 2: Run, FAIL. Step 3: Implement and wire startup, main and sync_initializer. Step 4: Run, PASS.**
- [ ] **Step 5: Run the database and startup suites**

Run: `flutter test test/core/database test/core/presentation test/core/services/sync`
Expected: PASS

- [ ] **Step 6: Commit** (`feat(demo-mode): enter and exit demo mode, and resume it at startup`)

## Phase B: The seal

### Task 7: Engine gates

**Files (each gets `DemoModeGate.instance.ensureNotDemo(<feature>)` as its first statement):**
- `sync`: `lib/core/services/sync/sync_service.dart` `performSync` (about :568); `lib/features/settings/presentation/providers/sync_providers.dart` `performSync({bool auto})` (about :1463, returns quietly when `auto` is true, throws otherwise); `lib/core/services/sync/sync_service_replace_join.dart` `applyReplaceJoin` (about :200); `lib/core/services/sync/replace_and_join_service.dart` `run` (about :64)
- `sharedLibrary`: `lib/core/services/shared_library/shared_library_service.dart` `sync` (:108); `shared_site_publisher.dart` `push`, `deleteFromLibrary`, `undelete`; `suggestion_service.dart` `propose`, `accept`, `dismiss`; `shared_library_sync_notifier.dart` `syncAll` (quiet when `auto`), `syncOne`; `library_backup_service.dart` `backUp`, `backUpIfDue`; `library_restore_service.dart` `restore`, `restoreInto`
- `backup`: `lib/features/backup/data/services/backup_service.dart` `performBackup` (:189), `exportBackupToPath` (:343), `exportBackupToTemp` (:413); `backup_providers.dart` `_checkDesktopBackup` (:626, quiet)
- `restore`: `backup_service.dart` `restoreFromBackup` (:798), `restoreFromFile` (:927), `restoreFromDatabaseCopy` (:1010); `lib/core/services/database_service.dart` `restore` (:1025)
- `fileImport` / `cloudImport` / `diveComputerDownload`: `import_wizard_providers.dart` `performImport` (:1102); `universal_import_providers.dart` `importFromGarminDevice` (:610); `ocr_import/.../scan_flow_controller.dart` `process` (:30); `dive_import/.../dive_resync_orchestrator.dart` `resync` (:63); `dive_computer/.../download_providers.dart` `startDownload` (:323)
- `mediaImport`: `media_import_service.dart` `importLocalFileForDive` (:133), `importPhotosForDive` (:182), `importPhotosForSite` (:280); `local_file_link_service.dart` `linkFileForDive` (:107); `media_object_store.dart` `putFile` (:106), `getFile` (:117)
- `export` / `share`: every public function in `lib/core/services/export/shared/file_export_utils.dart` that saves or shares (`saveAndShareFile`, `saveAndShareFileBytes`, `shareFileAtPath`, `exportImageAsPng`, `sharePdfBytes`, `saveImageToPhotos`, `saveImageToFile`, `saveTextToFile`, `saveBytesToFile`, `savePdfToFile`)
- `databaseFile`: `database_migration_service.dart` `migrateToCustomFolder`, `migrateToDefault`, `switchToExistingDatabase`, `replaceExistingDatabase`; `database_service.dart` `resetDatabase` (:1326); `database_security_service.dart` `enableSecurity`, `disableSecurity`, `enableEncryption`, `disableEncryption`
- Backstop: wrap `cloudProviderInstanceFor` (`cloud_provider_instances.dart:41`) results in a `DemoSealedCloudStorageProvider` decorator (new file `lib/features/demo_mode/data/demo_sealed_cloud_storage_provider.dart`) whose every method calls `ensureNotDemo(DemoSealedFeature.sync)` before delegating
- Create: `test/architecture/demo_seal_engine_gates_test.dart`
- Test: `test/features/demo_mode/data/demo_seal_behaviour_test.dart`

**Interfaces:**
- Consumes: `DemoModeGate`, `DemoSealedFeature`, `DemoModeSealedException`.
- Produces: `const List<(String file, String method, DemoSealedFeature feature)> demoSealedEngineMethods` in the architecture test.

- [ ] **Step 1: Write the failing architecture test.** For each entry, read the file, find the method's declaration and body, and assert that `ensureNotDemo(DemoSealedFeature.<feature>)` appears before the first other statement. Locate methods by declaration name, not line number.
- [ ] **Step 2: Write the failing behaviour tests**
  - `a sync timer already scheduled fires during demo mode and uploads nothing` (Review Focus 5: schedule auto sync, mark the gate active, elapse the debounce in `fakeAsync`, verify the provider's `uploadFile` was never called)
  - `performBackup throws DemoModeSealedException in demo mode`
  - `DatabaseService.restore throws and leaves the open database untouched`
  - `the sealed cloud provider refuses every call`
- [ ] **Step 3: Run both, FAIL. Step 4: Insert the gates and the decorator. Step 5: Run both plus `flutter test test/core/services/sync test/features/backup`, PASS.**
- [ ] **Step 6: Commit** (`feat(demo-mode): seal sync, backup, restore, import and export at the engine`)

### Task 8: Background isolate

**Files:**
- Modify: `lib/core/services/background_service.dart` (`callbackDispatcher`, about :142; right after `SharedPreferences.getInstance()` at about :148)
- Test: `test/core/services/background_service_demo_test.dart`

**Interfaces:**
- Consumes: `DemoPaths.resolve()`, `DemoStateStore`, `DemoModeGate.load`.

- [ ] **Step 1: Write the failing test** `every background task returns success without work while demo mode is active` (Review Focus 5): drive the extracted task-handler function with a demo state file present, and assert neither the backup nor the notification refresh touched the database.
- [ ] **Step 2: Run, FAIL. Step 3: Load the gate at the top of the dispatcher and return `true` for every task when active. Step 4: Run, PASS.**
- [ ] **Step 5: Commit** (`feat(demo-mode): background tasks do nothing in demo mode`)

### Task 9: Sealed routes

**Files:**
- Create: `lib/features/demo_mode/presentation/demo_sealed_routes.dart`
- Create: `lib/features/demo_mode/presentation/pages/demo_unavailable_page.dart`
- Modify: `lib/core/router/app_router.dart` (redirect at about :255-282; add route `/demo-unavailable`)
- Test: `test/features/demo_mode/presentation/demo_sealed_routes_test.dart`

**Interfaces:**
- Produces:
  - `const Map<String, DemoSealedFeature> demoSealedRoutePrefixes` covering:
    - `/transfer` (fileImport)
    - `/dive-computers/discover` and `/dive-computers/` paths ending `/download` (diveComputerDownload)
    - `/dives/scan`, `/sites/import`, `/dive-centers/import` (fileImport)
    - `/settings/backup` (backup)
    - `/settings/cloud-sync`, `/settings/connected-accounts` (sync)
    - `/settings/shared-libraries` (sharedLibrary)
    - `/settings/storage`, `/settings/setup-assistant`, `/settings/setup` (databaseFile)
    - `/settings/wearable-import` (cloudImport)
    - `/settings/media-storage`, `/settings/lightroom` (mediaImport)
  - `DemoSealedFeature? demoSealedFeatureFor(String location)`
  - `class DemoUnavailablePage extends StatelessWidget { const DemoUnavailablePage({required this.feature}); }` (feature name, one sentence on why, and an "Exit demo" button)

- [ ] **Step 1: Write the failing tests**
  - `every sealed prefix maps to a route that exists in appRouter` (walk the router's routes)
  - `redirect sends a sealed location to /demo-unavailable?feature=<name> only while demo mode is active`
  - `an unsealed location such as /dives is never redirected`
- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS. Step 5: Commit** (`feat(demo-mode): sealed screens explain they are unavailable in demo mode`)

### Task 10: Inline guard for buttons, pickers and shares

**Files:**
- Create: `lib/features/demo_mode/presentation/demo_seal_guard.dart`
- Modify: each file holding a sealed inline action. The seal report lists them:
  - dive detail exports (`dive_detail_page.dart` :2765, :2911, :3057, :5579)
  - `connections_share_action.dart:27`, `plan_export_actions.dart`, `blender_invoice_card.dart:550`, `media_health_providers.dart:51`
  - the direct `SharePlus` callers (`debug_log_providers.dart:201` is exempt: debug logs are not user data), `library_backups_page.dart`, `certification_share_sheet.dart`, `document_page_opener.dart`, `document_open_helper.dart`, `document_viewer_page.dart`, `backup_actions.dart`, `media_share_helper.dart`
  - file and image pickers (`tracks_import.dart`, `route_link_sheet.dart`, `saved_plans_sheet.dart`, `document_page_capture.dart`, `files_tab.dart`, `dive_media_section.dart`, `media_link_replacer.dart`, `media_repair_wizard_page.dart`, `media_sources_section_view.dart`, `certification_edit_page.dart`, `buddy_list_content.dart`, `profile_photo_codec.dart`, `photo_picker_page.dart`, `photo_import_helper.dart`, `site_media_import_helper.dart`, `media_drop_import.dart`, `trip_media_scanner.dart`)
  - shared-library actions on `site_detail_page.dart`, `site_list_content.dart:1441`, `site_edit_page.dart:2089`, `suggestion_review_sheet.dart`
  - the home sync chip (`gauge_strip.dart:486`), the security page's encryption switch (`security_settings_page.dart:109`), and incoming shares (`lib/app.dart` `_openShare` at about :435, which shows the note and returns false)
- Create: `test/architecture/demo_seal_ui_coverage_test.dart`
- Test: `test/features/demo_mode/presentation/demo_seal_guard_test.dart`

**Interfaces:**
- Produces: `bool demoSealGuard(BuildContext context, DemoSealedFeature feature)`. It returns true when the action may proceed. When demo mode is active it shows a SnackBar with the localized "Not available in demo mode" note and returns false.

- [ ] **Step 1: Write the failing architecture test.** Scan `lib/` (excluding `lib/features/demo_mode/` and generated files) for `FilePicker.platform`, `ImagePicker(`, `SharePlus.instance`, `pickFiles(`, `getDirectoryPath(`, `saveFile(`, `DropTarget(`. Every hit's file must contain `demoSealGuard(` or `ensureNotDemo(`, or be listed in `const demoSealUiExemptions = <String, String>{path: reason}` in the test. Seed the exemptions only with debug-log and crash-report sharing.
- [ ] **Step 2: Write the failing widget test** `guard shows the note and blocks while active, and passes through while inactive`.
- [ ] **Step 3: Run, FAIL. Step 4: Implement the guard and apply it at every reported site. Step 5: Run, PASS, plus `flutter test test/architecture test/shared`.**
- [ ] **Step 6: Commit** (`feat(demo-mode): explain sealed buttons, pickers and shares`)

## Phase C: Entering and leaving in the UI

### Task 11: Strings

**Files:**
- Modify: `lib/l10n/arb/app_*.arb` (all 11)
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

New keys:

- `demo_welcome_title` ("Explore with sample data")
- `demo_welcome_subtitle` ("Look around a complete sample logbook before entering your own")
- `demo_settings_enter_title` ("Explore with sample data")
- `demo_settings_enter_subtitle` ("Your logbook is set aside, untouched, until you exit")
- `demo_settings_exit_title` ("Exit demo")
- `demo_settings_exit_subtitle` ("Discard the sample logbook and return to your own")
- `demo_strip_label` ("Demo mode: you are exploring sample data")
- `demo_strip_exit` ("Exit demo")
- `demo_exit_confirm_title` ("Exit demo mode?")
- `demo_exit_confirm_body` ("Changes you made to the sample logbook will be discarded.")
- `demo_exit_confirm_action` ("Exit demo")
- `demo_enter_downloading` ("Downloading sample logbook")
- `demo_enter_preparing` ("Preparing sample logbook")
- `demo_enter_failed` ("The sample logbook could not be downloaded. Check your connection and try again.")
- `demo_sealed_note` ("Not available in demo mode")
- `demo_unavailable_title` ("Unavailable in demo mode")
- `demo_unavailable_body` ("Demo mode keeps the sample logbook separate from your data, so nothing can be imported, exported, backed up or synced.")
- `demo_row_unavailable` ("Unavailable in demo mode")

All final copy is the builder's call within this meaning.

- [ ] **Step 1: Add the keys with real translations in every locale; run `flutter gen-l10n`.**
- [ ] **Step 2: Run `flutter test test/l10n`. Expected: PASS** (no kept-English entries needed).
- [ ] **Step 3: Commit** (`feat(demo-mode): strings in every language`)

### Task 12: Providers

**Files:**
- Create: `lib/features/demo_mode/presentation/providers/demo_mode_providers.dart`
- Test: `test/features/demo_mode/presentation/demo_mode_providers_test.dart`

**Interfaces:**
- Produces:
  - `final demoModeActiveProvider = Provider<bool>((ref) => DemoModeGate.instance.isActive);` (re-read after every `restartApp()`)
  - `final demoManifestClientProvider = Provider<DemoManifestClient>(...)`
  - `final demoAvailabilityProvider = FutureProvider<DemoPackage?>(...)` (calls `fetchBest(AppDatabase.currentSchemaVersion)` once per app session, null on any failure)
  - `final demoModeServiceProvider = Provider<DemoModeService>(...)`
  - `final demoEnterControllerProvider = NotifierProvider<DemoEnterController, DemoEnterUiState>(...)`, where `DemoEnterUiState` is `{idle | running(DemoEnterProgress) | failed(DemoDownloadFailure)}` and the controller exposes `Future<void> start({required bool fromFirstRun})` and `void cancel()`. `start` builds the `DemoUnitSettings` it passes to `enter`: from the active diver's `diver_settings` row when not first run, and from `presetForLocale(Localizations locale)` (`unit_preset_detector.dart:9`) on first run
- [ ] **Step 1: Failing tests**
  - `availability is null when the client returns null` (Review Focus 4)
  - `availability is cached for the session`
  - `controller moves idle, then running, then failed on a download failure, and back to idle on retry`
  - `start passes the active diver's units, or the locale preset on first run`
- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS. Step 5: Commit** (`feat(demo-mode): providers for availability and entering`)

### Task 13: Welcome card and the entering dialog

**Files:**
- Modify: `lib/features/setup_wizard/presentation/widgets/steps/welcome_fork_step.dart` (add `VoidCallback? onTryDemo`; a third `_ForkCard` after line 70 with `Icons.explore_outlined`, shown only when non-null)
- Modify: `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart` (`_defFor` welcomeFork case, about :171-184: pass `onTryDemo` only when `demoAvailabilityProvider` has a package and the mode is `firstRun`; it opens the entering dialog with `fromFirstRun: true` and does not go through `_chooseAndAdvance`)
- Create: `lib/features/demo_mode/presentation/widgets/demo_enter_dialog.dart` (`Future<void> showDemoEnterDialog(BuildContext context, {required bool fromFirstRun})`: progress with stage label and percent, a Cancel button, and the failure message with Retry)
- Test: `test/features/setup_wizard/presentation/widgets/welcome_fork_demo_test.dart`
- Test: `test/features/demo_mode/presentation/demo_enter_dialog_test.dart`

- [ ] **Step 1: Failing tests**
  - `third card shows only when a sample logbook is available`
  - `tapping it opens the entering dialog with fromFirstRun true`
  - `dialog shows progress, then the failure message and Retry on failure`
  - `Cancel stops the download and closes the dialog with nothing changed`
- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS, plus `flutter test test/features/setup_wizard`. Step 5: Commit** (`feat(demo-mode): explore with sample data from the welcome screen`)

### Task 14: Settings > Data entry, exit, and sealed rows

**Files:**
- Modify: `lib/features/settings/presentation/widgets/data_row_tile.dart` (add `VoidCallback? onTap` used instead of `pushSettingsPage` when set, and `bool enabled = true` rendered as `ListTile(enabled: false)` with the subtitle replaced by `demo_row_unavailable`; keep `route` required for existing callers by making it `String?` with an assert that one of `route`/`onTap` is set)
- Modify: `lib/features/settings/presentation/pages/data_section_content.dart`. In demo mode the Backups, Sync between devices, Photos & videos, Shared site libraries, Connected accounts and Database storage rows get `enabled: false`. Add an "Explore with sample data" row at the end of "Your data" (when available and not active), or an "Exit demo" row (when active).
- Create: `lib/features/demo_mode/presentation/widgets/demo_exit_confirm.dart` (`Future<void> confirmAndExitDemo(BuildContext context, WidgetRef ref)`)
- Test: extend `test/features/settings/presentation/pages/data_section_content_test.dart`

- [ ] **Step 1: Failing tests**
  - `shows Explore with sample data when available and not in demo mode`
  - `hides it when no sample logbook is available`
  - `in demo mode shows Exit demo, and the six sealed rows are disabled with the note`
  - `Exit demo asks for confirmation and exits only on confirm`
- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS. Step 5: Commit** (`feat(demo-mode): enter and exit demo mode from Settings > Data`)

### Task 15: Demo strip

**Files:**
- Create: `lib/features/demo_mode/presentation/widgets/demo_mode_strip.dart` (`ConsumerWidget` modelled on `GpsRecordingStrip`: `SizedBox.shrink()` when inactive; otherwise a `Material` in `tertiaryContainer` with the label and an "Exit demo" `TextButton` calling `confirmAndExitDemo`)
- Modify: `lib/shared/widgets/main_scaffold.dart` (insert `const DemoModeStrip()` above `UpdateBanner` at about :387 and :405, and at the top of the chromeless scaffold at about :67)
- Test: `test/features/demo_mode/presentation/demo_mode_strip_test.dart`

- [ ] **Step 1: Failing tests**
  - `strip is absent when inactive`
  - `strip shows label and Exit demo when active, on phone and desktop layouts`
  - `strip text does not overflow at 320 px wide and text scale 2.0`
- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS, plus `flutter test test/shared`. Step 5: Commit** (`feat(demo-mode): a strip on every screen while exploring sample data`)

## Phase D: The generator

All generator code lives in `tool/demo_data/src/`. The runners are `flutter test` files under `tool/demo_data/`, driven by shell scripts under `scripts/demo_data/`, following `tool/color_encode_it/`. Inputs come from `--dart-define`. CI tests under `test/tool/demo_data/` import the `src/` code by relative path.

### Task 16: Dive shapes and extraction

**Files:**
- Create: `tool/demo_data/src/shape/dive_shape.dart`
- Create: `tool/demo_data/src/shape/shape_extractor.dart`
- Test: `test/tool/demo_data/shape_extractor_test.dart`

**Interfaces:**
- Produces:
  - `enum ShapeKind { recreational, deepOpenCircuit, multiGasDeco, trimix, ccr, scooter, multiComputer, freshwater, night }` (a shape can carry several)
  - `class ShapeSample { final double t; /* seconds from start */ final double depth; final double? temp; final Map<int, double> tankPressureBar; final double? ppO2; final List<double>? cellPpO2; final double? setpoint; }`
  - `class ShapeGas { final double o2; final double he; final int tankIndex; final double? startTimeSec; }`
  - `class DiveShape { final String id; /* sha256 of the quantised depth curve, not of any source field */ final Set<ShapeKind> kinds; final String diveMode; /* oc|ccr|scr */ final double sampleIntervalSec; final List<ShapeSample> samples; final List<ShapeGas> gases; final List<({double t, String type})> events; final int computerCount; Map<String, Object?> toJson(); factory DiveShape.fromJson(Map<String, Object?>); }`
  - `class ShapeExtractor { List<DiveShape> fromPayload(ImportPayload payload); Future<List<DiveShape>> fromSubmersionDatabase(String copiedDbPath); }`

The shape model has no field that can carry a date, place, name, serial or note. That is the anonymisation boundary, and the test asserts it.

- [ ] **Step 1: Failing tests**
  - `fromPayload keeps depth, temperature, per-tank pressure, gases and events of a UDDF fixture` (use `test/fixtures/` UDDF already in the repo)
  - `a CCR Subsurface fixture yields cell readings and setpoints`
  - `the JSON of every extracted shape contains none of the fixture's dates, site names, buddy names, notes or serials` (collect those strings from the payload first, then search the JSON)
  - `kinds classify a 45 m dive with a 50% switch as deepOpenCircuit and multiGasDeco`
- [ ] **Step 2: Run, FAIL. Step 3: Implement.** Read profile samples from each format's dive entity map; check `UddfImportParser` and `SubsurfaceXmlParser` for the sample key. For Submersion databases, open a copy through `AppDatabase` (migrations run) and read via `DiveRepository.getDivesByIds`, which hydrates profiles.
- [ ] **Step 4: Run, PASS. Step 5: Commit** (`feat(demo-data): anonymous dive shapes from imported logs`)

### Task 17: Harvest runner

**Files:**
- Create: `tool/demo_data/src/harvest/harvester.dart`
- Create: `tool/demo_data/harvest_test.dart` (the runner)
- Create: `scripts/demo_data/harvest.sh`
- Test: `test/tool/demo_data/harvester_test.dart`

**Interfaces:**
- Consumes: `FormatDetector().detect` (`lib/features/universal_import/data/services/format_detector.dart:30`), `parserForFormat` (`parser_registry.dart`), `ShapeExtractor`.
- Produces:
  - `class HarvestResult { final List<DiveShape> shapes; final Set<String> sourceStringHashes; final Map<String, int> perSourceCounts; final List<String> skipped; }`
  - `class Harvester { Harvester({required String salt}); Future<HarvestResult> harvest(List<String> paths); }` (walks directories; unzips archives into a temp directory; refuses the excluded generated files by name; dedupes shapes by `id`; collects salted SHA-256 hashes of every source text value of 3 or more characters for the privacy check)
  - CLI: `scripts/demo_data/harvest.sh <out_dir> <source_path>...` writes `<out_dir>/shapes.jsonl.gz`, `<out_dir>/source_strings.txt` (hashes only) and `<out_dir>/salt.txt`. It prints per-source counts and kind counts, and refuses an `out_dir` inside the repository.
- [ ] **Step 1: Failing tests**
  - `excluded generated files are skipped and reported`
  - `the same dive in UDDF and Subsurface yields one shape`
  - `source strings are stored only as salted hashes`
  - `an out_dir inside the repository is refused`
- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS. Step 5: Commit** (`feat(demo-data): harvest dive shapes from local real logs`)

### Task 18: Reshaper

**Files:**
- Create: `tool/demo_data/src/shape/reshaper.dart`
- Test: `test/tool/demo_data/reshaper_test.dart`

**Interfaces:**
- Produces: `class Reshaper { Reshaper(Random random); DiveShape reshape(DiveShape source, {required double targetMaxDepth, required int tankCount, required List<double> startPressuresBar, required List<double> tankVolumesL}); }`

Rules:

- Time stretch is drawn from [0.85, 0.97] or [1.03, 1.15].
- Depth scale is chosen so `targetMaxDepth` is within [0.85, 0.97] or [1.03, 1.15] of the source's maximum.
- The ascent rate never exceeds 18 m/min between samples, and stops are preserved.
- Pressure is re-fitted per tank, using the source's gas-use shape scaled to the new start pressure and volume. Pressure is monotone non-increasing per tank, except for the documented post-dive surfacing correction.
- Samples get small jitter (depth within 0.1 m, temperature within 0.2 C).
- Builder's call within these limits.
- [ ] **Step 1: Failing tests**
  - `reshaped profile never matches the source scale exactly`
  - `ascent rate stays within 18 m/min`
  - `tank pressure is monotone and ends above 30 bar`
  - `the same seed gives the same output`
- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS. Step 5: Commit** (`feat(demo-data): reshape dives so none matches its source`)

### Task 19: Privacy check

**Files:**
- Create: `tool/demo_data/src/checks/privacy_check.dart`
- Test: `test/tool/demo_data/privacy_check_test.dart`

**Interfaces:**
- Produces: `class PrivacyViolation { final String kind; /* profile | text */ final String where; }` and `class PrivacyCheck { static const similarityThreshold = 0.04; static double distance(DiveShape a, DiveShape b); /* both resampled to 200 points over normalised time; depth RMSE divided by the larger max depth, plus 0.5 x relative runtime difference, plus 0.5 x relative max-depth difference */ Future<List<PrivacyViolation>> run({required String demoDbPath, required List<DiveShape> sources, required Set<String> sourceStringHashes, required String salt}); }`
- [ ] **Step 1: Failing tests**
  - `an unreshaped copy is rejected` (distance 0)
  - `a reshaped dive passes`
  - `a text cell equal to a source string is rejected` (hash it with the salt)
- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS. Step 5: Commit** (`feat(demo-data): refuse a demo logbook that resembles a real dive`)

### Task 20: Story planner

**Files:**
- Create: `tool/demo_data/src/story/story_plan.dart`
- Create: `tool/demo_data/src/story/story_planner.dart`
- Test: `test/tool/demo_data/story_planner_test.dart`

**Interfaces:**
- Consumes: `assets/data/dive_sites.json`, `assets/data/dive_centers.json`.
- Produces:
  - `enum StoryPhase { recreational, technicalOc, rebreather }`
  - `class PlannedDive { final int number; final DateTime start; final StoryPhase phase; final Set<ShapeKind> wantedKinds; final String siteId; final String? tripId; final int tankCount; final String diveMode; final List<String> buddyIds; }`
  - `class StoryPlan { final List<PlannedDive> dives; final List<PlannedTrip> trips; final List<PlannedCert> certs; final List<PlannedCourse> courses; final List<CatalogSite> sites; final List<CatalogCenter> centers; final List<FictionalPerson> people; }`
  - `class StoryPlanner { StoryPlanner(Random random); StoryPlan plan({required DateTime anchor, int diveCount = 300}); }`
- [ ] **Step 1: Failing tests**
  - `dives span six years before the anchor, in order, with no overlaps`
  - `phases run recreational, then technical OC, then rebreather, with 8 to 12 CCR dives at the end`
  - `each certification precedes the first dive that needs it`
  - `every site and centre comes from the bundled catalogues`
  - `no fictional person shares a name with a buddy in any repository fixture`
- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS. Step 5: Commit** (`feat(demo-data): a six-year story for the demo diver`)

### Tasks 21 to 25: Seeders

Each seeder is `abstract class DemoSeeder { String get name; Future<void> seed(DemoSeedContext ctx); }`, where `class DemoSeedContext { final AppDatabase db; final StoryPlan plan; final List<DiveShape> shapes; final Reshaper reshaper; final Random random; final Map<String, String> ids; /* plan ids to database ids */ final String photosDir; }`. Seeders write through the app's repositories wherever one exists (so derived columns, HLCs and side tables are filled exactly as the app fills them), and through Drift companions otherwise. Each task has the same cycle: a failing test that runs its seeders on an in-memory database with the synthetic fixture shapes (`test/fixtures/demo_data/synthetic_shapes.jsonl`, generated by `test/tool/demo_data/synthetic_shapes.dart` from easing curves; synthetic data is allowed in CI), then assertions on row counts and relationships; implement; pass; commit as `feat(demo-data): seed <area>`.

- **Task 21: People and places.** Files `tool/demo_data/src/seeders/{diver,buddies,sites,centers,trips,taxonomy}_seeder.dart`. Covers the diver with settings, emergency contacts, medical and prior experience, body weight entries; buddies and dive roles; sites with GPS, site types and depths; dive centres; trips with trip gas and checklists; tags, dive types and custom fields. Tests: `the diver is default and has a settings row`, `every planned trip has its dives`, `every site has coordinates from the catalogue`.
- **Task 22: Training.** Files `tool/demo_data/src/seeders/training_seeder.dart`. Covers certifications with agencies and card images, courses with requirements and training dives, and certification currency events. Tests: `every certification has an agency and an issue date before its first use`, `the rebreather course links its training dives`.
- **Task 23: Gear.** Files `tool/demo_data/src/seeders/gear_seeder.dart`. Covers equipment of every type, equipment sets, service records with due dates (some overdue, some due soon), gear passports, cylinder passports with fills and hydro dates, transmitters paired to dive computers, dive computers and their connections, tank presets, weight presets and dive weights. Tests: `some equipment is due for service within 30 days of the anchor`, `each transmitter is paired to a computer`.
- **Task 24: Dives.** Files `tool/demo_data/src/seeders/dive_seeder.dart` and `tool/demo_data/src/seeders/dive_media_seeder.dart`. Each planned dive takes a fitting shape (never reused more than 3 times, never twice on one trip) through the reshaper. It writes the dive row, tanks and gases, profile series, tank pressure series, events, data sources (two computers on the multi-computer dives), CCR setpoints and cell data, scooter dives with a nav route, marine life sightings, weather and tide on the dive, conditions, ratings, notes in the story's voice, and media rows linking `photosDir` files with credits in the caption. Tests: `every dive has a profile and at least one tank with pressure`, `CCR dives carry cell data`, `no shape is used more than 3 times`.
- **Task 25: Planning and logistics.** Files `tool/demo_data/src/seeders/planning_seeder.dart`. Covers dive plans with segments and tanks, missions with legs and members, pre-dive checklist templates and sessions, documents (small generated PDFs and images stored the way the documents feature stores them), GPS logs and tracks, and saved queries if the schema has them. Tests: `a plan exists for an upcoming trip`, `a completed pre-dive session links to a dive`.

### Task 26: Derived data and the coverage check

**Files:**
- Create: `tool/demo_data/src/seeders/derived_seeder.dart` (runs the app's own services for safety reviews, derived metrics, data quality findings and insights caches, the same way the app runs them after an import)
- Create: `tool/demo_data/src/checks/coverage_check.dart`
- Create: `test/tool/demo_data/coverage_test.dart`

**Interfaces:**
- Produces: `const Map<String, String> demoCoverageExclusions` (table name to the reason it stays empty: sync bookkeeping tables `sync_metadata`, `sync_records`, `deletion_log`, `sync_peer_cursors`, `local_publish_states`; history and journal tables; built-in seed tables; shared-library tables, which demo mode never uses) and `class CoverageCheck { static Future<List<String>> emptyTables(AppDatabase db); }` (tables in `db.allTables` with zero rows that are not excluded).
- [ ] **Step 1: Failing test** `the synthetic build fills every table that is not excluded`: run all seeders on an in-memory database with the synthetic shapes and expect `emptyTables` to be empty.
- [ ] **Step 2: Run, FAIL** (lists the gaps). **Step 3: Fill every gap**, by extending a seeder or adding an exclusion with a reason the spec allows. **Step 4: Run, PASS. Step 5: Commit** (`feat(demo-data): every data table is filled, checked in CI`)

### Task 27: Build runner and packager

**Files:**
- Create: `tool/demo_data/src/build/demo_builder.dart`
- Create: `tool/demo_data/build_test.dart` (the runner)
- Create: `scripts/demo_data/build.sh`
- Create: `tool/demo_data/README.md` (how to harvest, curate photos, build and publish; documents the privacy measure and threshold)
- Create: `tool/demo_data/photos/credits.json` (each photo's file name, source URL, author and licence; the image files themselves are fetched by the build script from the URLs into a temp dir, not committed)
- Test: `test/tool/demo_data/demo_builder_test.dart`

**Interfaces:**
- Produces: `class DemoBuilder { Future<DemoBuildOutput> build({required List<DiveShape> shapes, required String photosDir, required int seed, required String outDir, Set<String>? sourceStringHashes, String? salt}); }` and `class DemoBuildOutput { final File zip; final DemoPackage package; }`.

Steps:

1. Write the database to a temp file at the current schema.
2. Run the coverage check, then the privacy check (when hashes are given); refuse on any failure.
3. `VACUUM`.
4. Zip `submersion_demo.db` and `photos/`.
5. Refuse a database over 5 MB compressed or a zip over 15 MB.
6. Write `manifest-entry.json`.

`scripts/demo_data/build.sh <shapes_dir> <out_dir> [seed]` also fetches the credited photos and resizes them to a 1600 px long edge.

- [ ] **Step 1: Failing tests**
  - `a synthetic build produces a zip whose manifest entry matches its sha256 and size`
  - `the build is refused when a coverage gap is introduced`
  - `the same seed gives byte-identical databases` (fix every random and clock input)
- [ ] **Step 2: Run, FAIL. Step 3: Implement. Step 4: Run, PASS. Step 5: Commit** (`feat(demo-data): build and package the sample logbook`)

## Phase E: Retire the Python generator

### Task 28: Round-trip test on committed fixtures

**Files:**
- Create: `test/fixtures/uddf/round_trip_quick.uddf` (generated once, before deletion, with `python3 scripts/generate_uddf_test_data.py --quick -o <path>`; synthetic, so committing it is allowed)
- Modify: `test/integration/uddf_round_trip_test.dart` (lines about 127, 285, 363: copy the fixture into the test's temp dir instead of calling `PythonScriptRunner.generateUddfTestData`)
- Delete: `test/helpers/python_script_runner.dart`
- Modify: `test/integration/uddf_test_importer.dart` (drop its generator reference)

- [ ] **Step 1: Generate the fixture. Step 2: Switch the test. Step 3: Run `flutter test test/integration/uddf_round_trip_test.dart`, PASS. Step 4: Commit** (`test(uddf): round-trip test uses a committed fixture`)

### Task 29: Screenshots from the demo database

**Files:**
- Create: `scripts/demo_data/fetch_demo_db.py` (stdlib only; reads the manifest, picks the newest package whose schema is not above `currentSchemaVersion` parsed from `lib/core/database/database.dart`, verifies the sha256, and extracts into a given directory)
- Create: `scripts/demo_data/fetch_demo_db_test.py`
- Modify: `integration_test/screenshots_test.dart` (replace `UDDF_TEST_DATA_PATH` with `DEMO_PACKAGE_DIR`: copy the database to a temp file, open it with `NativeDatabase` and `setTestDatabase`, run `DemoDatabasePreparer.prepare` with `now: DateTime.now()`, and keep `ScreenshotTestDataSeeder` as the fallback when the define is empty)
- Delete: `integration_test/helpers/uddf_screenshot_helper.dart`
- Modify: `.github/workflows/screenshots.yml` (lines about 88 and 223: fetch instead of generate; pass `DEMO_PACKAGE_DIR`), `scripts/release/capture_screenshots.sh` (lines about 23, 64-65, 150-156, 188-205), `macos/fastlane/Fastfile` lane `:screenshots` (about 388-430)
- Delete: `scripts/generate_uddf_test_data.py`, `scripts/test_uddf_generator.py`
- Modify: any remaining reference (`grep -rn generate_uddf_test_data` outside `docs/design/` and `CHANGELOG.md` must be empty)

- [ ] **Step 1: Failing Python test** `picks the newest compatible package and rejects a bad checksum` (`python3.14 -m pytest scripts/demo_data/fetch_demo_db_test.py`).
- [ ] **Step 2: Implement the fetch script. Step 3: Switch the integration test and the three pipelines. Step 4: Delete the generator and its test.**
- [ ] **Step 5: Verify** `flutter analyze` is clean, `grep` finds no stale reference, and `bash -n` passes on the modified shell scripts.
- [ ] **Step 6: Commit** (`build(screenshots): capture store screenshots from the demo logbook`)

## Phase F: The real logbook

### Task 30: Build from real data, then walk every screen

- [ ] **Step 1: Harvest.** Run `scripts/demo_data/harvest.sh <scratch>/shapes` with the maintainer's test-data folder, the GitHub dive-data attachments in the scratchpad download directory, and a copy of the maintainer's database. Check the per-source and per-kind counts, including at least 4 CCR shapes.
- [ ] **Step 2: Curate photos.** Pick about 30 CC0 or public-domain underwater photos that fit the story's destinations and sightings, and fill `credits.json`. Ask the maintainer before downloading them.
- [ ] **Step 3: Build.** Run `scripts/demo_data/build.sh <scratch>/shapes <scratch>/out` and confirm that both checks pass and both size limits hold.
- [ ] **Step 4: Walk every screen.** Use a throwaway screenshot test that opens the built database through `DemoDatabasePreparer`. Capture the dashboard, dive list, a recreational dive, a deco dive, a CCR dive, a multi-computer dive, sites map, trips, buddies, certifications, courses, equipment and service, passports, planner, checklists, documents, statistics and insights, tracks, marine life and data quality. Fix any empty state at its seeder and rebuild. Show the maintainer a contact sheet of the screens.
- [ ] **Step 5: Commit** any seeder fixes (`fix(demo-data): <what was empty>`).

### Task 31: Publish (only after the maintainer's explicit go-ahead)

- [ ] **Step 1: Ask the maintainer to approve publishing**, showing the size, the counts, both check results and the contact sheet.
- [ ] **Step 2: On approval only**, create or update the release:

```bash
gh release create demo-data --title "Demo mode sample logbook" --notes "Sample logbook for demo mode. Not an app release." --latest=false
gh release upload demo-data <out>/submersion-demo-s318.zip <out>/demo-manifest.json --clobber
```

- [ ] **Step 3: Verify.** `curl -sL <kDemoManifestUrl>` parses; `gh release view --json isLatest` is false for `demo-data`; the app's latest-release check still returns the newest app release.

## Phase G: Finish

### Task 32: End-to-end check and after screenshots

- [ ] **Step 1:** An integration-style test, `test/features/demo_mode/demo_mode_end_to_end_test.dart`. It points a `MockClient` at the real published manifest and package bytes saved under the test's temp dir, enters, asserts the dashboard shows the demo diver, exits, and asserts the original database, `current_diver_id` and `sync_auto_enabled` are back.
- [ ] **Step 2: After screenshots.** Restore the throwaway shot test from the scratchpad copy, add the demo strip and the demo unavailable page, and capture `01-welcome-after*`, `02-settings-data-after*` (normal and in demo mode), `03-demo-strip-after*` and `04-demo-unavailable-after*`, in light and dark at phone and desktop widths. Delete the throwaway test.
- [ ] **Step 3:** `dart format .`, `flutter analyze`, `flutter test test/features/demo_mode test/tool test/architecture test/shared test/l10n test/features/settings test/features/setup_wizard`. Expected: all PASS.
