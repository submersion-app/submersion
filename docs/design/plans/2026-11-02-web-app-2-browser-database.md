# Web App Plan 2: Browser Database and Workers

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The web build opens the real `AppDatabase` on Drift's `WasmDatabase` in a worker with the app's SQL functions registered, persists it in the browser's origin private file system, runs the heavy sync work in a second compiled worker, and boots to the setup wizard in Chrome.

**Architecture:** Drift's OPFS storage runs SQLite inside a web worker compiled separately from the Flutter app with `dart compile js`. That worker must register the five SQL functions every connection needs, so the functions' import chain first becomes Flutter-free by two mechanical moves (the enum bodies out of `enums.dart`, `DiveTank` and `GasMix` out of `dive.dart`). A second compiled worker, the compute worker, takes the jobs native code runs on isolates: inflating and decrypting sync payloads, hashing base parts, Argon2id, and streaming a large base file to and from an OPFS temp file, which is the one OPFS write path all three browsers share. Both workers are guarded by an import-graph test. `BackgroundDatabaseConnection`'s web file (a stub after Plan 1) becomes the real thing, and the startup page skips the native-only phases on the web.

**Tech Stack:** drift 2.34.3 `package:drift/wasm.dart` (`WasmDatabase.open`, `WasmDatabase.workerMainForOpen`, `WasmStorageImplementation`, `MissingBrowserFeature`), sqlite3 3.5.1 `sqlite3.wasm` from the sqlite3.dart GitHub release matching the locked version, `dart compile js -O4`, `package:web` for OPFS and `postMessage`, `package:cryptography` 2.9.0 (pure Dart path), `package:crypto`.

**Spec:** `docs/design/specs/2026-11-02-web-app-design.md` (sections "The database worker", "2b. Runtime hazards: dart:isolate", "Persistence", "Encryption", "Identity in the mesh" for the multi-tab lock).

## Global Constraints

- Everything in Plan 1's Global Constraints.
- Worker entry points are pure Dart: their transitive import closure has no `package:flutter`, `dart:ui`, `dart:io`, `dart:ffi` or `dart:isolate` import (Task 3's guard).
- Compiled workers and `sqlite3.wasm` are build outputs, never committed: `web/drift_worker.js`, `web/compute_worker.js`, `web/sqlite3.wasm` and `test/web/assets/` go in `.gitignore`.
- The database worker registers exactly the functions `registerAppSqlFunctions` registers (`unicode_lower`, `row_digest`, `tank_config_base`, `tank_config_summary`, `dive_ambient_bar`); no second implementation.
- Native code paths are untouched. The native `off_isolate`, base sink, parse client and database opener move to `_io.dart` files verbatim.
- Browser tests live under `test/web/` with a library-level `@TestOn('browser')` and their own `test/web/flutter_test_config.dart` (the root config imports `dart:io` helpers). They run with `flutter test --platform chrome test/web`. Plan 4 wires CI; here they run locally.
- Argon2id parameters do not change: they are part of the on-storage key slot format shared with every other device.

## Review Focus

1. Opening the web database twice in two tabs: Drift serialises access in the shared worker, but two tabs publishing at once would reuse one changeset sequence. Task 8 adds the cross-tab lock and a browser test that two `withCrossTabLock` bodies never overlap.
2. A `sqlite3.wasm` whose version does not match the `package:sqlite3` Dart bindings fails at runtime with an obscure import error. Task 2 pins URL and sha256 in a lock file and the fetch script refuses a mismatch.
3. A browser without OPFS (private mode, old Safari) falling to IndexedDB silently and the user believing data persists. Task 5 exposes `WebDatabaseStatus` and Plan 3 shows it in Settings; Task 5's test asserts the status reports `inMemory` when Drift says so.
4. A sync base larger than the tab's memory parsed inline because the worker failed to start. Task 6's web `BaseParseClient` has no inline fallback: it surfaces a `BaseParseException` naming the worker failure, and the test asserts that.
5. A compute job result that cannot cross `postMessage` (a Dart object, not bytes or JSON) silently becoming `null`. Task 4's protocol test round-trips every job's request and reply through JSON and `Uint8List` only.

---

### Task 1: Flutter-free SQL function import chain

**Files:**
- Create: `lib/core/constants/app_enums.dart` (every declaration now in `enums.dart` except the `export`)
- Modify: `lib/core/constants/enums.dart` becomes two lines: `export 'app_enums.dart'; export 'certification_enums.dart';`
- Create: `lib/features/dive_log/domain/entities/dive_tank.dart` (`class DiveTank` from `dive.dart:1198` and `class GasMix` from `dive.dart:1476`, moved verbatim with the imports they need)
- Modify: `lib/features/dive_log/domain/entities/dive.dart` gains `export 'dive_tank.dart';` and loses the two classes
- Modify: `lib/core/deco/entities/dive_environment.dart`, `lib/features/insights/data/tank_configuration_sql.dart`, `lib/features/insights/domain/tank_configuration/tank_configuration.dart`, `tank_configuration_classifier.dart` import `app_enums.dart` and `dive_tank.dart` instead of `enums.dart` and `dive.dart`
- Test: `test/core/database/sql_functions_import_graph_test.dart`

- [ ] **Step 1: Write the failing guard**

Model it on `test/core/database/database_import_graph_test.dart`: start at `lib/core/database/app_sql_functions.dart`, follow `package:submersion/` and relative imports, and collect any import URI starting with `package:flutter`, `dart:ui`, `dart:io`, `dart:ffi` or `dart:isolate`. Assert the start file exists, then `expect(offenders, isEmpty, reason: offenders.join('\n'))`. The offender line names the importing file and the URI.

- [ ] **Step 2: Run it, expect `certification_enums.dart -> dart:ui` and `tag.dart -> package:flutter/material.dart`**
- [ ] **Step 3: Do the two moves**

`app_enums.dart` is `enums.dart` minus line 1; `enums.dart` is the two exports. `dive_tank.dart` holds `DiveTank` and `GasMix`; check that neither references `Dive` or any Flutter-reaching entity (the inventory says they need `gas_model.dart`, `max_operating_depth.dart`, `gas_compressibility.dart`, `tank_extra_regulators.dart` and the enums).

- [ ] **Step 4: Run** `flutter test test/core/database/sql_functions_import_graph_test.dart test/core/database test/features/insights test/features/dive_log/domain test/core/constants`, expected pass, then `flutter analyze` clean (no consumer import changes since both files re-export)
- [ ] **Step 5: Commit** `refactor(database): make the SQL function import chain Flutter-free`

---

### Task 2: Worker build inputs: `sqlite3.wasm` fetch and worker compile

**Files:**
- Create: `scripts/web/sqlite3_wasm.lock` (two lines: `url=<release asset url for the sqlite3.dart tag matching pubspec.lock's sqlite3 version>` and `sha256=<hex>`)
- Create: `scripts/web/fetch_sqlite3_wasm.sh` (downloads to `web/sqlite3.wasm` unless present with the right hash; verifies with `shasum -a 256`; exits 1 on mismatch and deletes the file)
- Create: `scripts/web/compile_workers.sh` (`dart compile js -O4 -o web/drift_worker.js web/drift_worker.dart` and the same for `compute_worker`; then copies `web/*.js` and `web/sqlite3.wasm` to `test/web/assets/`)
- Create: `scripts/web/check_sqlite3_wasm_lock.py` (asserts the lock's version matches `pubspec.lock`'s sqlite3 version; run from `script-tests` in Plan 4) and `check_sqlite3_wasm_lock_test.py`
- Modify: `.gitignore` adds `web/drift_worker.js`, `web/compute_worker.js`, `web/sqlite3.wasm`, `test/web/assets/`
- Modify: `scripts/build_web.sh` runs fetch, compile, then `flutter build web`

- [ ] **Step 1: Write `check_sqlite3_wasm_lock_test.py`** (a lock naming version X passes against a pubspec.lock naming X and fails against X+1; run with `python3.14 -m pytest scripts/web`)
- [ ] **Step 2: Resolve the release asset URL for sqlite3 3.5.1, download once, record url and sha256 in the lock**
- [ ] **Step 3: Write the two shell scripts and the check script; run** `scripts/web/fetch_sqlite3_wasm.sh && ls -la web/sqlite3.wasm`
- [ ] **Step 4: Commit** `build(web): fetch sqlite3.wasm by pinned hash and compile the workers`

(The worker Dart files do not exist yet; `compile_workers.sh` is exercised in Task 3.)

---

### Task 3: The database worker and its guard

**Files:**
- Create: `web/drift_worker.dart`
  ```dart
  import 'package:drift/wasm.dart';
  import 'package:submersion/core/database/app_sql_functions.dart';
  void main() => WasmDatabase.workerMainForOpen(setupAllDatabases: registerAppSqlFunctions);
  ```
- Create: `test/architecture/web_worker_import_graph_test.dart`

- [ ] **Step 1: Write the guard**

For each of `web/drift_worker.dart` and `web/compute_worker.dart` (skip a missing file only until Task 4 lands, then require both), walk the import closure the way Task 1's test does, but resolve a conditional import `a if (dart.library.js_interop) b` to `b`. Offenders: `package:flutter`, `dart:ui`, `dart:io`, `dart:ffi`, `dart:isolate`.

- [ ] **Step 2: Run the guard against `drift_worker.dart`; expected pass after Task 1 (if it fails, the chain is not clean yet; fix it here)**
- [ ] **Step 3: Run** `scripts/web/compile_workers.sh` **and confirm `web/drift_worker.js` exists and `dart compile js` printed no errors**
- [ ] **Step 4: Commit** `feat(web): drift worker that registers the app SQL functions`

---

### Task 4: Compute protocol, job handlers and the compute worker

**Files:**
- Create: `lib/core/platform/compute/compute_protocol.dart` (pure)
  ```dart
  enum ComputeJob { inflateBounded, deflate, gzip, gunzip, aesGcmEncrypt, aesGcmDecrypt, argon2id, sha256, hashBaseParts, opfsCreate, opfsAppend, opfsClose, opfsRead, opfsLength, opfsDelete, baseParseStart, baseParseScalars, baseParseNext, baseParseDispose }
  class ComputeRequest { final int id; final ComputeJob job; final Map<String, Object?> args; Map<String, Object?> toJson(); factory ComputeRequest.fromJson(Map); }
  class ComputeReply { final int id; final Object? result; final String? error; ... toJson/fromJson }
  // Byte arguments and results travel as Uint8List values inside the map; everything else is JSON scalars, lists and maps.
  ```
- Create: `lib/core/platform/compute/compute_job_handlers.dart` (pure): `Future<Object?> handleComputeJob(ComputeJob job, Map<String, Object?> args, {required OpfsFiles files})` implementing every job with `PlatformZlib` (pure path), `package:cryptography` `DartAesGcm`/`DartArgon2id`, `package:crypto` sha256, `BaseChunker` part hashing (from `base_part_hasher.dart`'s pure parts), and `BaseJsonStreamReader` for the parse jobs. `OpfsFiles` is an abstract interface (`create`, `append`, `close`, `readChunk`, `length`, `delete`) so the handlers are testable on the VM with an in-memory fake.
- Create: `lib/core/platform/compute/opfs_files_web.dart` (`OpfsFiles` over `FileSystemSyncAccessHandle` in directory `submersion-sync-tmp`, worker-only API from `package:web`)
- Create: `web/compute_worker.dart` (reads `ComputeRequest` from `onmessage`, calls `handleComputeJob`, posts `ComputeReply`; transfers `Uint8List` buffers)
- Create: `lib/core/platform/compute/compute_worker_client.dart` (web: spawns `compute_worker.js` once, assigns ids, completes futures by id; `Future<Object?> call(ComputeJob job, Map<String, Object?> args)`; a `progress` stream for `baseParseNext` byte counts)
- Create: `lib/core/platform/compute/compute_jobs.dart` (facade), `compute_jobs_io.dart` (each method runs the same `handleComputeJob` inside `Isolate.run` when the payload is above `kOffIsolateMinBytes`, else inline, with an `OpfsFiles` backed by `File` in the sync temp dir), `compute_jobs_web.dart` (each method calls the client)
  ```dart
  abstract final class ComputeJobs {
    static Future<Uint8List> inflateBounded(Uint8List bytes, {required int maxBytes});
    static Future<Uint8List> deflate(Uint8List bytes, {int level = 6});
    static Future<Uint8List> gzip(Uint8List bytes, {int level = 6});
    static Future<Uint8List> gunzip(Uint8List bytes);
    static Future<Uint8List> aesGcmEncrypt({required Uint8List key, required Uint8List nonce, required Uint8List plaintext, Uint8List? aad});
    static Future<Uint8List> aesGcmDecrypt({required Uint8List key, required Uint8List nonce, required Uint8List ciphertextWithMac, Uint8List? aad});
    static Future<Uint8List> argon2id({required Uint8List password, required Uint8List salt, required int memoryKiB, required int iterations, required int parallelism, required int hashLength});
    static Future<Uint8List> sha256(Uint8List bytes);
    static Future<({String whole, List<String> parts})> hashBaseParts(Uint8List bytes, {required int partSize});
  }
  ```
- Modify: `lib/core/services/sync/crypto/sync_envelope.dart` (`_gzippedOffIsolate`, `_inflatedOffIsolate`, `_encryptedOffIsolate`, `_decryptedOffIsolate` call `ComputeJobs`), `lib/core/services/sync/crypto/keyslots.dart:132` (Argon2id through `ComputeJobs.argon2id`), `lib/core/services/sync/changeset_log/base_part_hasher.dart` (the hashing core moves to the pure handler; `openBasePartHasher` keeps its signature), `lib/core/services/sync/sync_data_serializer.dart` `checksumOfOffIsolate` (`ComputeJobs.sha256`)
- Test: `test/core/platform/compute/compute_protocol_test.dart`, `compute_job_handlers_test.dart` (VM, in-memory `OpfsFiles` fake), existing `test/core/services/sync/crypto/` and `test/core/services/sync/changeset_log/`

- [ ] **Step 1: Write the failing tests**

```dart
// compute_protocol_test.dart
test('every ComputeJob round-trips a request and reply through toJson/fromJson with Uint8List intact', ...);
// compute_job_handlers_test.dart
test('inflateBounded matches PlatformZlib and throws past maxBytes', ...);
test('aesGcm encrypt then decrypt returns the plaintext; a flipped byte fails', ...);
test('argon2id with the key slot parameters matches DartArgon2id.deriveKeyFromPassword', ...);
test('hashBaseParts equals BaseChunker + sha256 per part', ...);
test('opfs create, append, length, readChunk and delete through the fake', ...);
test('baseParse jobs stream a fixture base: scalars first, then batches of the requested tables, then dispose frees the handle', ...);
```

- [ ] **Step 2: Run, expect missing URIs**
- [ ] **Step 3: Implement protocol, handlers and the io facade; make the four modified call sites use `ComputeJobs`**

`keyslots.dart` keeps its `deriveKeyFromPassword` call shape but goes through the facade so the browser does not block on Argon2id. Existing crypto tests must stay green byte for byte.

- [ ] **Step 4: Run** `flutter test test/core/platform/compute test/core/services/sync`, expected pass
- [ ] **Step 5: Write `compute_worker.dart`, `opfs_files_web.dart`, `compute_worker_client.dart`, `compute_jobs_web.dart`; run `scripts/web/compile_workers.sh`; run the worker guard**

Expected: both workers compile, `test/architecture/web_worker_import_graph_test.dart` passes with both files required.

- [ ] **Step 6: Commit** `feat(web): compute worker for sync crypto, hashing and base streaming`

---

### Task 5: The web database connection

**Files:**
- Modify: `lib/core/database/background_database_connection_web.dart` (replace Plan 1's stub)
- Create: `lib/core/platform/web_database_status.dart` (facade), `_io.dart` (`webDatabaseStatusProvider` yields `null`), `_web.dart`
  ```dart
  class WebDatabaseStatus { final WasmStorageImplementation storage; final Set<MissingBrowserFeature> missingFeatures; bool get persists => storage != WasmStorageImplementation.inMemory; }
  final webDatabaseStatusProvider = Provider<WebDatabaseStatus?>(...);
  ```
- Modify: `lib/core/database/database_engine_preflight.dart` becomes a facade over `_io.dart` (today's SQLCipher probe) and `_web.dart` (`assertDatabaseEngineAvailable` calls `WasmDatabase.probe(sqlite3Uri: ..., driftWorkerUri: ...)` and throws `DatabaseEngineUnavailableException('the browser could not load sqlite3.wasm')` on failure)
- Modify: `lib/core/services/database_service.dart`: `initialize` skips `Directory.create` and `_assertCipherAvailable` when `HostPlatform.isWeb`; `_openDatabase` on the web reads the stored version through a probe open with `enableMigrations: false` instead of `getStoredSchemaVersion` (a `AppDatabase` over the probe connection, `customSelect('PRAGMA user_version')`, close), throws `DatabaseVersionMismatchException` when stored is newer, then opens normally; `_runUpgradeLadder` is not called on the web (Drift's `MigrationStrategy` runs `onUpgrade` itself)
- Modify: `lib/core/services/database_location_service.dart`: `getDatabasePath()` returns `kWebDatabasePath = '/opfs/Submersion/submersion.db'` on the web; `isCustomFolderSupported` is false on the web
- Modify: `lib/core/services/local_cache_database_service.dart` passes `'submersion_local'` through `openPlain` on the web (the opener derives the Drift database name from the path's basename without extension)
- Test: `test/web/database/web_database_open_test.dart` (browser), `test/core/services/database_service_web_path_test.dart` (VM: with `HostPlatform.isWeb` faked through an injectable `isWeb` parameter on `initialize`, the service skips the cipher check and the directory creation)

**Interfaces:**
- Produces: the web `BackgroundDatabaseConnection.open(String path, {String? keyHex})` calls `WasmDatabase.open(databaseName: basenameWithoutExtension(path), sqlite3Uri: Uri.parse('sqlite3.wasm'), driftWorkerUri: Uri.parse('drift_worker.js'), localSetup: registerAppSqlFunctions)` and records `chosenImplementation` and `missingFeatures` into `WebDatabaseStatus`. The URIs are relative to the page so they resolve under any base href; the browser tests override them to `/web/assets/...` through a `@visibleForTesting` static `assetBase`.
- `keyHex` must be null on the web; a non-null value throws `ArgumentError` (encryption at rest is not offered there).

- [ ] **Step 1: Write the browser test**

```dart
@TestOn('browser')
// test/web/database/web_database_open_test.dart
test('opens AppDatabase on WasmDatabase, creates schema at currentSchemaVersion, persists a diver across reopen', () async {
  BackgroundDatabaseConnection.assetBase = '/web/assets/';
  final a = await BackgroundDatabaseConnection.open('/opfs/Submersion/submersion.db');
  final db = AppDatabase(a.connection);
  expect((await db.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version'), AppDatabase.currentSchemaVersion);
  // insert a diver, close, reopen, read it back
  // expect WebDatabaseStatus.storage is opfsShared or opfsLocks in headless Chrome
});
test('unicode_lower and dive_ambient_bar resolve in the worker', ...);   // SELECT unicode_lower('ÄB') == 'äb'
```

- [ ] **Step 2: Create `test/web/flutter_test_config.dart`** (a `testExecutable` that only sets `TestWidgetsFlutterBinding` defaults; no `dart:io` helpers)
- [ ] **Step 3: Run** `scripts/web/compile_workers.sh && flutter test --platform chrome test/web/database`, expect failure on the stub
- [ ] **Step 4: Implement the web connection, status provider, preflight facade and the `DatabaseService` web branches**
- [ ] **Step 5: Run the browser test and the VM suites** `flutter test test/core/database test/core/services`, expected pass
- [ ] **Step 6: Commit** `feat(web): open the app database on WasmDatabase in the browser`

---

### Task 6: Sync temp files and the base parse client on the web

**Files:**
- Create: `lib/core/services/sync/changeset_log/sync_temp_files.dart` (facade), `_io.dart` (`File` in `resolveSyncTempDir()`), `_web.dart` (compute worker `opfs*` jobs; paths are `opfs://submersion-sync-tmp/<name>`)
  ```dart
  abstract final class SyncTempFiles {
    static Future<SyncTempSink> create(String name);
    static Stream<List<int>> openRead(String path);
    static Future<int> length(String path);
    static Future<bool> exists(String path);
    static Future<void> delete(String path);
  }
  abstract class SyncTempSink { Future<void> add(List<int> bytes); Future<String> close(); }   // close returns the path
  ```
- Modify: `lib/core/services/sync/changeset_log/base_part_file_sink.dart` writes through `SyncTempFiles` (its `tempDirProvider` parameter stays for native tests; on the web it is ignored)
- Rename: `lib/core/services/sync/changeset_log/base_parse_client.dart` to `_io.dart`; create facade and `base_parse_client_web.dart` with the same class surface (`spawn`, `onProgress`, `readScalarsAndDeletions`, `startDataRows`, `nextDataBatch`, `dispose`) over the `baseParse*` compute jobs; `spawn` throws `BaseParseException('compute worker unavailable: <cause>')` when the worker fails to start, and there is no inline fallback on the web
- Modify: `lib/core/services/sync/sync_service.dart`: the three `File(...).openRead()` sites (`_applyRemoteBaseFileInline` at ~2509/2553/2642 and `_adoptApplyStreamingRows` at ~5676) read through `SyncTempFiles.openRead`; `_applyRemoteBaseFileInner`'s catch-and-fall-back-inline only applies when `!HostPlatform.isWeb`
- Modify: `lib/core/services/sync/changeset_log/sync_temp_dir.dart`: `resolveSyncTempDir()` on the web throws `UnsupportedError` (no caller remains on the web path after this task; the guard in Plan 1 Task 9 keeps path_provider importers listed)
- Test: `test/core/services/sync/changeset_log/sync_temp_files_io_test.dart` (VM), `test/web/sync/sync_temp_files_web_test.dart` (browser: create, add 3 MiB in chunks, length, openRead concatenates to the same bytes, delete), `test/web/sync/base_parse_client_web_test.dart` (browser: write a fixture base to OPFS, spawn, scalars, two tables, dispose), existing `test/core/services/sync/`

- [ ] **Step 1: Write the three failing tests**
- [ ] **Step 2: Implement the facade and both implementations; move the parse client**
- [ ] **Step 3: Run** `flutter test test/core/services/sync` **and** `flutter test --platform chrome test/web/sync`, expected pass
- [ ] **Step 4: Commit** `feat(web): stream sync bases through OPFS temp files in the compute worker`

---

### Task 7: `off_isolate` facade and the remaining isolate call sites

**Files:**
- Rename: `lib/core/utils/off_isolate.dart` to `off_isolate_io.dart`; create facade and `off_isolate_web.dart` (`isolateRun` and `runOffIsolate` run the work inline; same signatures and constants)
- Modify (choose inline on the web, through `HostPlatform.isWeb`, native branch untouched): `lib/core/services/logger_service.dart` `isolateRunKeepingLogs`, `lib/core/services/shared_library/crypto/field_signatures.dart` `dropUnverifiedAll` (one sequential chunk on the web), `lib/core/services/export/uddf/uddf_dump_codec.dart` `_encodeOnWorker`, `lib/features/planner/presentation/providers/plan_background_results.dart` (`IsolatePlanResultRunner` is replaced by an inline runner on the web), `lib/features/planner/presentation/providers/mission_outcome_provider.dart` `runMissionEngineInIsolate`, `lib/features/documents/data/services/document_archive_exporter.dart` `_encode`
- Not modified (native-only features Plan 3 hides): `compact_database_file.dart`, `backup_crypto.dart`, `backup_service.dart`, `quarantined_database_service.dart`, `pdf_page_renderer.dart`, `corrected_photo_encoder.dart`
- Test: `test/core/utils/off_isolate_web_test.dart` (VM import of the web file: `runOffIsolate` returns the work's result and `isolateRun` runs the closure once), existing planner, logger and shared-library tests

- [ ] **Step 1: Write the failing test, move the file, add the facade and the web file**
- [ ] **Step 2: Add the inline branches at the six call sites**
- [ ] **Step 3: Run** `flutter test test/core/utils test/core/services test/features/planner test/features/documents`, expected pass
- [ ] **Step 4: Commit** `feat(web): run isolate work inline on the web where no worker job exists`

---

### Task 8: Cross-tab publish lock

**Files:**
- Create: `lib/core/platform/cross_tab_lock.dart` (facade), `_io.dart` (`withCrossTabLock(name, body) => body()`), `_web.dart` (`navigator.locks.request(name, body)` through `package:web`)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart:1500` wraps `_runSyncOnce` in `withCrossTabLock('submersion-sync', ...)` inside the existing `SyncCoordinator.run`
- Test: `test/web/platform/cross_tab_lock_test.dart` (browser: two bodies that each record enter and exit timestamps never overlap), `test/core/platform/cross_tab_lock_io_test.dart` (VM: body runs once and its value returns)

- [ ] **Step 1: Write both failing tests, implement, run** `flutter test --platform chrome test/web/platform` **and** `flutter test test/core/platform test/features/settings/presentation/providers`
- [ ] **Step 2: Commit** `feat(web): hold a Web Lock around sync so two tabs never publish together`

---

### Task 9: Web startup

**Files:**
- Modify: `lib/core/presentation/pages/startup_page.dart`: on the web skip `_resolveSecurityGate` (no encryption at rest), skip `initializeBackgroundService`, keep the migration progress UI (Drift reports through `onMigrationProgress` on upgrades); `assertDatabaseEngineAvailable` already resolves to the web probe via Task 5's facade
- Modify: `lib/core/services/security/database_security_service.dart`: `encryptionEnabled` and `appLockEnabled` are false on the web and `enableEncryption`/`enableSecurity` throw `UnsupportedError` (Plan 3 hides the switches)
- Test: `test/core/presentation/pages/startup_page_web_test.dart` (VM: with the web branches driven by an injectable `isWeb`, the page reaches the ready state without calling the security gate or the background service; use the existing `enginePreflightOverride` and database-initializer injection points), `test/web/startup/web_startup_test.dart` (browser: pump `SubmersionRestart` with real prefs and the web database; expect the setup wizard's first-run route, since the database has no divers)

- [ ] **Step 1: Write the failing tests, implement the branches**
- [ ] **Step 2: Run** `flutter test test/core/presentation test/core/services/security` **and** `flutter test --platform chrome test/web`, expected pass
- [ ] **Step 3: Manual check:** `scripts/build_web.sh && flutter run -d chrome` opens the setup wizard; reload keeps the database (DevTools Application tab shows OPFS entries)
- [ ] **Step 4: Commit** `feat(web): the web build boots to the setup wizard on a persistent browser database`

---

## Self-review notes

- Spec coverage: database worker and function registration (Tasks 1 to 3), compute worker and OPFS streaming (Tasks 4, 6), persistence ladder and status (Task 5), encryption derivation off the UI thread (Task 4), inline fallbacks (Task 7), multi-tab lock (Task 8), web startup (Task 9).
- Type consistency: `registerAppSqlFunctions(CommonDatabase)` is the worker's `setupAllDatabases` and the main-thread `localSetup`. `BackgroundDatabaseConnection.open(String path, {String? keyHex})` matches Plan 1's facade. `ComputeJobs` names are used verbatim in Task 4's four call sites and Task 6's web files.
- Review Focus coverage: 1 Task 8, 2 Task 2, 3 Task 5, 4 Task 6, 5 Task 4.
