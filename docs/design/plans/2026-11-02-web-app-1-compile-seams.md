# Web App Plan 1: Compile Seams and Platform Helpers

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `flutter build web --release` exits 0 on this codebase with the native app unchanged, and two architecture guards keep it that way.

**Architecture:** A diagnostic web compile on 2026-11-02 showed that only three groups of imports stop the Dart front end: `dart:ffi` in two Windows network files, `package:mcp_dart` in three agent-access files, and the FFI build of `package:sqlite3` reached by 19 files (two of them through `drift/native.dart`). Each group goes behind a facade that exports the native file by default and a web file when `dart.library.js_interop` is defined. Everything else compiles today and only throws at runtime, so the rest of this plan replaces the runtime hazards on the common path (`Platform.*` reads, `dart:io` zlib, `IOClient`, path_provider, the log file, the bootstrap) with facades of the same shape. Native code moves into `*_io.dart` files unchanged.

**Tech Stack:** Flutter 3.47.0, Dart conditional imports, drift 2.34.3, sqlite3 3.5.1 (`package:sqlite3/common.dart` types), `package:archive` 4.0.9 (already a dependency) for pure Dart zlib, `package:http` `BrowserClient`.

**Spec:** `docs/design/specs/2026-11-02-web-app-design.md` (sections "Architecture", "1. Compile blockers", "2. Runtime hazards", "3. The platform layer", "Entry point").

## Global Constraints

- Native behaviour does not change. Every seam moves native code into a `*_io.dart` file verbatim; the facade re-exports it. The full existing suite is the regression guard for this.
- Conditional imports use `if (dart.library.js_interop)` for the web branch. The one existing seam on `dart.library.html` (`lib/shared/services/file_share_handler.dart`) moves to `js_interop` in Task 1.
- New files 200 to 400 lines, never over 800. No emojis. `dart format .` before every commit.
- Imports grouped dart, flutter, packages, local. snake_case files.
- Paths built with `p.join`, temp space through the facade, never a literal `/tmp`.
- A test that touches process-wide state restores it in `addTearDown` (CI bundles test files into one isolate).
- No `Co-Authored-By` or tool attribution anywhere.
- Each task ends with `flutter analyze` clean and the named tests green before its commit. Run `test/architecture/` after any task that adds a file under `lib/`.
- Commit messages: `feat(web): ...` for product code, `test(web): ...` for guards, `refactor(<scope>): ...` for moves.

## Review Focus

1. A `Platform.isX` read that the sweep turns into `HostPlatform.isX` inside a `const` or `static const` initializer: `HostPlatform` getters are not const, so the analyzer must catch it. Task 6 runs `flutter analyze` and lists every file the sweep touched.
2. A file that had `import 'dart:io'` only for `Platform` keeps the now-unused import and the analyzer reports `unused_import` as a warning. Task 6's analyze step must be clean, not "no errors".
3. `PlatformZlib.inflateBounded` on the pure Dart path accepting a stream that expands past `maxBytes` before throwing, because the whole input was inflated first. Task 2's test uses a 2 MiB zero-filled body and asserts the exception, and the pure implementation is tested on the VM.
4. The zlib facade changing the bytes a native build writes to the database. Task 2 asserts the native encoder's output for a fixed input is byte-identical to `ZLibCodec(level: 6)`.
5. A seam facade whose web file lacks a member the native file has, found only when `flutter build web` runs. Task 8 is that compile, and Task 9's guard bans the raw imports so no new one appears later.

---

### Task 1: Raw sqlite3 and drift native seams

The 19 files importing `package:sqlite3/sqlite3.dart` split into 14 that only need types and 5 that call `sqlite3.open` or `openInMemory`. The types exist in `package:sqlite3/common.dart`. The five callers go through one facade.

**Files:**
- Create: `lib/core/platform/sqlite/raw_sqlite.dart` (facade), `raw_sqlite_io.dart`, `raw_sqlite_web.dart`
- Create: `lib/core/database/background_database_connection_io.dart` (today's code, moved), `background_database_connection_web.dart` (stub for this plan; Plan 2 replaces it)
- Modify: `lib/core/database/background_database_connection.dart` becomes the facade
- Modify (types only, `sqlite3.dart` import becomes `common.dart`): `lib/core/database/database_connection_setup.dart`, `lib/core/presentation/pages/startup_page.dart`, `lib/core/presentation/startup_failure.dart`, `lib/core/services/database_migration_service.dart`, `lib/core/services/startup_recovery_service.dart`, `lib/features/backup/data/services/backup_note_stamp.dart`, `lib/features/backup/data/services/backup_service.dart`, `lib/features/rules/data/services/rule_undo_service.dart`, `lib/features/universal_import/data/services/divemate_schema.dart`, `divinglog_db_reader.dart`, `divinglog_reference_reader.dart`, `divinglog_row_values.dart`, `macdive_db_reader.dart`, `shearwater_db_reader.dart`
- Modify (callers of the facade): `lib/core/database/database_engine_preflight.dart`, `lib/core/database/database_snapshot.dart`, `lib/core/services/database_service.dart`, `lib/core/services/security/database_encryption_migrator.dart`, `lib/features/universal_import/data/services/sqlite_temp_copy.dart`
- Modify: `lib/shared/services/file_share_handler.dart` (condition `dart.library.html` becomes `dart.library.js_interop`)
- Test: `test/core/platform/sqlite/raw_sqlite_test.dart`, existing `test/core/database/` and `test/features/universal_import/`

**Interfaces:**
- Produces:
  ```dart
  // raw_sqlite.dart
  abstract final class RawSqlite {
    static bool get isAvailable;                 // io: true, web: false
    static CommonDatabase open(String path, {OpenMode mode = OpenMode.readWrite});
    static CommonDatabase openInMemory();
  }
  // web: both open methods throw UnsupportedError('Raw SQLite access is native only')
  ```
  ```dart
  // background_database_connection.dart (same surface in _io and _web)
  Future<bool> closeDatabaseForAppShutdown(GeneratedDatabase db, {BackgroundDatabaseConnection? background, Duration gracefulTimeout, Duration executorTimeout, Duration workerTimeout});
  DatabaseConnection openMainIsolateConnection(String path, {String? keyHex});   // io: NativeDatabase(File(path), setup: applyMainDatabaseSetup); web: throws UnsupportedError in this plan
  class BackgroundDatabaseConnection {
    final DatabaseConnection connection;
    static Future<BackgroundDatabaseConnection> open(String path, {String? keyHex, @visibleForTesting DatabaseConnection Function()? debugOpener});
    static Future<BackgroundDatabaseConnection> openPlain(String path);
    Future<bool> awaitWorkerShutdown({required Duration timeout, required bool killIfStuck});
  }
  ```
  Note the `File` parameters of `open` and `openPlain` become `String path`; the two callers (`database_service.dart:557-575`, `local_cache_database_service.dart:67`) pass `file.path`.
- `applyMainDatabaseSetup(CommonDatabase db, {String? keyHex})` and `applyConnectionBasics(CommonDatabase db, {String? keyHex})` take `CommonDatabase` from now on. Plan 2 reuses `applyMainDatabaseSetup` unchanged.

- [ ] **Step 1: Write the failing facade test**

```dart
// test/core/platform/sqlite/raw_sqlite_test.dart
test('RawSqlite is available on the VM and opens an in-memory database', () {
  expect(RawSqlite.isAvailable, isTrue);
  final db = RawSqlite.openInMemory();
  addTearDown(db.close);
  expect(db.select('SELECT 1 AS one').single['one'], 1);
});
test('RawSqlite.open honours read-only mode', () {
  // create a file db in Directory.systemTemp, reopen with OpenMode.readOnly, expect SqliteException on INSERT
});
```

- [ ] **Step 2: Run it, expect "Target of URI doesn't exist"**

Run: `flutter test test/core/platform/sqlite/raw_sqlite_test.dart`

- [ ] **Step 3: Create the three `raw_sqlite*` files**

`raw_sqlite_io.dart` wraps `sqlite3.sqlite3.open(path, mode: mode)` and `openInMemory()`. `raw_sqlite_web.dart` throws. The facade is a one-line `export` with the conditional.

- [ ] **Step 4: Switch the five callers to `RawSqlite`, the fourteen type-only files to `common.dart`**

In `database_service.dart`, `openRaw` keeps its signature but its return type becomes `CommonDatabase` and its body calls `RawSqlite.open`. `database_connection_setup.dart` changes `Database` to `CommonDatabase`; `SqliteException` is already in `common.dart`.

- [ ] **Step 5: Move `background_database_connection.dart` to `_io.dart`, add the facade and the web stub**

`git mv lib/core/database/background_database_connection.dart lib/core/database/background_database_connection_io.dart`, then change the `File` parameters to `String path`, add `openMainIsolateConnection`, write the facade, write the web stub with every member throwing `UnsupportedError('Plan 2 adds the browser database')`. Move the `NativeDatabase(file, setup: ...)` construction at `database_service.dart:464` into a call to `openMainIsolateConnection(file.path, keyHex: keyHex)`.

- [ ] **Step 6: Flip the file-share seam condition**

`lib/shared/services/file_share_handler.dart:6`: `dart.library.html` becomes `dart.library.js_interop`.

- [ ] **Step 7: Run the affected suites**

Run: `flutter test test/core/platform test/core/database test/core/services test/features/universal_import test/features/backup test/shared/services`
Expected: all pass. `grep -rn "sqlite3/sqlite3.dart\|drift/native.dart\|drift/isolate.dart" lib --include=*.dart` lists only `raw_sqlite_io.dart` and `background_database_connection_io.dart`.

- [ ] **Step 8: Commit**

```bash
git add -A lib/core/platform/sqlite lib/core/database lib/core/services lib/core/presentation lib/features lib/shared/services test/core/platform
git commit -m "refactor(database): seam raw sqlite3 and drift native behind platform facades"
```

---

### Task 2: Pure Dart zlib facade

`dart:io`'s `ZLibCodec` and `GZipCodec` throw on the web and sit on the hot path: every dive profile and tank pressure series is a zlib blob, and sync envelopes are gzipped.

**Files:**
- Create: `lib/core/platform/zlib/platform_zlib.dart` (facade), `platform_zlib_io.dart`, `platform_zlib_web.dart`, `platform_zlib_pure.dart` (the `package:archive` implementation; the web file delegates to it, and the VM tests import it directly), `zlib_exceptions.dart`
- Modify: `lib/core/database/raw_dive_data_codec.dart`, `lib/features/dive_log/domain/codecs/profile_series_codec.dart`, `lib/features/dive_log/domain/codecs/tank_pressure_series_codec.dart`, `lib/features/dive_log/domain/codecs/bounded_inflate.dart`, `lib/core/utils/bounded_inflate.dart`, `lib/core/services/sync/crypto/sync_envelope.dart` (gzip calls only), `lib/core/services/nearby/nearby_transfer.dart` (gzip calls only)
- Test: `test/core/platform/zlib/platform_zlib_test.dart`, existing codec tests under `test/features/dive_log/domain/codecs/` and `test/core/utils/`

**Interfaces:**
- Produces:
  ```dart
  abstract final class PlatformZlib {
    static Uint8List deflate(List<int> bytes, {int level = 6});       // zlib framing
    static Uint8List inflate(List<int> bytes);
    static Uint8List inflateBounded(List<int> bytes, {required int maxBytes});  // throws ZlibBoundExceeded
    static Uint8List gzip(List<int> bytes, {int level = 6});
    static Uint8List gunzip(List<int> bytes);
  }
  class ZlibBoundExceeded implements Exception { final int maxBytes; }
  class ZlibFormatException implements Exception { final String message; }
  ```
  Both `bounded_inflate.dart` files keep their public functions and exception types; their bodies call `PlatformZlib.inflateBounded` and translate `ZlibBoundExceeded` and `ZlibFormatException` into the exceptions they throw today.
- The pure file exposes the same five functions as top-level `pureDeflate`, `pureInflate`, `pureInflateBounded`, `pureGzip`, `pureGunzip` so the VM test can call them without the facade.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/platform/zlib/platform_zlib_test.dart
for (final (name, deflate, inflate) in [('facade', PlatformZlib.deflate, PlatformZlib.inflate), ('pure', pureDeflate, pureInflate)]) {
  test('$name round-trips 1 MiB of mixed bytes', ...);
}
test('native deflate output is byte-identical to ZLibCodec(level: 6)', () {
  expect(PlatformZlib.deflate(sample), ZLibCodec(level: 6).encode(sample));
});
test('pure inflate accepts native deflate output and vice versa', ...);
test('inflateBounded throws ZlibBoundExceeded at maxBytes on both paths', () {
  final zeros = Uint8List(2 * 1024 * 1024);
  final packed = PlatformZlib.deflate(zeros);
  expect(() => PlatformZlib.inflateBounded(packed, maxBytes: 1024 * 1024), throwsA(isA<ZlibBoundExceeded>()));
  expect(() => pureInflateBounded(packed, maxBytes: 1024 * 1024), throwsA(isA<ZlibBoundExceeded>()));
});
test('inflate of garbage throws ZlibFormatException on both paths', ...);
test('gzip round-trips and gunzip accepts the other path\'s output', ...);
```

- [ ] **Step 2: Run, expect missing-URI failure**

- [ ] **Step 3: Implement `platform_zlib_io.dart`**

`ZLibCodec(level: level)`, `GZipCodec(level: level)`; `inflateBounded` moves the chunked-conversion bounded sink that `lib/core/utils/bounded_inflate.dart:75` has today, throwing `ZlibBoundExceeded` instead of its own exception.

- [ ] **Step 4: Implement `platform_zlib_pure.dart` with `package:archive`**

`ZLibEncoder`/`ZLibDecoder` and `GZipEncoder`/`GZipDecoder` for the unbounded calls. For `pureInflateBounded`, validate the 2-byte zlib header (CMF low nibble 8, `(CMF*256+FLG) % 31 == 0`, no preset dictionary) then run archive's `Inflate.buffer` over the remainder into an `OutputStream` subclass that throws `ZlibBoundExceeded` when its length would pass `maxBytes`. Map archive's `ArchiveException` to `ZlibFormatException`.

- [ ] **Step 5: Point the seven callers at the facade**

Keep each caller's exception types and messages. `sync_envelope.dart` and `nearby_transfer.dart` lose their `dart:io` import only if nothing else in the file needs it.

- [ ] **Step 6: Run the suites**

Run: `flutter test test/core/platform/zlib test/features/dive_log/domain test/core/utils test/core/services/sync test/core/database`
Expected: pass.

- [ ] **Step 7: Commit**

```bash
git commit -am "feat(web): zlib facade with a pure Dart implementation for the browser"
```

---

### Task 3: Windows FFI and MCP server seams

**Files:**
- Rename: `lib/core/network/windows_root_store.dart` to `windows_root_store_io.dart`; create facade `windows_root_store.dart` and `windows_root_store_web.dart` (`List<Uint8List> readWindowsRootCertificates() => const []`)
- Rename: `lib/core/network/proxy/system/windows_system_proxy_resolver.dart` to `_io.dart`; create facade and `_web.dart` (`WindowsSystemProxyResolver.resolve` returns the same "direct" `SystemProxyResult` the env fallback returns when nothing is configured; `readIeProxyConfig` and `queryPacForUrl` throw `UnsupportedError`)
- Rename: `lib/features/agent_access/data/server/agent_access_server.dart` to `_io.dart`; create facade and `_web.dart` with the same class surface, every start method throwing `UnsupportedError('Agent access is native only')` and any `isSupported`-style getter false
- Modify: `lib/features/agent_access/presentation/providers/agent_access_providers.dart` drops `import 'package:mcp_dart/mcp_dart.dart' show McpServer` by typing the provider against the server class or `Object`; `mcp_server_builder.dart` is imported only from the io server
- Test: existing `test/core/network/` and `test/features/agent_access/`

- [ ] **Step 1: Read each file's public surface and write the web stub to match it exactly**
- [ ] **Step 2: `git mv` each native file to `_io.dart`, add facades**
- [ ] **Step 3: Run `flutter test test/core/network test/features/agent_access`**, expected pass
- [ ] **Step 4: Commit** `refactor(network): seam Windows FFI and the MCP server for the web build`

---

### Task 4: HTTP client, directories and log file facades

**Files:**
- Create: `lib/core/network/platform_http_client.dart` (facade), `_io.dart` (`IOClient(HttpClient()..connectionTimeout = connectionTimeout)`), `_web.dart` (`BrowserClient()`)
- Modify: `lib/core/services/cloud_storage/s3/s3_api_client.dart:106` `_defaultClient`, `lib/core/services/cloud_storage/http_timeouts.dart:46`, `lib/core/services/cloud_storage/webdav/webdav_tls.dart:129-137` (`createWebDavHttpClient` keeps its signature; the web branch returns the platform client and ignores the trust recorder, since the browser owns certificate trust), `lib/features/maps/data/services/tile_cache_service.dart:399`
- Create: `lib/core/platform/app_directories.dart` (facade), `_io.dart` (path_provider), `_web.dart` (constants `/opfs/support`, `/opfs/documents`, `/opfs/temp`)
- Rename: `lib/core/services/log_file_service.dart` to `log_file_service_io.dart`; create facade and `log_file_service_web.dart` (same constructor and members; an in-memory `ListQueue<String>` capped at `maxFileSizeBytes` characters that drops its oldest half when full; `logFilePath` returns `memory://submersion.log`; `initialize` is a no-op)
- Test: `test/core/network/platform_http_client_test.dart` (VM: returns an `IOClient`), `test/core/services/log_file_service_web_test.dart` (import the web file directly on the VM: write 3 lines, read 3 entries, overflow drops oldest half, clearLog empties), existing `test/core/services/log_file_service_test.dart`

**Interfaces:**
- Produces: `http.Client createPlatformHttpClient({Duration connectionTimeout = const Duration(seconds: 15)})`; `AppDirectories.support()`, `.documents()`, `.temp()` each `Future<String>`.

- [ ] **Step 1: Write the two failing tests above**
- [ ] **Step 2: Create the facades and implementations**
- [ ] **Step 3: Replace the four `IOClient(HttpClient()...)` sites and `main.dart`'s `getApplicationSupportDirectory()` call (Task 5 moves that line; here only the import changes)**
- [ ] **Step 4: Run** `flutter test test/core/network test/core/services test/core/services/cloud_storage`, expected pass
- [ ] **Step 5: Commit** `feat(web): platform facades for the HTTP client, app directories and the log file`

---

### Task 5: Bootstrap seam and single entry point

`lib/main.dart` keeps `main()`; its body moves behind a facade so `flutter build web` and `flutter run -d chrome` need no `-t` flag.

**Files:**
- Create: `lib/core/bootstrap/app_bootstrap.dart` (facade exporting `Future<void> bootstrapApp()`), `app_bootstrap_io.dart` (today's `_bootstrap` from `lib/main.dart`, moved verbatim: `HttpOverrides.global`, `migrateWindowsAppDataDirectories`, prefs, proxy controller, log directory, `DatabaseLocationService`, `runApp`), `app_bootstrap_web.dart` (prefs, media cache caps, quality toggles, `LogFileService(logDirectory: await AppDirectories.support())`, `DatabaseLocationService(prefs)`, `runApp(StartupWrapper(...))` with no HTTP overrides, no Windows migration, no proxy controller), `bootstrap_shared.dart` (the steps both share, so nothing is duplicated: `applyMediaCacheCaps`, `QualityDetectorTogglesNotifier.hydrateFromPrefs`, `LoggerService.configureFileLogging`, `logSessionEnvironment`, building `StartupWrapper`)
- Modify: `lib/main.dart` becomes `void main() => runZonedGuarded(bootstrapApp, ...)` plus whatever error reporting it has today
- Modify: `lib/core/providers/root_overrides.dart` accepts `proxyController` as nullable already; the web bootstrap passes null
- Test: existing `test/main_test.dart` or equivalent startup tests; `test/core/bootstrap/app_bootstrap_web_test.dart` importing the web file on the VM and asserting `bootstrapApp` reaches `runApp` with a `StartupWrapper` when `runApp` is injected (make `runApp` an injectable `@visibleForTesting` parameter of a `bootstrapWeb({void Function(Widget) run = runApp})` helper the facade's `bootstrapApp` calls)

- [ ] **Step 1: Write the failing web bootstrap test**
- [ ] **Step 2: Move `_bootstrap` into `app_bootstrap_io.dart`, extract the shared steps, write the web variant**
- [ ] **Step 3: Run** `flutter test test/core/bootstrap test/core/presentation` and the startup tests, expected pass
- [ ] **Step 4: Commit** `feat(web): bootstrap seam so lib/main.dart is the only entry point`

---

### Task 6: `HostPlatform` helper and the `Platform.` sweep

206 `Platform.` reads in 70 files. The native implementation keeps `dart:io` `Platform`, so native behaviour and every existing test are unchanged; only the web file answers differently.

**Files:**
- Create: `lib/core/platform/host_platform.dart` (facade), `host_platform_io.dart`, `host_platform_web.dart`
- Modify: the 70 files listed by `grep -rln "Platform\." lib --include=*.dart` (excluding comments), replacing `Platform.<member>` with `HostPlatform.<member>` and adding the import; remove `dart:io` imports that become unused
- Test: `test/core/platform/host_platform_test.dart`, `test/core/platform/host_platform_web_test.dart` (imports the web file on the VM), `test/architecture/host_platform_single_source_test.dart`

**Interfaces:**
- Produces:
  ```dart
  abstract final class HostPlatform {
    static bool get isWeb;        // io false, web true
    static bool get isAndroid; static bool get isIOS; static bool get isMacOS; static bool get isWindows; static bool get isLinux;   // web: all false
    static bool get isApple;      // isIOS || isMacOS
    static bool get isDesktop;    // isMacOS || isWindows || isLinux
    static bool get isMobile;     // isAndroid || isIOS
    static Map<String, String> get environment;   // web: const {}
    static String? get localHostname;             // io: Platform.localHostname; web: null
    static String get operatingSystem;            // web: 'web'
    static String get operatingSystemVersion;     // web: navigator.userAgent
    static String get localeName;                 // web: navigator.language
    static int get numberOfProcessors;            // web: navigator.hardwareConcurrency, min 1
    static String get pathSeparator;              // web: '/'
    static String get resolvedExecutable;         // web: ''
  }
  ```
  The web file reads `navigator` through `package:web` (add `web: ^1.1.0` to `pubspec.yaml` dependencies; it is already resolved transitively at 1.1.x in `pubspec.lock`).

- [ ] **Step 1: Write the failing tests**

```dart
// host_platform_test.dart: isWeb false; each isX equals dart:io Platform.isX; environment equals Platform.environment; isDesktop and isApple composed correctly
// host_platform_web_test.dart (VM import of host_platform_web.dart is impossible because of package:web; instead the web file keeps its navigator reads in a tiny `BrowserInfo` class with an injectable fake, and the test covers the pure composition: isWeb true, every isX false, pathSeparator '/', numberOfProcessors >= 1 when the fake reports 0)
// host_platform_single_source_test.dart: using MaskedSource from test/architecture/source_mask.dart, scan lib/ for the regex `(?<![A-Za-z_.])Platform\.(is[A-Z]\w*|environment|localHostname|operatingSystem\w*|localeName|numberOfProcessors|pathSeparator|resolvedExecutable|version|script|executable)` in code (not comments or strings); the only allowed file is lib/core/platform/host_platform_io.dart; the test fails if that file is missing so it cannot pass vacuously
```

- [ ] **Step 2: Run the guard, expect about 70 offending files**
- [ ] **Step 3: Create the three files, add `web` to pubspec, `flutter pub get`**
- [ ] **Step 4: Sweep**

Use a script in the scratchpad that, for each offending file, replaces the regex matches with `HostPlatform.$1`, inserts `import 'package:submersion/core/platform/host_platform.dart';` in the local import group, and leaves `dart:io` in place. Then run `flutter analyze`; delete each `dart:io` import the analyzer reports unused. Do not touch `host_platform_io.dart`.

- [ ] **Step 5: Run the guard and the whole suite**

Run: `flutter test test/architecture/host_platform_single_source_test.dart test/core/platform` then `./scripts/run_all_tests.sh`
Expected: guard passes with zero offenders; full suite green (native semantics are identical, so any failure is a sweep mistake).

- [ ] **Step 6: Commit** `refactor(platform): route every Platform read through HostPlatform`

---

### Task 7: `kIsWeb` reads that gate features move to the helper

The 19 `kIsWeb` files stay as they are where they size a layout. Where they gate a feature (`contact_import_support.dart`, `card_emulation_service.dart`, `location_service.dart`, `garmin_device_detector.dart`, `global_drop_target.dart`), replace `kIsWeb` with `HostPlatform.isWeb` so Plan 3's capability object has one place to look. No behaviour change.

- [ ] **Step 1: Replace and run** `flutter test test/shared test/features/buddies test/core/services test/features/universal_import`
- [ ] **Step 2: Commit** `refactor(platform): feature gates read HostPlatform.isWeb`

---

### Task 8: The web compile

**Files:**
- Create: `scripts/build_web.sh` (first version: `flutter build web --release "$@"`; Plan 2 and Plan 4 extend it)

- [ ] **Step 1: Run** `flutter build web --release 2>&1 | tee "$SCRATCH/web-build-2.log"; echo exit=$?`
- [ ] **Step 2: If the front end reports new unavailable libraries, seam them the same way as Tasks 1 to 4 (facade, `_io`, `_web`) and record each in this plan's commit message**
- [ ] **Step 3: Repeat until** `exit=0` and `build/web/main.dart.js` exists
- [ ] **Step 4: Commit** `feat(web): the app compiles for the web`

---

### Task 9: Compile-seam guard

**Files:**
- Create: `test/architecture/web_compile_seams_test.dart`

- [ ] **Step 1: Write the guard**

Scan `lib/` (skipping generated files) for import URIs `dart:ffi`, `package:ffi/`, `package:sqlite3/sqlite3.dart`, `package:drift/native.dart`, `package:drift/isolate.dart`, `package:mcp_dart/`, `package:path_provider/`, `package:http/io_client.dart`. Allowed only in files whose name ends in `_io.dart`. Assert the list of files that are allowed is non-empty (so the guard fails loudly if the io files are renamed). For `package:path_provider/`, the allowlist is the current importers outside the facade (the 24 files the inventory found) written as an explicit set, with a comment that Plan 3 shrinks it: a new importer fails the guard.

- [ ] **Step 2: Run** `flutter test test/architecture/`, expected pass
- [ ] **Step 3: Commit** `test(web): guard the web compile seams`

---

## Self-review notes

- Spec coverage: compile blockers (Tasks 1, 3, 8), `dart:io` runtime hazards on the common path (Tasks 2, 4, 5, 6), guard (Tasks 6, 9), single entry point (Task 5). The capability object, the browser database and the workers are Plans 2 and 3.
- Type consistency: `CommonDatabase` replaces `Database` in `applyMainDatabaseSetup`; Plan 2's worker registers functions through the same `registerAppSqlFunctions(CommonDatabase)`. `BackgroundDatabaseConnection.open(String path, {String? keyHex})` is the shape Plan 2 implements for the web.
- The web variants written here (`background_database_connection_web.dart`, `app_bootstrap_web.dart`) are placeholders that compile and throw; Plan 2 makes them real. The PR description states this ordering.
