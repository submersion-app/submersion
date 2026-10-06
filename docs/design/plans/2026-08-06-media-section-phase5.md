# Media Section Phase 5 (Watcher, Audit, Smart Albums, Sources) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Media section program: a background watcher that auto-repairs exact-hash moves, a per-device repair audit trail, synced smart albums, and a per-source browsing section.

**Architecture:** Two independent halves. **Part A (repair automation)** adds a per-device cache-DB index of watched folders, a scanner that re-hashes only changed files and feeds exact matches straight into the Phase 3 `MediaRepairService`, and an audit log every repair path writes. **Part B (library extras)** makes `MediaLibraryFilter` JSON-serializable so a smart album is a named saved filter (synced), plus a Sources section that browses by source type. Spec: `docs/superpowers/specs/2026-08-05-media-section-design.md` sections 4 and 7.

**Tech Stack:** Flutter 3.x, Drift (main DB + local cache DB), Riverpod (barrel), the Phase 3 repair engine (`MediaRepairService`, `RepairProposal`, `sha256OfFile`).

## Global Constraints

Identical to Phase 1-4 (worktree-only + `pwd`, `dart format .` no-op before commits, `flutter analyze` zero issues, no emojis, every string in `app_en.arb` plus the 10 locale ARBs with real translations then `flutter gen-l10n`, Riverpod via the barrel, `MaterialApp(locale: Locale('en'))` in widget tests, no Drift under `FakeAsync`, no Co-Authored-By). This phase does NOT touch `dive_media_section.dart`; the full suite runs once in the final task.

**Schema claims, verified 2026-08-06 against the ladder memory AND `git show origin/main:lib/core/database/database.dart | grep currentSchemaVersion`:**

- Main DB is at **v142** on origin/main (v138 divelogs and v140 media-section are reserved gaps). This phase claims **v143** for ONE migration creating BOTH new tables. Re-verify immediately before the Task 2 commit — if v143 is taken, renumber to the next free number everywhere in Task 2.
- Local cache DB is at **schemaVersion 8** (`local_cache_database.dart:124`). This phase claims **v9**.
- The cache DB is per-device and never synced or backed up — correct semantics for watched roots and the file index, both of which are pure device state.

Facts locked in during research:

- Cache migrations are `if (from < N) await m.createTable(x);` plus an idempotent `CREATE TABLE IF NOT EXISTS` re-assert in `beforeOpen` (ladder-collision self-heal), exactly as v7/v8 do at `local_cache_database.dart:153-190`.
- Registering a SYNCED entity touches 8 sites: `SyncRepository.entityTables` (sync_repository.dart:83 idiom), `sync_service.dart` `hasUpdatedAt` map (:1833) and `parentRefs` (:1904) and the changeset apply list (:1190), and `sync_data_serializer.dart` field (:228) + constructor param (:302) + `toJson` (:377) + `fromJson` (:453) + export-registry entry (`(key:, table:, blob: false, full: null)`, :670) + `_export<Entity>` helper + the `_safeExport` call (:1188).
- A per-device table (the repair log) is registered in NONE of those — that is what keeps device-local paths off the wire.
- `sha256OfFile(File) → ({String hash, int sizeBytes})` lives in `lib/core/services/media_store/store_keys.dart`.
- The opportunistic-background-pass idiom (cadence gate + fire-and-forget + never break the caller) is `media_store_providers.dart:420-462`; its pure gate `shouldAutoVerify` (media_verify_service.dart:27) is the shape to copy, including the future-clock defense.

---

## Part A — repair automation

### Task 1: Cache DB v9 — watched roots and file index

**Files:**
- Modify: `lib/core/database/local_cache_database.dart` (two tables, `@DriftDatabase` tables list, `schemaVersion => 9`, onUpgrade block, beforeOpen re-assert)
- Create: `lib/features/media/data/repositories/watched_folder_repository.dart`
- Test: `test/features/media/data/watched_folder_repository_test.dart`

**Interfaces:**
- Produces:

```dart
// Tables (cache DB):
class WatchedRoots extends Table {
  TextColumn get path => text()();
  IntColumn get addedAt => integer()();
  IntColumn get lastScanAt => integer().nullable()();
  @override Set<Column> get primaryKey => {path};
}
class WatchedFolderIndex extends Table {
  TextColumn get rootPath => text()();
  TextColumn get relativePath => text()();
  IntColumn get sizeBytes => integer()();
  IntColumn get mtimeMillis => integer()();
  TextColumn get contentHash => text().nullable()();
  @override Set<Column> get primaryKey => {rootPath, relativePath};
}

class IndexedFile {
  const IndexedFile({required this.rootPath, required this.relativePath,
      required this.sizeBytes, required this.mtimeMillis, this.contentHash});
  String get absolutePath => '$rootPath/$relativePath';
}

class WatchedFolderRepository {
  WatchedFolderRepository({LocalCacheDatabase? database});
  Future<List<String>> getRoots();
  Future<void> addRoot(String path);
  Future<void> removeRoot(String path);        // also prunes its index rows
  Future<DateTime?> lastScanAt(String rootPath);
  Future<void> stampScanned(String rootPath, DateTime at);
  Future<Map<String, IndexedFile>> indexForRoot(String rootPath); // by relativePath
  Future<void> upsertIndexed(IndexedFile file);
  Future<void> pruneMissing(String rootPath, Set<String> keepRelativePaths);
  Future<Map<String, String>> hashToPath();    // contentHash -> absolute path
}
```

- [ ] **Step 1: Write the failing tests** (harness: `LocalCacheDatabase(NativeDatabase.memory())` then `WatchedFolderRepository(database: cacheDb)`, the idiom from `test/features/media_store/media_upload_pipeline_test.dart:96`):

```dart
test('roots round-trip and removal prunes the index', () async {
  await repo.addRoot('/nas/Dives');
  expect(await repo.getRoots(), ['/nas/Dives']);
  await repo.upsertIndexed(const IndexedFile(rootPath: '/nas/Dives',
      relativePath: '2026/a.jpg', sizeBytes: 4, mtimeMillis: 1, contentHash: 'H'));
  await repo.removeRoot('/nas/Dives');
  expect(await repo.getRoots(), isEmpty);
  expect(await repo.indexForRoot('/nas/Dives'), isEmpty);
});

test('upsert replaces by (root, relativePath) and hashToPath maps absolutes',
    () async {
  await repo.upsertIndexed(const IndexedFile(rootPath: '/r',
      relativePath: 'a.jpg', sizeBytes: 4, mtimeMillis: 1, contentHash: 'OLD'));
  await repo.upsertIndexed(const IndexedFile(rootPath: '/r',
      relativePath: 'a.jpg', sizeBytes: 9, mtimeMillis: 2, contentHash: 'NEW'));
  final index = await repo.indexForRoot('/r');
  expect(index, hasLength(1));
  expect(index['a.jpg']!.sizeBytes, 9);
  expect(await repo.hashToPath(), {'NEW': '/r/a.jpg'});
});

test('pruneMissing drops rows whose file vanished', () async {
  await repo.upsertIndexed(const IndexedFile(rootPath: '/r',
      relativePath: 'keep.jpg', sizeBytes: 1, mtimeMillis: 1));
  await repo.upsertIndexed(const IndexedFile(rootPath: '/r',
      relativePath: 'gone.jpg', sizeBytes: 1, mtimeMillis: 1));
  await repo.pruneMissing('/r', {'keep.jpg'});
  expect((await repo.indexForRoot('/r')).keys, ['keep.jpg']);
});

test('stampScanned records the cadence timestamp', () async {
  await repo.addRoot('/r');
  expect(await repo.lastScanAt('/r'), isNull);
  await repo.stampScanned('/r', DateTime(2026, 6, 12));
  expect(await repo.lastScanAt('/r'), DateTime(2026, 6, 12));
});

test('fresh cache database has both v9 tables', () async {
  final names = await cacheDb.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table'").get();
  final set = names.map((r) => r.read<String>('name')).toSet();
  expect(set, containsAll(['watched_roots', 'watched_folder_index']));
});
```

- [ ] **Step 2: FAIL run** — `flutter test test/features/media/data/watched_folder_repository_test.dart --timeout 120s`
- [ ] **Step 3: Implement**

In `local_cache_database.dart`: declare both tables (shapes above) with the doc comment "Media section Phase 5: per-device watcher state. Derivable — a wipe costs a re-scan, never user data."; add both to the `@DriftDatabase(tables: [...])` annotation; bump `int get schemaVersion => 9;`; append the onUpgrade block:

```dart
      // v9: watcher state (Media section Phase 5).
      if (from < 9) {
        await m.createTable(watchedRoots);
        await m.createTable(watchedFolderIndex);
      }
```

and in `beforeOpen`, after the existing re-asserts, the same self-heal shape used for v7/v8:

```dart
      await customStatement('''
        CREATE TABLE IF NOT EXISTS watched_roots (
          path TEXT NOT NULL,
          added_at INTEGER NOT NULL,
          last_scan_at INTEGER,
          PRIMARY KEY (path)
        )
      ''');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS watched_folder_index (
          root_path TEXT NOT NULL,
          relative_path TEXT NOT NULL,
          size_bytes INTEGER NOT NULL,
          mtime_millis INTEGER NOT NULL,
          content_hash TEXT,
          PRIMARY KEY (root_path, relative_path)
        )
      ''');
```

Then `dart run build_runner build --delete-conflicting-outputs` and write the repository with plain Drift selects/`insertOnConflictUpdate`/deletes (mirror `MediaTransferQueueRepository`'s constructor: `WatchedFolderRepository({LocalCacheDatabase? database}) : _database = database;` with `_db => _database ?? LocalCacheDatabaseService.instance.database`).

- [ ] **Step 4: PASS run** — `flutter test test/features/media/data/watched_folder_repository_test.dart test/core/database/ --timeout 120s`
- [ ] **Step 5: Commit** — "Add cache v9 watcher tables and repository"

---

### Task 2: Main DB v143 — repair log and smart albums tables

**Files:**
- Modify: `lib/core/database/database.dart` (two table classes, `@DriftDatabase` tables list, `currentSchemaVersion = 143`, `migrationVersions` entry, assert helper, onUpgrade block, beforeOpen backstop)
- Test: `test/core/database/migration_v143_media_phase5_test.dart`

**Interfaces:**
- Produces:

```dart
/// Per-device repair history. NOT synced (paths are device-specific,
/// same rationale as PendingPhotoSuggestions).
class MediaRepairLog extends Table {
  TextColumn get id => text()();
  TextColumn get mediaId => text()();
  TextColumn get batchId => text()();
  IntColumn get occurredAt => integer()();
  TextColumn get action => text()();   // relink | cloudBacked | autoRelink
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  TextColumn get source => text()();   // folder | photoLibrary | store | watcher | manual
  @override Set<Column> get primaryKey => {id};
}

/// A named saved MediaLibraryFilter. Synced (user data).
class MediaSmartAlbums extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get filterJson => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();
  @override Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 1: Write the failing test** — copy `test/core/database/migration_v140_retain_in_library_test.dart` and adapt: a `_dbAt142()` fixture stamping `PRAGMA user_version = 142` with a minimal `media` table, then

```dart
test('v143 creates the repair log and smart album tables', () async {
  final db = AppDatabase(_dbAt142());
  addTearDown(db.close);
  final names = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table'").get();
  final set = names.map((r) => r.read<String>('name')).toSet();
  expect(set, containsAll(['media_repair_log', 'media_smart_albums']));
});
test('fresh databases get both tables', () async { /* NativeDatabase.memory() */ });
test('v143 is present in the migration ladder', () {
  expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(143));
  expect(AppDatabase.migrationVersions, contains(143));
});
```

- [ ] **Step 2: FAIL run** — `flutter test test/core/database/migration_v143_media_phase5_test.dart --timeout 120s`
- [ ] **Step 3: Implement** — declare both tables next to `Media` in database.dart; add both to `@DriftDatabase(tables: [...])`; `currentSchemaVersion = 143`; append `143,` to `migrationVersions` with the comment `// v143: media_repair_log (per-device) + media_smart_albums (synced).`; add the idempotent helper beside `_assertMediaRetainInLibraryColumn`:

```dart
  /// v143: Media section Phase 5 tables. createTable is CREATE TABLE IF NOT
  /// EXISTS, so this is safe from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertMediaPhase5Schema() async {
    await createMigrator().createTable(mediaRepairLog);
    await createMigrator().createTable(mediaSmartAlbums);
  }
```

then the onUpgrade block after the v140 one:

```dart
        if (from < 143) {
          await _assertMediaPhase5Schema();
        }
        if (from < 143) await reportProgress();
```

and `await _assertMediaPhase5Schema();` in `beforeOpen` after the v140 backstop. Run codegen.

- [ ] **Step 4: PASS run** — `flutter test test/core/database/ --timeout 120s`
- [ ] **Step 5: Commit** — "Add v143 migration: repair log and smart album tables"

---

### Task 3: Repair audit log wired into the engine

**Files:**
- Create: `lib/features/media/data/repositories/media_repair_log_repository.dart`
- Modify: `lib/features/media/data/services/repair/media_repair_service.dart` (accept an optional log repository + a `source`, write one row per applied action, prune)
- Modify: `lib/features/media/presentation/providers/media_repair_providers.dart` (`mediaRepairServiceProvider` passes the log repository)
- Test: `test/features/media/data/repair/media_repair_log_test.dart`

**Interfaces:**
- Consumes: `RepairApplyReport`, `RepairProposal`, `RepairWrite` (Phase 3).
- Produces:

```dart
enum RepairLogAction { relink, cloudBacked, autoRelink }
enum RepairLogSource { folder, photoLibrary, store, watcher, manual }

class RepairLogEntry {
  const RepairLogEntry({required this.id, required this.mediaId,
      required this.batchId, required this.occurredAt, required this.action,
      this.oldValue, this.newValue, required this.source});
}

class MediaRepairLogRepository {
  Future<void> record(List<RepairLogEntry> entries);   // + prune to newest 500
  Future<List<RepairLogEntry>> recent({int limit = 100});
}

// MediaRepairService gains:
//   final MediaRepairLogRepository? log;   (constructor param `log`)
//   Future<RepairApplyReport> apply(List<RepairProposal> accepted,
//       {RepairLogSource source = RepairLogSource.manual});
```

- [ ] **Step 1: Failing tests** (extend the Phase 3 harness in `media_repair_service_test.dart`'s style — real temp files, in-memory DBs):

```dart
test('an applied relink writes one audit row carrying old and new paths',
    () async {
  // seed orphaned row at /gone/a.jpg with hash of a temp file; apply an
  // exact proposal with source: RepairLogSource.watcher;
  final entries = await logRepo.recent();
  expect(entries, hasLength(1));
  expect(entries.single.mediaId, 'a');
  expect(entries.single.action, RepairLogAction.autoRelink); // watcher source
  expect(entries.single.oldValue, '/gone/a.jpg');
  expect(entries.single.newValue, endsWith('a.jpg'));
  expect(entries.single.source, RepairLogSource.watcher);
});

test('a cloud-backed conversion logs the cloudBacked action', () async { ... });

test('every row in one apply shares a batch id', () async {
  // two proposals -> two rows, one distinct batchId
});

test('record prunes to the newest 500 rows', () async {
  // insert 505 entries via record(); expect recent(limit: 1000).length == 500
  // and that the oldest ones are gone.
});
```

- [ ] **Step 2: FAIL run**, **Step 3: Implement** — repository over `_db.mediaRepairLog` (insert in one transaction, then
`DELETE FROM media_repair_log WHERE id NOT IN (SELECT id FROM media_repair_log ORDER BY occurred_at DESC LIMIT 500)`);
in the service, build entries alongside the Stage B writes (action `cloudBacked` for store proposals, `autoRelink` when `source == RepairLogSource.watcher`, else `relink`; `oldValue` = the item's pre-repair `localPath ?? filePath`, `newValue` = the candidate path or asset id), one `batchId` per `apply` call (`const Uuid().v4()`), and call `log?.record(entries)` after Stage C. **Step 4: PASS run** — `flutter test test/features/media/data/repair/ --timeout 120s`.
- [ ] **Step 5: Commit** — "Add repair audit log and wire it into the engine"

---

### Task 4: Watcher scanner with exact-hash auto-apply

**Files:**
- Create: `lib/features/media/data/services/repair/watched_folder_scanner.dart`
- Create: `lib/features/media/presentation/providers/media_watcher_providers.dart`
- Test: `test/features/media/data/repair/watched_folder_scanner_test.dart`

**Interfaces:**
- Consumes: `WatchedFolderRepository` (T1), `MediaRepairService.apply(..., source:)` (T3), `MediaLibraryRepository.getPage(health: missing)`, `sha256OfFile`.
- Produces:

```dart
/// Pure cadence gate: at most one automatic scan per day, with the same
/// future-clock defense as shouldAutoVerify.
bool shouldAutoScan({required DateTime? lastScanAt, required DateTime now});

class WatcherScanReport {
  const WatcherScanReport({required this.filesIndexed, required this.rehashed,
      required this.autoRepaired});
}

class WatchedFolderScanner {
  WatchedFolderScanner({required this.watched, required this.repair,
      required this.loadMissingRows, this.autoApply = true});
  Future<WatcherScanReport> scan({required DateTime now});
}

final watchedFolderRepositoryProvider = Provider<WatchedFolderRepository>;
final watcherAutoApplyProvider = ...;   // AppSettingsRepository raw setting
                                        // 'media_watcher_auto_apply', default true
final watcherScannerProvider = Provider<WatchedFolderScanner>;
```

- [ ] **Step 1: Failing tests** (real temp dirs + in-memory DBs; a fake `loadMissingRows`):

```dart
test('first scan indexes every file and hashes each once', () async {
  // two files under the root; expect report.filesIndexed == 2, rehashed == 2,
  // and the repository index carries their hashes.
});

test('a second scan re-hashes only files whose size or mtime changed',
    () async {
  // scan, then rewrite ONE file (changing size), scan again:
  // expect report.rehashed == 1 (the untouched file keeps its stored hash).
});

test('an exact hash match on a missing row is auto-applied', () async {
  // missing row whose contentHash equals the temp file's hash ->
  // report.autoRepaired == 1 and the row now points at the found path.
});

test('non-exact candidates are never auto-applied', () async {
  // missing row whose hash matches nothing -> autoRepaired == 0, row untouched.
});

test('autoApply false indexes but repairs nothing', () async { ... });

test('shouldAutoScan gates to one run per day and ignores a future stamp', () {
  final now = DateTime(2026, 6, 12, 12);
  expect(shouldAutoScan(lastScanAt: null, now: now), isTrue);
  expect(shouldAutoScan(
      lastScanAt: now.subtract(const Duration(hours: 2)), now: now), isFalse);
  expect(shouldAutoScan(
      lastScanAt: now.subtract(const Duration(days: 2)), now: now), isTrue);
  expect(shouldAutoScan(
      lastScanAt: now.add(const Duration(days: 3)), now: now), isTrue);
});
```

- [ ] **Step 2: FAIL run**, **Step 3: Implement** — the scanner walks each root (`Directory(root).list(recursive: true, followLinks: false)`, skipping non-files and swallowing `FileSystemException` per root like `FolderCandidateSource` does), computes `relativePath` as the path minus `'$root/'`, compares `(size, mtime.millisecondsSinceEpoch)` against `indexForRoot`, re-hashes with `sha256OfFile` only on change or when `contentHash == null`, upserts, then `pruneMissing(root, seen)` and `stampScanned`. Auto-apply: build `hashToPath()`, and for each missing row whose `contentHash` is a key, apply
`RepairProposal(item: row, confidence: RepairConfidence.exact, candidate: RepairCandidate.file(path: found, sizeBytes: null, hash: row.contentHash))`
through `repair.apply(proposals, source: RepairLogSource.watcher)`. **Step 4: PASS run** — `flutter test test/features/media/data/repair/ --timeout 120s`.
- [ ] **Step 5: Commit** — "Add watched-folder scanner with exact-hash auto-repair"

---

### Task 5: Sources console section (per-source browsing + watcher UI)

**Files:**
- Modify: `lib/features/media/data/repositories/media_library_repository.dart` (`Future<Map<MediaSourceType, int>> countBySourceType()`)
- Create: `lib/features/media/presentation/pages/media_sources_section_view.dart`
- Modify: `lib/features/media/presentation/widgets/media_console_scaffold.dart` (`MediaConsoleSection.sources` before `importMedia`, icon `Icons.source_outlined`, label `media_console_sources`)
- Modify: `lib/features/media/presentation/pages/media_section_page.dart`
- Modify: l10n arbs + gen-l10n — `media_console_sources` "Sources", `media_sources_browseHeader` "Browse by source", `media_sources_watchedHeader` "Watched folders", `media_sources_addWatched` "Add folder...", `media_sources_scanNow` "Scan now", `media_sources_autoApply` "Automatically re-link exact matches", `media_sources_neverScanned` "Never scanned", `media_sources_lastScanned` "Last scanned {date}", `media_sources_scanResult` "{indexed} files indexed, {repaired} re-linked"
- Test: `test/features/media/presentation/media_sources_section_test.dart`

**Interfaces:**
- Consumes: `countBySourceType`, `watchedFolderRepositoryProvider`, `watcherScannerProvider`, `watcherAutoApplyProvider`, `mediaLibraryFilterProvider` (Phase 1).
- Produces: `MediaSourcesSectionView` — a "Browse by source" list (one row per source type with its count; tapping sets `mediaLibraryFilterProvider` to that `sourceType` and switches the console to Library via an `onBrowseSource` callback passed by the section page) plus a "Watched folders" list with add/remove, per-root last-scanned text, an auto-apply switch, and a "Scan now" button showing the result in a snackbar.

- [ ] **Step 1: Failing tests** — repository test for `countBySourceType` (seed rows of three source types, expect the map; signatures excluded), plus widget tests over seeded providers (source rows render counts; tapping one sets the filter and invokes the browse callback; adding a root via an injected picker override lists it; Scan now calls an injected scanner fake and shows the result).
- [ ] **Step 2: FAIL run**, **Step 3: Implement** (`countBySourceType`: `selectOnly(media)..addColumns([sourceType, count])..where(not signature)..groupBy([sourceType])`), **Step 4: PASS run** — `flutter test test/features/media/ --timeout 120s`.
- [ ] **Step 5: Commit** — "Add Sources console section with watched folders"

---

### Task 6: Repair history view

**Files:**
- Create: `lib/features/media/presentation/pages/media_repair_history_view.dart`
- Modify: `lib/features/media/presentation/pages/media_missing_view.dart` (a history icon in the header pushing the view)
- Modify: l10n arbs + gen-l10n — `media_repairHistory_title` "Repair history", `media_repairHistory_empty` "No repairs yet", `media_repairHistory_action_relink` "Re-linked", `media_repairHistory_action_cloudBacked` "Cloud-backed", `media_repairHistory_action_autoRelink` "Auto re-linked", `media_repairHistory_source` "via {source}"
- Test: `test/features/media/presentation/media_repair_history_test.dart`

**Interfaces:**
- Consumes: `MediaRepairLogRepository.recent()` behind `repairHistoryProvider` (a `FutureProvider<List<RepairLogEntry>>` created in this task inside `media_repair_providers.dart`).
- Produces: `MediaRepairHistoryView` — newest-first list; each row shows the localized action, the new value, a `DateFormat.yMMMd().add_jm()` timestamp, and the source.

- [ ] **Step 1: Failing tests** (seeded provider: three entries render with their action labels; empty state shows `media_repairHistory_empty`), **Step 2: FAIL run**, **Step 3: Implement**, **Step 4: PASS run** — `flutter test test/features/media/presentation/media_repair_history_test.dart --timeout 120s`.
- [ ] **Step 5: Commit** — "Add repair history view"

---

## Part B — library extras

### Task 7: Serializable MediaLibraryFilter

**Files:**
- Modify: `lib/features/media/domain/entities/media_library_filter.dart`
- Test: `test/features/media/domain/media_library_filter_json_test.dart`

**Interfaces:**
- Produces: `Map<String, dynamic> toJson()` and `static MediaLibraryFilter fromJson(Map<String, dynamic> json)`. Enums serialize by `.name`; dates as epoch millis; unknown or malformed values decode to null so a smart album written by a newer version degrades instead of throwing.

- [ ] **Step 1: Failing tests**

```dart
test('round-trips every field', () {
  final filter = MediaLibraryFilter(
    mediaType: MediaType.video, siteId: 's1', tripId: 't1', diveId: 'd1',
    fromDate: DateTime(2026, 6, 1), toDate: DateTime(2026, 6, 30),
    sourceType: MediaSourceType.localFile,
    health: MediaHealthFilter.unlinked);
  expect(MediaLibraryFilter.fromJson(filter.toJson()), filter);
});
test('an empty filter round-trips to none', () {
  expect(MediaLibraryFilter.fromJson(MediaLibraryFilter.none.toJson()),
      MediaLibraryFilter.none);
});
test('unknown enum values decode to null rather than throwing', () {
  final decoded = MediaLibraryFilter.fromJson(
      {'mediaType': 'hologram', 'health': 'exploded'});
  expect(decoded.mediaType, isNull);
  expect(decoded.health, isNull);
});
```

(The equality check works because `MediaLibraryFilter` already implements `==`/`hashCode`.)

- [ ] **Step 2: FAIL run**, **Step 3: Implement**, **Step 4: PASS run** — `flutter test test/features/media/domain/media_library_filter_json_test.dart --timeout 120s`.
- [ ] **Step 5: Commit** — "Make MediaLibraryFilter JSON-serializable"

---

### Task 8: Smart album repository and sync registration

**Files:**
- Create: `lib/features/media/domain/entities/media_smart_album.dart`
- Create: `lib/features/media/data/repositories/media_smart_album_repository.dart`
- Modify: `lib/core/data/repositories/sync_repository.dart` (entityTables)
- Modify: `lib/core/services/sync/sync_service.dart` (apply list, hasUpdatedAt, parentRefs)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (field, ctor, toJson, fromJson, export registry, `_exportMediaSmartAlbums`, `_safeExport` call)
- Test: `test/features/media/data/media_smart_album_repository_test.dart`

**Interfaces:**
- Consumes: `MediaLibraryFilter.toJson/fromJson` (T7).
- Produces:

```dart
class MediaSmartAlbum {
  const MediaSmartAlbum({required this.id, required this.name,
      required this.filter, this.sortOrder = 0,
      required this.createdAt, required this.updatedAt});
  final MediaLibraryFilter filter;
}

class MediaSmartAlbumRepository {
  Future<List<MediaSmartAlbum>> getAll();          // sortOrder, then name
  Future<MediaSmartAlbum> create({required String name,
      required MediaLibraryFilter filter});        // uuid id, HLC pending
  Future<void> rename(String id, String name);
  Future<void> delete(String id);                  // + logDeletion tombstone
  Stream<void> watchChanges();
}
```

- [ ] **Step 1: Failing tests**

```dart
test('create stores the serialized filter and reads it back', () async {
  final album = await repo.create(name: 'Blue Hole videos',
      filter: const MediaLibraryFilter(siteId: 's1', mediaType: MediaType.video));
  final all = await repo.getAll();
  expect(all.single.id, album.id);
  expect(all.single.filter.siteId, 's1');
  expect(all.single.filter.mediaType, MediaType.video);
});
test('create marks the row pending for sync', () async {
  final album = await repo.create(name: 'x', filter: MediaLibraryFilter.none);
  final pending = await db.customSelect(
    "SELECT record_id FROM sync_records WHERE entity_type = 'mediaSmartAlbums'")
      .get();
  expect(pending.map((r) => r.read<String>('record_id')), contains(album.id));
});
test('delete removes the row and writes a tombstone', () async { ... });
test('rename updates the name and bumps updatedAt', () async { ... });
```

(If the pending-marker table/column names differ, assert through `SyncRepository` the way `test/features/media/data/media_reassign_test.dart` checks tombstones — copy that idiom.)

- [ ] **Step 2: FAIL run**, **Step 3: Implement** — repository mirrors `MediaRepository`'s create/update/delete shape (uuid ids, `markRecordPending(entityType: 'mediaSmartAlbums', ...)`, `logDeletion` on delete, `SyncEventBus.notifyLocalChange()`), then the 8 sync sites:

```dart
// sync_repository.dart entityTables:
'mediaSmartAlbums': (table: 'media_smart_albums', pk: 'id'),
// sync_service.dart hasUpdatedAt map:
'mediaSmartAlbums': true,
// sync_service.dart parentRefs: (no FK parents -> omit the entry entirely)
// sync_service.dart apply list (near the media entries):
(type: 'mediaSmartAlbums', records: data.mediaSmartAlbums, hasUpdatedAt: true),
// sync_data_serializer.dart: field + ctor param + toJson entry + fromJson
//   (_parseList(json['mediaSmartAlbums'])) + export registry entry
//   (key: 'mediaSmartAlbums', table: _db.mediaSmartAlbums, blob: false, full: null)
//   + helper:
  Future<List<Map<String, dynamic>>> _exportMediaSmartAlbums(
      String? hlcSince) async {
    final query = _db.select(_db.mediaSmartAlbums);
    if (hlcSince != null) query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
// + the _safeExport call in the changeset builder.
```

- [ ] **Step 4: PASS run** — `flutter test test/features/media/data/ test/core/services/sync/ --timeout 120s` (the sync suite has contract tests that enumerate registered entities; fix any expected-count assertion they carry).
- [ ] **Step 5: Commit** — "Add smart albums with sync registration"

---

### Task 9: Smart albums UI

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_library_filter_bar.dart` (a bookmark action: save the current filter as an album; a dropdown listing albums that applies one on tap)
- Create: `lib/features/media/presentation/providers/media_smart_album_providers.dart`
- Modify: l10n arbs + gen-l10n — `media_smartAlbum_save` "Save as album", `media_smartAlbum_saveTitle` "Name this album", `media_smartAlbum_albums` "Albums", `media_smartAlbum_delete` "Delete album", `media_smartAlbum_saved` "Album saved"
- Test: `test/features/media/presentation/media_smart_album_test.dart`

**Interfaces:**
- Consumes: `MediaSmartAlbumRepository` (T8), `mediaLibraryFilterProvider`.
- Produces: `mediaSmartAlbumsProvider` (`FutureProvider<List<MediaSmartAlbum>>`, invalidated by `watchChanges`), and the filter-bar controls.

- [ ] **Step 1: Failing tests** (save action opens a name dialog and calls `create` with the live filter; the albums menu lists names and applying one writes that filter to `mediaLibraryFilterProvider`; delete calls `delete`), **Step 2: FAIL run**, **Step 3: Implement**, **Step 4: PASS run** — `flutter test test/features/media/presentation/ --timeout 120s`.
- [ ] **Step 5: Commit** — "Add smart album save and apply controls"

---

### Task 10: Final sweep

- [ ] `dart format .` (no-op), `flutter analyze` (zero issues), `flutter test --timeout 120s` full suite. Known-flaky files to re-run in isolation before concluding regression: backup encryption suite, OCR scan page, upload drain, recovery-code yoyo. Re-verify the v143 claim against `git show origin/main:lib/core/database/database.dart | grep currentSchemaVersion` and renumber if main moved. Commit stragglers.

---

## Plan self-review notes (already applied)

- Spec coverage: watcher with exact-hash auto-apply and suggest-only setting (T4, T5), `watched_folder_index` on cache v9 (T1), `media_repair_log` per-device and pruned to 500 (T2, T3) with an audit view (T6), `media_smart_albums` synced as a serialized filter (T2, T7, T8, T9), per-source browsing (T5).
- Deviation recorded: the spec's "app start (at most once per day)" trigger has no host — the startup-maintenance runner was abandoned — so the automatic pass fires when the Media console builds (`MediaSectionPage`), gated by the same daily `shouldAutoScan` cadence, with "Scan now" always available. Same fire-and-forget shape as the store's opportunistic verify sweep.
- Type consistency: `WatchedFolderRepository`/`IndexedFile`, `RepairLogAction`/`RepairLogSource`/`RepairLogEntry`/`MediaRepairLogRepository`, `WatchedFolderScanner`/`shouldAutoScan`/`WatcherScanReport`, `MediaSmartAlbum`/`MediaSmartAlbumRepository`, `MediaConsoleSection.sources`, `countBySourceType` used consistently across tasks.
