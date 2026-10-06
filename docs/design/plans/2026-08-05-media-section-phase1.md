# Media Section Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the new top-level Media section: nav entry, adaptive console scaffold, paginated cross-dive library with three view modes, shared full-screen viewer, multi-select with Delete/Share, a Transfers view, and the v140 `retain_in_library` migration.

**Architecture:** A new `/media` shell route hosts `MediaSectionPage`, which wraps content in `MediaConsoleScaffold` (desktop sidebar, phone top tabs). A new `MediaLibraryRepository` provides keyset-paginated, filtered, cross-dive reads (Drift join of media + dives + dive_sites), consumed by a paged `StateNotifier`. Tiles reuse `MediaItemView`; the full-screen viewer is `PhotoViewerPage` generalized to take a media list instead of a dive id. Spec: `docs/superpowers/specs/2026-08-05-media-section-design.md`.

**Tech Stack:** Flutter 3.x, Drift, Riverpod (via `package:submersion/core/providers/provider.dart` barrel), go_router, intl.

## Global Constraints

- Work happens in the worktree `.claude/worktrees/media-section` on branch `worktree-media-section`. Run all commands from the worktree root; verify with `pwd` before trusting any command output.
- All commands below assume the worktree root as cwd. If a `flutter test` invocation is slow to start, that is normal (first build).
- `dart format .` must produce no changes before every commit (run it, then `git add` the result).
- `flutter analyze` treats infos as CI-fatal: zero new infos allowed.
- No emojis anywhere in code, comments, or docs.
- Every user-visible string is localized: add the key to `lib/l10n/arb/app_en.arb` AND every other `app_*.arb` in `lib/l10n/arb/` (10 non-English locales; translate, do not copy English), then run `flutter gen-l10n`. Commit the regenerated files.
- Riverpod imports come from the barrel `package:submersion/core/providers/provider.dart` — never import `flutter_riverpod` or legacy StateNotifier packages directly.
- Widget tests: pin `MaterialApp(locale: Locale('en'))` on any test host that renders localized strings; never touch Drift inside `FakeAsync`.
- New test FILES can silently abort the pre-push hook; that is a known repo trap. Pushes happen only at branch finish, not during this plan.
- Do not add Co-Authored-By lines to commit messages.
- After ANY edit to `lib/features/media/presentation/widgets/dive_media_section.dart` or shared media widgets, run the FULL test suite, not just the touched tests (provider-dependency changes break consumer tests that analyze cannot catch).
- Timestamps in the media table are epoch milliseconds stored as INTEGER; `takenAt` hydrates as UTC (`isUtc: true`) — display converts to local.

---

### Task 1: v140 migration — `media.retain_in_library`

The dormant column that Phase 2's link management consumes. Schema ladder: main is at v137; v138 is reserved by divelogs PR #603 and v139 is claimed by equipment currency PR #805 (neither on this branch), so this claims **v140** and our branch has NO v138 or v139 blocks. Before starting, re-verify against the ladder memory AND `git fetch origin && git show origin/main:lib/core/database/database.dart | grep "currentSchemaVersion = "` — if either shows v140 taken, renumber this task's claim to the next free number and adjust every "140" below.

**Files:**
- Modify: `lib/core/database/database.dart` (table def ~line 1245, `currentSchemaVersion` line 2864, `migrationVersions` list ~line 3032, onUpgrade tail ~line 7163, beforeOpen ~line 7183)
- Create: `test/core/database/migration_v140_retain_in_library_test.dart`
- Modify (generated): `lib/core/database/database.g.dart` via build_runner

**Interfaces:**
- Consumes: existing migration helper conventions (`_assertAccentColorSettingsColumns` at database.dart:3572 is the exact template).
- Produces: `Media.retainInLibrary` (Drift `BoolColumn`, default false) available as `MediaData.retainInLibrary`; `AppDatabase.currentSchemaVersion == 140`. No repository or entity exposes it yet (dormant until Phase 2).

- [ ] **Step 1: Write the failing migration test**

Copy `test/core/database/migration_v135_accent_columns_test.dart` to `test/core/database/migration_v140_retain_in_library_test.dart` and adapt it — keep that file's database-construction boilerplate verbatim and change the assertions to:

```dart
// Test bodies (keep the copied file's setup/teardown and DB construction):

test('currentSchemaVersion includes v140', () {
  expect(
    AppDatabase.currentSchemaVersion,
    greaterThanOrEqualTo(140),
  );
  expect(AppDatabase.migrationVersions, contains(140));
});

test('fresh database has media.retain_in_library', () async {
  // db = fresh in-memory AppDatabase from the copied boilerplate.
  final cols = await db
      .customSelect("PRAGMA table_info('media')")
      .get();
  final names = cols.map((c) => c.read<String>('name')).toSet();
  expect(names, contains('retain_in_library'));
});

test('retain_in_library defaults to 0 (false)', () async {
  final row = await db
      .customSelect(
        "SELECT dflt_value, [notnull] FROM pragma_table_info('media') "
        "WHERE name = 'retain_in_library'",
      )
      .getSingle();
  expect(row.read<String>('dflt_value'), '0');
  expect(row.read<int>('notnull'), 1);
});
```

Where the v135 template exercises the upgrade path with an old-version fixture, keep that structure and assert the same three things post-migration (column present, NOT NULL, default 0).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v140_retain_in_library_test.dart --timeout 120s`
Expected: FAIL — `migrationVersions` does not contain 140 and PRAGMA lacks the column.

- [ ] **Step 3: Implement the migration**

In `lib/core/database/database.dart`:

(a) Add the column to the `Media` table class, immediately before `IntColumn get createdAt` (line ~1246):

```dart
  // Media section Phase 1 (v140): kept-in-library marker. Dormant until the
  // Phase 2 link-management UI sets it; the orphan sweep will exclude rows
  // where it is true. Synced with the row like every other media column.
  BoolColumn get retainInLibrary =>
      boolean().withDefault(const Constant(false))();
```

(b) Bump the version constant (line 2864):

```dart
  static const int currentSchemaVersion = 140;
```

(c) Append to `migrationVersions` after `137,`:

```dart
    // 138 (divelogs #603) and 139 (equipment currency #805) are reserved by
    // parallel branches; no blocks here.
    140,
  ];
```

(d) Add the idempotent assert helper next to `_assertAccentColorSettingsColumns` (after line 3590):

```dart
  /// v140: media.retain_in_library (Media section Phase 1). Idempotent; safe
  /// to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertMediaRetainInLibraryColumn() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('retain_in_library')) {
      await customStatement(
        'ALTER TABLE media ADD COLUMN retain_in_library '
        'INTEGER NOT NULL DEFAULT 0 CHECK (retain_in_library IN (0, 1))',
      );
    }
  }
```

(e) Add the onUpgrade block after the `if (from < 137) await reportProgress();` line (~7163):

```dart
        // v140: media.retain_in_library (Media section Phase 1). v138
        // (divelogs) and v139 (equipment currency) live on parallel branches;
        // a DB arriving here from 137 skips straight to 140 and the
        // beforeOpen backstop self-heals any DB a parallel branch strands in
        // between.
        if (from < 140) {
          await _assertMediaRetainInLibraryColumn();
        }
        if (from < 140) await reportProgress();
```

(f) Add the beforeOpen backstop after the v137 backstop (`await _assertWeatherCodeColumn();`, line ~7183):

```dart
        // v140 backstop: re-assert media.retain_in_library.
        await _assertMediaRetainInLibraryColumn();
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes without errors; `database.g.dart` gains `retainInLibrary`.

- [ ] **Step 5: Run the migration test and the neighboring migration tests**

Run: `flutter test test/core/database/ --timeout 120s`
Expected: ALL PASS. If an older migration test asserts `currentSchemaVersion == 137` exactly (exact-latest tripwire), relax that assertion to `greaterThanOrEqualTo(137)` per repo convention — the newest migration owns exact-latest, and our new test deliberately uses `greaterThanOrEqualTo(140)` from the start.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -u lib/core/database/ test/core/database/migration_v140_retain_in_library_test.dart
git add test/core/database/migration_v140_retain_in_library_test.dart
git commit -m "Add v140 migration: media.retain_in_library column"
```

---

### Task 2: Media path performance indexes

`kPerformanceIndexes` is asserted idempotently on every open from beforeOpen (`database.dart:7390`), so this needs NO schema version bump.

**Files:**
- Modify: `lib/core/database/performance_indexes.dart` (after the `idx_media_origin_device` entry, ~line 247)
- Test: `test/core/database/performance_indexes_test.dart` (existing; no edits — its fresh-DB sweep validates new DDL automatically)

**Interfaces:**
- Produces: indexes `idx_media_local_path`, `idx_media_file_path`, `idx_media_is_orphaned` present on every opened DB; Task 4's queries and count badges rely on them.

- [ ] **Step 1: Add the three index entries**

After the `idx_media_origin_device` entry in `kPerformanceIndexes`:

```dart
  (
    name: 'idx_media_local_path',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_local_path '
        'ON media(local_path)',
  ),
  (
    name: 'idx_media_file_path',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_file_path '
        'ON media(file_path)',
  ),
  (
    name: 'idx_media_is_orphaned',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_is_orphaned '
        'ON media(is_orphaned)',
  ),
```

- [ ] **Step 2: Run the index test**

Run: `flutter test test/core/database/performance_indexes_test.dart --timeout 120s`
Expected: PASS (the fresh-DB test creates every index against the current schema; a typo in a column name fails here).

- [ ] **Step 3: Format and commit**

```bash
dart format .
git add lib/core/database/performance_indexes.dart
git commit -m "Add media path and orphan-flag performance indexes"
```

---

### Task 3: Extract the shared media row mapper

`MediaRepository._mapRowToMediaItem` (media_repository.dart:1306) is private; Task 4's new repository needs the identical mapping. Extract it rather than duplicate it.

**Files:**
- Create: `lib/features/media/data/repositories/media_row_mapper.dart`
- Modify: `lib/features/media/data/repositories/media_repository.dart` (replace the private method body with a delegation, keep the private name so no call sites change)
- Test: existing media repository tests (`test/features/media/`) prove behavior is unchanged

**Interfaces:**
- Produces: top-level function
  `MediaItem mediaItemFromRow(MediaData row, MediaEnrichmentData? enrichmentRow)`
  in `media_row_mapper.dart` (import alias conventions: it returns the domain `MediaItem`). Task 4 consumes this.

- [ ] **Step 1: Create the mapper file**

Move the entire body of `_mapRowToMediaItem` into the new file as a top-level function with the same parameter and return types (copy the imports it needs from media_repository.dart — the domain entity import uses `as domain` there; in the new file import the domain entity directly and return `MediaItem`):

```dart
// lib/features/media/data/repositories/media_row_mapper.dart
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// Maps a Drift media row (plus optional enrichment row) to the domain
/// [MediaItem]. Shared by MediaRepository and MediaLibraryRepository so the
/// two can never drift apart on hydration rules (takenAt is UTC, source type
/// parsing, enrichment merge).
MediaItem mediaItemFromRow(MediaData row, MediaEnrichmentData? enrichmentRow) {
  // BODY: moved verbatim from MediaRepository._mapRowToMediaItem
  // (media_repository.dart:1306). Do not change any logic in the move.
}
```

- [ ] **Step 2: Delegate from MediaRepository**

Replace `_mapRowToMediaItem`'s body with a delegation (keep the private method so its ~8 call sites are untouched):

```dart
  domain.MediaItem _mapRowToMediaItem(
    MediaData row, [
    MediaEnrichmentData? enrichmentRow,
  ]) => mediaItemFromRow(row, enrichmentRow);
```

Match the existing parameter shape exactly (check whether the enrichment parameter is positional-optional or required at line 1306 and mirror it).

- [ ] **Step 3: Run the media test suite**

Run: `flutter test test/features/media/ --timeout 120s`
Expected: ALL PASS — pure refactor, zero behavior change.

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add lib/features/media/data/repositories/
git commit -m "Extract shared media row mapper"
```

---

### Task 4: MediaLibraryFilter + MediaLibraryRepository (keyset pagination)

The cross-dive query layer. Filters compile to Drift expressions; pagination is keyset on `COALESCE(taken_at, created_at) DESC, id DESC`.

**Files:**
- Create: `lib/features/media/domain/entities/media_library_filter.dart`
- Create: `lib/features/media/data/repositories/media_library_repository.dart`
- Test: `test/features/media/data/media_library_repository_test.dart`

**Interfaces:**
- Consumes: `mediaItemFromRow` (Task 3); Drift tables `media`, `dives`, `diveSites`.
- Produces (Tasks 7-9 rely on these exact names):

```dart
enum MediaHealthFilter { missing, unlinked }

class MediaLibraryFilter {
  const MediaLibraryFilter({
    this.mediaType,          // MediaType? (photo | video)
    this.siteId,             // String?
    this.tripId,             // String?
    this.diveId,             // String?
    this.fromDate,           // DateTime? inclusive, on sort key
    this.toDate,             // DateTime? inclusive, on sort key
    this.sourceType,         // MediaSourceType?
    this.health,             // MediaHealthFilter?
  });
  MediaLibraryFilter copyWith(...);   // standard nullable-preserving copyWith
  static const MediaLibraryFilter none = MediaLibraryFilter();
}

class MediaLibraryCursor {
  const MediaLibraryCursor({required this.sortKey, required this.id});
  final int sortKey;  // epoch ms of COALESCE(taken_at, created_at)
  final String id;
}

class MediaLibraryEntry {
  const MediaLibraryEntry({
    required this.item,       // MediaItem
    this.diveNumber,          // int? from dives.dive_number
    this.diveDateTime,        // DateTime? from dives.dive_date_time
    this.siteName,            // String? from dive_sites.name
  });
}

class MediaLibraryPageResult {
  const MediaLibraryPageResult({required this.entries, this.nextCursor});
  final List<MediaLibraryEntry> entries;
  final MediaLibraryCursor? nextCursor;  // null == last page
}

class MediaLibraryRepository {
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    MediaLibraryCursor? after,
    int limit = 60,
  });
  Future<int> countUnlinked();
  Future<int> countMissing();
  Stream<void> watchMediaChanges();
}
```

- [ ] **Step 1: Write the failing repository tests**

Test file skeleton — construct the in-memory DB the same way `test/features/media/` repository tests do (copy their setUp; they go through `DatabaseService.instance` with an in-memory override). Seed: two dives for diver `d1` (numbers 1 and 2, different dates), one dive for diver `d2`, a site named `Blue Hole` on dive 1; media rows: 3 photos on dive 1 (distinct `takenAt` values), 1 video on dive 2, 1 photo on the `d2` dive, 1 unlinked photo (`diveId` null, `siteId` null, sourceType `localFile`), 1 unlinked `networkUrl` row, 1 orphaned photo (`isOrphaned: true`) on dive 1, and 1 signature row (`fileType: 'instructor_signature'`) on dive 1. Insert epoch-ms timestamps directly.

```dart
group('MediaLibraryRepository.getPage', () {
  test('excludes signatures and other divers, includes unlinked', () async {
    final page = await repo.getPage(diverId: 'd1');
    final ids = page.entries.map((e) => e.item.id).toList();
    expect(ids, isNot(contains('sig-1')));
    expect(ids, isNot(contains('other-diver-photo')));
    expect(ids, contains('unlinked-1'));
    expect(ids, contains('unlinked-url-1'));
  });

  test('orders by COALESCE(taken_at, created_at) DESC then id DESC',
      () async {
    final page = await repo.getPage(diverId: 'd1');
    final keys = page.entries
        .map((e) =>
            (e.item.takenAt ?? e.item.createdAt).millisecondsSinceEpoch)
        .toList();
    final sorted = [...keys]..sort((a, b) => b.compareTo(a));
    expect(keys, sorted);
  });

  test('keyset pagination walks the full set without gaps or repeats',
      () async {
    final first = await repo.getPage(diverId: 'd1', limit: 3);
    expect(first.entries, hasLength(3));
    expect(first.nextCursor, isNotNull);
    final second =
        await repo.getPage(diverId: 'd1', after: first.nextCursor, limit: 50);
    final all = {...first.entries.map((e) => e.item.id),
                 ...second.entries.map((e) => e.item.id)};
    expect(all.length,
        first.entries.length + second.entries.length); // no repeats
    expect(second.nextCursor, isNull); // exhausted
  });

  test('mediaType, health, and dive filters compile correctly', () async {
    final videos = await repo.getPage(
        diverId: 'd1',
        filter: const MediaLibraryFilter(mediaType: MediaType.video));
    expect(videos.entries.every((e) => e.item.fileType == MediaType.video),
        isTrue);

    final missing = await repo.getPage(
        diverId: 'd1',
        filter:
            const MediaLibraryFilter(health: MediaHealthFilter.missing));
    expect(missing.entries.map((e) => e.item.id), ['orphaned-1']);

    final unlinked = await repo.getPage(
        diverId: 'd1',
        filter:
            const MediaLibraryFilter(health: MediaHealthFilter.unlinked));
    // networkUrl/manifestEntry are library-level sources: NOT "unlinked".
    expect(unlinked.entries.map((e) => e.item.id), ['unlinked-1']);
  });

  test('joins dive header fields', () async {
    final page = await repo.getPage(diverId: 'd1');
    final onDive1 = page.entries
        .firstWhere((e) => e.item.diveId == 'dive-1');
    expect(onDive1.diveNumber, 1);
    expect(onDive1.siteName, 'Blue Hole');
  });
});

group('counts', () {
  test('countUnlinked excludes library-level sources and signatures',
      () async {
    expect(await repo.countUnlinked(), 1);
  });
  test('countMissing counts is_orphaned rows', () async {
    expect(await repo.countMissing(), 1);
  });
});
```

Adjust the exact `MediaType`/`fileType` accessor names on `MediaItem` to what `media_item.dart` exposes (open it; the entity mirrors every column).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/data/media_library_repository_test.dart --timeout 120s`
Expected: FAIL — types do not exist.

- [ ] **Step 3: Implement filter entity and repository**

`media_library_filter.dart` per the Interfaces block (plain immutable class + enum + cursor + entry + page result — no JSON yet; smart albums serialize in Phase 5).

`media_library_repository.dart` core query (follow `getRecentPhotos` at media_repository.dart:82 for style — `AppDatabase get _db => DatabaseService.instance.database;`, try/catch with `LoggerService`, rethrow):

```dart
Future<MediaLibraryPageResult> getPage({
  required String? diverId,
  MediaLibraryFilter filter = MediaLibraryFilter.none,
  MediaLibraryCursor? after,
  int limit = 60,
}) async {
  final m = _db.media;
  final d = _db.dives;
  final s = _db.diveSites;
  final sortKey = coalesce<int>([m.takenAt, m.createdAt]);

  Expression<bool> where =
      m.fileType.equals('instructor_signature').not();
  if (diverId != null) {
    where = where & (m.diveId.isNull() | d.diverId.equals(diverId));
  }
  final type = filter.mediaType;
  if (type != null) {
    where = where & m.fileType.equals(_mediaTypeString(type));
  }
  if (filter.diveId != null) where = where & m.diveId.equals(filter.diveId!);
  if (filter.siteId != null) {
    where = where &
        (d.siteId.equals(filter.siteId!) | m.siteId.equals(filter.siteId!));
  }
  if (filter.tripId != null) where = where & d.tripId.equals(filter.tripId!);
  if (filter.fromDate != null) {
    where = where &
        sortKey.isBiggerOrEqualValue(
            filter.fromDate!.millisecondsSinceEpoch);
  }
  if (filter.toDate != null) {
    where = where &
        sortKey.isSmallerOrEqualValue(filter.toDate!.millisecondsSinceEpoch);
  }
  if (filter.sourceType != null) {
    where = where & m.sourceType.equals(filter.sourceType!.name);
  }
  switch (filter.health) {
    case MediaHealthFilter.missing:
      where = where & m.isOrphaned.equals(true);
    case MediaHealthFilter.unlinked:
      where = where &
          m.diveId.isNull() &
          m.siteId.isNull() &
          m.sourceType.isNotIn(kLibraryLevelSourceTypes);
    case null:
      break;
  }
  if (after != null) {
    where = where &
        (sortKey.isSmallerThanValue(after.sortKey) |
            (sortKey.equalsExp(Variable(after.sortKey)) &
                m.id.isSmallerThanValue(after.id)));
  }

  final query = _db.select(m).join([
    leftOuterJoin(d, d.id.equalsExp(m.diveId)),
    leftOuterJoin(s, s.id.equalsExp(d.siteId)),
  ])
    ..where(where)
    ..orderBy([OrderingTerm.desc(sortKey), OrderingTerm.desc(m.id)])
    ..limit(limit + 1); // one extra row detects "has next page"

  final rows = await query.get();
  final hasMore = rows.length > limit;
  final visible = hasMore ? rows.sublist(0, limit) : rows;
  final entries = visible.map((row) {
    final mediaRow = row.readTable(m);
    final diveRow = row.readTableOrNull(d);
    final siteRow = row.readTableOrNull(s);
    return MediaLibraryEntry(
      item: mediaItemFromRow(mediaRow, null),
      diveNumber: diveRow?.diveNumber,
      diveDateTime: diveRow == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(diveRow.diveDateTime),
      siteName: siteRow?.name,
    );
  }).toList();

  MediaLibraryCursor? next;
  if (hasMore && entries.isNotEmpty) {
    final last = visible.last.readTable(m);
    next = MediaLibraryCursor(
      sortKey: last.takenAt ?? last.createdAt,
      id: last.id,
    );
  }
  return MediaLibraryPageResult(entries: entries, nextCursor: next);
}
```

Notes for the implementer:
- `kLibraryLevelSourceTypes` — define `const kLibraryLevelSourceTypes = ['networkUrl', 'manifestEntry'];` in this file. MediaRepository has a private copy (`libraryLevelSourceTypes` at media_repository.dart:989); leave that one alone in this task.
- `coalesce` is `package:drift/drift.dart`'s function helper. If `equalsExp(Variable(...))` reads awkwardly, `sortKey.equals(after.sortKey)` compiles for `Expression<int>` in current Drift — use whichever the analyzer accepts.
- Field-name checks: `diveRow.diveNumber`, `diveRow.diveDateTime`, `siteRow.name` — confirm exact generated names in `database.g.dart` (the dives table column is `dive_date_time`; entity field checked in Dive domain at dive.dart:20 `diveNumber`).
- Dive detail hydrates enrichment; the library passes `null` enrichment deliberately (lean hydration for grids, same reasoning as the dive-list lean pattern).

Counts and change stream:

```dart
Future<int> countUnlinked() async {
  final m = _db.media;
  final count = countAll(
    filter: m.diveId.isNull() &
        m.siteId.isNull() &
        m.fileType.equals('instructor_signature').not() &
        m.sourceType.isNotIn(kLibraryLevelSourceTypes),
  );
  final row = await (_db.selectOnly(m)..addColumns([count])).getSingle();
  return row.read(count) ?? 0;
}

Future<int> countMissing() async {
  final m = _db.media;
  final count = countAll(filter: m.isOrphaned.equals(true));
  final row = await (_db.selectOnly(m)..addColumns([count])).getSingle();
  return row.read(count) ?? 0;
}

Stream<void> watchMediaChanges() {
  final m = _db.media;
  final count = countAll();
  return (_db.selectOnly(m)..addColumns([count]))
      .watchSingle()
      .map((_) {});
}
```

`_mediaTypeString(MediaType t)` maps photo -> `'photo'`, video -> `'video'` (mirror MediaRepository's private `_mediaTypeToString`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/data/media_library_repository_test.dart --timeout 120s`
Expected: ALL PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/domain/entities/media_library_filter.dart \
        lib/features/media/data/repositories/media_library_repository.dart \
        test/features/media/data/media_library_repository_test.dart
git commit -m "Add MediaLibraryRepository with keyset pagination and filters"
```

---

### Task 5: Nav destination, route, accent colors, l10n

**Files:**
- Modify: `lib/shared/widgets/nav/nav_destinations.dart` (insert after `trips`, line ~71)
- Modify: `lib/core/router/app_router.dart` (new GoRoute under the ShellRoute)
- Modify: `lib/core/theme/feature_accent_colors.dart` (both palettes)
- Create: `lib/features/media/presentation/pages/media_section_page.dart` (placeholder body; console arrives in Task 6)
- Modify: `lib/l10n/arb/app_en.arb` + all 10 other `app_*.arb` + `flutter gen-l10n`
- Modify tests: `test/shared/widgets/nav/nav_destinations_test.dart`, `test/shared/widgets/nav/rail_destination_order_test.dart` (feature_accent_colors_test needs no edit — it iterates the catalog)

**Interfaces:**
- Produces: nav id `'media'`, route `/media`, l10n key `nav_media`, accent entries `'media'` in both palettes; `MediaSectionPage` widget (Task 6 replaces its body).

- [ ] **Step 1: Update the nav tests to expect the new destination (failing first)**

`nav_destinations_test.dart`: change `15` to `16` (line 7), and in the expected-ids list insert `'media'` after `'trips'` (line 33/34). In the `movableNavIds` group: insert `'media'` after `'trips'` and change `13` to `14` (line 82).
`rail_destination_order_test.dart`: insert `('media', '/media'),` after `('trips', '/trips'),`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/shared/widgets/nav/ --timeout 120s`
Expected: FAIL — catalog has no `media` entry.

- [ ] **Step 3: Implement**

(a) `nav_destinations.dart` — insert after the `trips` entry:

```dart
  NavDestination(
    id: 'media',
    route: '/media',
    icon: Icons.photo_library_outlined,
    selectedIcon: Icons.photo_library,
    label: (l10n) => l10n.nav_media,
  ),
```

(b) `feature_accent_colors.dart` — add to the light map after `'trips'`:

```dart
      'media': Color(0xFF6A1B9A),
```

and to the dark map after `'trips'`:

```dart
      'media': Color(0xFFCE93D8),
```

(purple 800 / purple 200 — related to but distinguishable from trips' 700/300; the accent test only requires presence and both entries clear the 3:1 contrast note that governs the light palette).

(c) `app_en.arb` — add alphabetically among the `nav_` keys:

```json
  "nav_media": "Media",
```

plus the matching `"@nav_media": {"description": "Media section nav label"}` metadata entry where the other `@nav_` entries live. Then add translated `nav_media` to every other `app_*.arb` in `lib/l10n/arb/` (list them with `ls lib/l10n/arb/app_*.arb`; translate "Media" per locale — most Latin-script locales keep "Media"; use the locale's conventional word for a media library, e.g. Japanese uses katakana). Run `flutter gen-l10n`.

(d) `media_section_page.dart` — placeholder page:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Top-level Media section host. Task 6 replaces the body with
/// MediaConsoleScaffold; this placeholder just makes /media routable.
class MediaSectionPage extends StatelessWidget {
  const MediaSectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.nav_media)),
      body: const SizedBox.shrink(),
    );
  }
}
```

(e) `app_router.dart` — add under the ShellRoute children, after the trips route block:

```dart
          // Media section (DAM console)
          GoRoute(
            path: '/media',
            name: 'media',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const MediaSectionPage(),
            ),
          ),
```

plus the import for `media_section_page.dart` grouped with the other feature page imports.

- [ ] **Step 4: Run nav, theme, and router tests**

Run: `flutter test test/shared/widgets/nav/ test/core/theme/ --timeout 120s`
Expected: ALL PASS (accent test now iterates 15 routable ids and finds `media` in both palettes).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib/shared/widgets/nav/ lib/core/router/ lib/core/theme/ \
        lib/features/media/presentation/pages/media_section_page.dart \
        lib/l10n/ test/shared/widgets/nav/
git commit -m "Add Media top-level nav destination and /media route"
```

(`git add -A` is scoped to listed paths only — never bare `git add -A`, which can pick up a stale submodule pointer in this repo.)

---

### Task 6: MediaConsoleScaffold (adaptive sidebar / tabs)

**Files:**
- Create: `lib/shared/widgets/nav/media_console_scaffold.dart` — no; console is media-feature-local. Create: `lib/features/media/presentation/widgets/media_console_scaffold.dart`
- Modify: `lib/features/media/presentation/pages/media_section_page.dart`
- Modify: l10n arbs (`media_console_library`, `media_console_transfers`) + gen-l10n
- Test: `test/features/media/presentation/media_console_scaffold_test.dart`

**Interfaces:**
- Produces:

```dart
enum MediaConsoleSection { library, transfers }

class MediaConsoleScaffold extends StatelessWidget {
  const MediaConsoleScaffold({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.child,
    this.badgeCounts = const {},   // MediaConsoleSection -> int, 0 hides
  });
}
```

Phase 2+ adds `unlinked`/`missing`/`importMedia` enum values; the widget renders whatever the enum contains, so later phases only grow the enum and the section registry inside `MediaSectionPage`.

- [ ] **Step 1: Write failing widget tests**

```dart
Widget host(double width, MediaConsoleSection selected,
    void Function(MediaConsoleSection) onSelect) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: MediaConsoleScaffold(
        selected: selected,
        onSelect: onSelect,
        child: const Text('CONTENT'),
      ),
    ),
  );
}

testWidgets('wide layout shows sidebar entries', (tester) async {
  await tester.pumpWidget(
      host(1100, MediaConsoleSection.library, (_) {}));
  expect(find.text('Library'), findsOneWidget);
  expect(find.text('Transfers'), findsOneWidget);
  expect(find.byType(TabBar), findsNothing);
  expect(find.text('CONTENT'), findsOneWidget);
});

testWidgets('narrow layout shows tabs instead of sidebar', (tester) async {
  await tester.pumpWidget(
      host(500, MediaConsoleSection.library, (_) {}));
  expect(find.byType(TabBar), findsOneWidget);
});

testWidgets('tapping an entry fires onSelect', (tester) async {
  MediaConsoleSection? tapped;
  await tester.pumpWidget(
      host(1100, MediaConsoleSection.library, (s) => tapped = s));
  await tester.tap(find.text('Transfers'));
  expect(tapped, MediaConsoleSection.transfers);
});
```

Use `tester.view.physicalSize`/`devicePixelRatio` overrides if the MediaQuery wrapper fights the test binding (repo widget tests use both idioms; pick the one neighboring media widget tests use).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/media_console_scaffold_test.dart --timeout 120s`
Expected: FAIL — widget does not exist.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum MediaConsoleSection { library, transfers }

/// Internal navigation for the Media section: a left sidebar on wide
/// layouts, top tabs on narrow ones. Mirrors MainScaffold's rail/bar split
/// one level down. The 720px threshold keeps the sidebar off phone-landscape
/// widths where the app shell already spends horizontal space on its rail.
class MediaConsoleScaffold extends StatelessWidget {
  const MediaConsoleScaffold({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.child,
    this.badgeCounts = const {},
  });

  final MediaConsoleSection selected;
  final ValueChanged<MediaConsoleSection> onSelect;
  final Widget child;
  final Map<MediaConsoleSection, int> badgeCounts;

  static const double _sidebarBreakpoint = 720;

  String _label(AppLocalizations l10n, MediaConsoleSection section) {
    return switch (section) {
      MediaConsoleSection.library => l10n.media_console_library,
      MediaConsoleSection.transfers => l10n.media_console_transfers,
    };
  }

  IconData _icon(MediaConsoleSection section) {
    return switch (section) {
      MediaConsoleSection.library => Icons.photo_library_outlined,
      MediaConsoleSection.transfers => Icons.swap_vert,
    };
  }

  Widget _badge(BuildContext context, MediaConsoleSection section,
      Widget iconWidget) {
    final count = badgeCounts[section] ?? 0;
    if (count == 0) return iconWidget;
    return Badge.count(count: count, child: iconWidget);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _sidebarBreakpoint;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 200,
                child: ListView(
                  children: [
                    for (final section in MediaConsoleSection.values)
                      ListTile(
                        selected: section == selected,
                        leading: _badge(
                          context,
                          section,
                          Icon(_icon(section)),
                        ),
                        title: Text(_label(context.l10n, section)),
                        onTap: () => onSelect(section),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: child),
            ],
          );
        }
        return Column(
          children: [
            Material(
              child: TabBar(
                controller: null,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                onTap: (i) => onSelect(MediaConsoleSection.values[i]),
                tabs: [
                  for (final section in MediaConsoleSection.values)
                    Tab(
                      child: _badge(
                        context,
                        section,
                        Text(_label(context.l10n, section)),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
```

Note: a `TabBar` requires a `TabController`; wrap the narrow branch in `DefaultTabController(length: MediaConsoleSection.values.length, initialIndex: selected.index, child: ...)`. Keep selection authoritative from `selected` (rebuild recreates the controller at the right index).

Update `MediaSectionPage` to hold the selected section and render the console:

```dart
class MediaSectionPage extends StatefulWidget {
  const MediaSectionPage({super.key});
  @override
  State<MediaSectionPage> createState() => _MediaSectionPageState();
}

class _MediaSectionPageState extends State<MediaSectionPage> {
  MediaConsoleSection _section = MediaConsoleSection.library;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.nav_media)),
      body: MediaConsoleScaffold(
        selected: _section,
        onSelect: (s) => setState(() => _section = s),
        child: switch (_section) {
          MediaConsoleSection.library => const SizedBox.shrink(),
          MediaConsoleSection.transfers => const SizedBox.shrink(),
        },
      ),
    );
  }
}
```

New arb keys (all 11 locales + gen-l10n): `media_console_library` "Library", `media_console_transfers` "Transfers".

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/media/presentation/media_console_scaffold_test.dart --timeout 120s`
Expected: ALL PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/ lib/l10n/ \
        test/features/media/presentation/media_console_scaffold_test.dart
git commit -m "Add adaptive MediaConsoleScaffold and section host"
```

---

### Task 7: Library providers — view mode setting and paged notifier

**Files:**
- Create: `lib/features/media/presentation/providers/media_library_providers.dart`
- Test: `test/features/media/presentation/media_library_providers_test.dart`

**Interfaces:**
- Consumes: `MediaLibraryRepository` (Task 4), `currentDiverIdProvider` (from `package:submersion/features/divers/presentation/providers/diver_providers.dart`), `AppSettingsRepository.getRawSetting/setRawSetting`.
- Produces (Tasks 8-9, 11 rely on these):

```dart
enum MediaLibraryViewMode { grid, byDive, timeline }

final mediaLibraryRepositoryProvider = Provider<MediaLibraryRepository>(...);
final mediaLibraryViewModeProvider =
    StateNotifierProvider<MediaLibraryViewModeNotifier, MediaLibraryViewMode>;
      // persists via AppSettingsRepository key 'media_library_view_mode'
final mediaLibraryFilterProvider = StateProvider<MediaLibraryFilter>;
final mediaLibraryNotifierProvider =
    StateNotifierProvider<MediaLibraryNotifier, MediaLibraryState>;
final unlinkedCountProvider = FutureProvider<int>;
final missingCountProvider = FutureProvider<int>;

class MediaLibraryState {
  const MediaLibraryState({
    this.entries = const [],
    this.nextCursor,
    this.isLoading = false,      // first page in flight
    this.isLoadingMore = false,  // subsequent page in flight
    this.error,                  // Object? from the last failed load
  });
}

class MediaLibraryNotifier extends StateNotifier<MediaLibraryState> {
  Future<void> loadFirstPage();
  Future<void> loadMore();   // no-op when nextCursor == null or already loading
}
```

- [ ] **Step 1: Write failing provider tests**

Use `ProviderContainer` with the repository overridden by a fake:

```dart
class _FakeLibraryRepo implements MediaLibraryRepository {
  int pageCalls = 0;
  @override
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    MediaLibraryCursor? after,
    int limit = 60,
  }) async {
    pageCalls++;
    if (after == null) {
      return MediaLibraryPageResult(
        entries: [entry('a'), entry('b')],
        nextCursor: const MediaLibraryCursor(sortKey: 100, id: 'b'),
      );
    }
    return MediaLibraryPageResult(entries: [entry('c')]);
  }
  // countUnlinked/countMissing return fixed numbers; watchMediaChanges
  // returns a StreamController's stream the test can pump.
}

test('loadFirstPage then loadMore accumulates entries', () async {
  final notifier = container.read(mediaLibraryNotifierProvider.notifier);
  await notifier.loadFirstPage();
  expect(container.read(mediaLibraryNotifierProvider).entries, hasLength(2));
  await notifier.loadMore();
  final state = container.read(mediaLibraryNotifierProvider);
  expect(state.entries, hasLength(3));
  expect(state.nextCursor, isNull);
});

test('loadMore is a no-op at end of data', () async { ... });

test('changing the filter resets and reloads page one', () async {
  await container.read(mediaLibraryNotifierProvider.notifier).loadFirstPage();
  container.read(mediaLibraryFilterProvider.notifier).state =
      const MediaLibraryFilter(mediaType: MediaType.video);
  await container.pump(); // let the notifier react
  expect(fakeRepo.lastFilter?.mediaType, MediaType.video);
});

test('media change stream triggers refresh preserving filter', () async {
  await container.read(mediaLibraryNotifierProvider.notifier).loadFirstPage();
  fakeRepo.changes.add(null);
  await container.pump();
  expect(fakeRepo.pageCalls, greaterThanOrEqualTo(2));
});

test('view mode persists through AppSettingsRepository', () async { ... });
```

Do not run provider `Future`s under `FakeAsync` (repo trap: stalls forever).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/media_library_providers_test.dart --timeout 120s`
Expected: FAIL.

- [ ] **Step 3: Implement**

Implementation notes (follow `media_providers.dart` idioms — same barrel import, StateNotifier family style):

```dart
class MediaLibraryNotifier extends StateNotifier<MediaLibraryState> {
  MediaLibraryNotifier(this._repo, this._diverId, this._filter)
      : super(const MediaLibraryState()) {
    _changesSub = _repo.watchMediaChanges().listen((_) => loadFirstPage());
    loadFirstPage();
  }

  final MediaLibraryRepository _repo;
  final String? _diverId;
  final MediaLibraryFilter _filter;
  StreamSubscription<void>? _changesSub;

  Future<void> loadFirstPage() async {
    state = MediaLibraryState(isLoading: true);
    try {
      final page = await _repo.getPage(diverId: _diverId, filter: _filter);
      if (!mounted) return;
      state = MediaLibraryState(
        entries: page.entries,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      if (!mounted) return;
      state = MediaLibraryState(error: e);
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.getPage(
        diverId: _diverId,
        filter: _filter,
        after: cursor,
      );
      if (!mounted) return;
      state = MediaLibraryState(
        entries: [...state.entries, ...page.entries],
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    super.dispose();
  }
}

final mediaLibraryNotifierProvider =
    StateNotifierProvider<MediaLibraryNotifier, MediaLibraryState>((ref) {
  final repo = ref.watch(mediaLibraryRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(mediaLibraryFilterProvider);
  return MediaLibraryNotifier(repo, diverId, filter);
});
```

Watching `mediaLibraryFilterProvider` in the provider body means a filter change rebuilds the notifier — that IS the "reset and reload" path (deliberately coarse per spec; no per-row invalidation). `MediaLibraryState.copyWith` is a standard implementation. View mode notifier reads `getRawSetting('media_library_view_mode')` at construction (async prime, defaulting to grid) and writes through on change. Count providers call the repository and are invalidated by the same `watchMediaChanges` stream via `ref.invalidateSelfWhen(repo.watchMediaChanges())` (idiom from statistics_providers.dart:28).

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/media/presentation/media_library_providers_test.dart --timeout 120s`
Expected: ALL PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/providers/media_library_providers.dart \
        test/features/media/presentation/media_library_providers_test.dart
git commit -m "Add media library paged notifier and view mode providers"
```

---

### Task 8: Library grid view with infinite scroll

**Files:**
- Create: `lib/features/media/presentation/widgets/media_library_grid.dart`
- Create: `lib/features/media/presentation/pages/media_library_view.dart` (the Library section content: filter bar + view-mode switcher shell + grid)
- Modify: `lib/features/media/presentation/pages/media_section_page.dart` (library section renders `MediaLibraryView`)
- Modify: l10n arbs (`media_library_empty`, `media_library_filter_all`, `media_library_filter_photos`, `media_library_filter_videos`) + gen-l10n
- Test: `test/features/media/presentation/media_library_grid_test.dart`

**Interfaces:**
- Consumes: `mediaLibraryNotifierProvider`, `mediaLibraryFilterProvider`, `MediaItemView` (existing universal tile at `lib/features/media/presentation/widgets/media_item_view.dart` — open it for its constructor before wiring; it takes the `MediaItem` plus sizing/fit parameters).
- Produces: `MediaLibraryGrid` (scrollable sliver grid over `MediaLibraryState.entries`, `onTileTap(MediaLibraryEntry)` callback, fires `loadMore()` near the end); `MediaLibraryView` hosting filter chips + the active view mode.

- [ ] **Step 1: Write failing widget tests**

Override `mediaLibraryNotifierProvider` with a test notifier seeded with N entries (build `MediaLibraryEntry` fixtures around minimal `MediaItem` values; `MediaItemView` in tests renders placeholders for unresolvable sources, which is fine — assert on tile count, not pixels):

```dart
testWidgets('renders one tile per entry', (tester) async { ... });

testWidgets('shows localized empty state when no entries', (tester) async {
  // seed empty state; expect find.text('No media yet')
});

testWidgets('scrolling near the end calls loadMore', (tester) async {
  // seed 60 entries with nextCursor != null; drag to bottom;
  // assert the test notifier recorded a loadMore call
});

testWidgets('type filter chips update mediaLibraryFilterProvider',
    (tester) async {
  // tap 'Videos' chip; read container's filter; expect mediaType == video
});
```

Host with `MaterialApp(locale: Locale('en'), ...)` and `ProviderScope(overrides: [...])`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/media_library_grid_test.dart --timeout 120s`
Expected: FAIL.

- [ ] **Step 3: Implement**

`MediaLibraryGrid`:

```dart
class MediaLibraryGrid extends ConsumerWidget {
  const MediaLibraryGrid({
    super.key,
    required this.entries,
    required this.hasMore,
    required this.onLoadMore,
    required this.onTileTap,
  });

  final List<MediaLibraryEntry> entries;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final void Function(MediaLibraryEntry entry, int index) onTileTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (hasMore &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
          onLoadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return GestureDetector(
            onTap: () => onTileTap(entry, index),
            child: MediaItemView(
              item: entry.item,
              // match MediaItemView's actual constructor: thumbnail sizing
              // parameters as used by dive_media_section.dart's grid tiles —
              // copy that call site's argument list.
            ),
          );
        },
      ),
    );
  }
}
```

`MediaLibraryView` composes: a filter chip row (All / Photos / Videos writing `mediaLibraryFilterProvider`), the view-mode `SegmentedButton` placeholder (single `grid` segment until Task 9 adds the others), and the body switching on `mediaLibraryViewModeProvider`. Empty state: centered `Text(context.l10n.media_library_empty)` when `entries.isEmpty && !isLoading`. Wire `onTileTap` to a no-op for now (Task 10 pushes the viewer).

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/media/presentation/media_library_grid_test.dart --timeout 120s`
Expected: ALL PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/ lib/l10n/ \
        test/features/media/presentation/media_library_grid_test.dart
git commit -m "Add media library grid view with infinite scroll"
```

---

### Task 9: By-dive and timeline view modes

**Files:**
- Create: `lib/features/media/presentation/widgets/media_library_groupers.dart` (pure grouping functions)
- Create: `lib/features/media/presentation/widgets/media_library_grouped_list.dart` (renders grouped sections; shared by both modes)
- Modify: `lib/features/media/presentation/pages/media_library_view.dart` (full 3-mode `SegmentedButton`)
- Modify: l10n arbs (`media_library_viewMode_grid` "Grid", `media_library_viewMode_byDive` "By dive", `media_library_viewMode_timeline` "Timeline", `media_library_unlinkedHeader` "Unlinked", `media_library_diveHeader` "#{number} {site}" with placeholders) + gen-l10n
- Test: `test/features/media/presentation/media_library_groupers_test.dart`, plus mode-switch cases in `media_library_grid_test.dart`'s host

**Interfaces:**
- Consumes: `MediaLibraryEntry` (Task 4), view mode provider (Task 7).
- Produces (pure functions, unit-testable without widgets):

```dart
class MediaLibraryGroup {
  const MediaLibraryGroup({required this.header, required this.entries});
  final MediaLibraryGroupHeader header;
  final List<MediaLibraryEntry> entries;
}

sealed class MediaLibraryGroupHeader {}
class DiveGroupHeader extends MediaLibraryGroupHeader {
  DiveGroupHeader({this.diveId, this.diveNumber, this.siteName,
      this.diveDateTime}); // diveId == null -> the pinned Unlinked group
}
class DateGroupHeader extends MediaLibraryGroupHeader {
  DateGroupHeader({required this.monthStart, this.dayStart});
}

List<MediaLibraryGroup> groupByDive(List<MediaLibraryEntry> entries);
List<MediaLibraryGroup> groupByTimeline(List<MediaLibraryEntry> entries);
```

- [ ] **Step 1: Write failing grouper unit tests**

Hand-computed vectors (per repo practice — derive expectations by hand, not from the implementation):

```dart
test('groupByDive keeps stream order, groups runs by diveId, '
    'and appends unlinked last', () {
  // entries (already sorted newest-first by the query):
  //   e1(dive A), e2(dive A), e3(dive B), e4(no dive), e5(dive A)
  final groups = groupByDive([e1, e2, e3, e4, e5]);
  // dive A appears twice? NO: groupByDive groups by diveId across the whole
  // page (map-of-lists preserving first-seen order), so:
  //   [A: e1,e2,e5], [B: e3], [Unlinked: e4]
  expect(groups.map((g) => (g.header as DiveGroupHeader).diveId).toList(),
      ['A', 'B', null]);
  expect(groups.first.entries, [e1, e2, e5]);
});

test('groupByTimeline groups by month then day', () {
  // e1 Jun 12 2026, e2 Jun 12 2026, e3 Jun 11 2026, e4 May 3 2026
  // -> [June2026/Jun12: e1,e2], [June2026/Jun11: e3], [May2026/May3: e4]
  // month boundary detected when monthStart changes between consecutive
  // day groups; assert monthStart and dayStart values explicitly with
  // DateTime(2026, 6, 12) etc.
});

test('timeline uses takenAt, falling back to createdAt', () { ... });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/media_library_groupers_test.dart --timeout 120s`
Expected: FAIL.

- [ ] **Step 3: Implement groupers**

```dart
List<MediaLibraryGroup> groupByDive(List<MediaLibraryEntry> entries) {
  final byDive = <String?, List<MediaLibraryEntry>>{};
  for (final e in entries) {
    byDive.putIfAbsent(e.item.diveId, () => []).add(e);
  }
  final unlinked = byDive.remove(null);
  final groups = <MediaLibraryGroup>[
    for (final MapEntry(:key, :value) in byDive.entries)
      MediaLibraryGroup(
        header: DiveGroupHeader(
          diveId: key,
          diveNumber: value.first.diveNumber,
          siteName: value.first.siteName,
          diveDateTime: value.first.diveDateTime,
        ),
        entries: value,
      ),
  ];
  if (unlinked != null && unlinked.isNotEmpty) {
    groups.add(
      MediaLibraryGroup(header: DiveGroupHeader(diveId: null),
          entries: unlinked),
    );
  }
  return groups;
}
```

`groupByTimeline`: local-time day buckets from `(item.takenAt ?? item.createdAt).toLocal()`, `DateTime(y, m, d)` day keys in first-seen order; a group's `monthStart` is `DateTime(y, m)`. The grouped-list widget renders a month header row whenever `monthStart` differs from the previous group's, then the day header, then a non-scrolling `GridView` (shrinkWrap, `NeverScrollableScrollPhysics`) of tiles inside a single outer `ListView` that carries the same near-end `loadMore` NotificationListener as Task 8. Dive headers: `Text(context.l10n.media_library_diveHeader(entry.diveNumber ?? 0, siteName ?? ''))` with an `InkWell` wrapping the header that calls `context.go('/dives/${header.diveId}')`; the unlinked group header uses `media_library_unlinkedHeader`. Month/day formatting: `DateFormat.yMMMM(localeName)` and `DateFormat.MMMEd(localeName)` from intl.

Extend the `SegmentedButton` in `MediaLibraryView` to the three modes writing `mediaLibraryViewModeProvider`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/media/presentation/ --timeout 120s`
Expected: ALL PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/ lib/l10n/ test/features/media/
git commit -m "Add by-dive and timeline library view modes"
```

---

### Task 10: Shared full-screen viewer

Generalize `PhotoViewerPage` from dive-scoped to list-scoped; the trip viewer becomes a thin wrapper deletion. This is the riskiest task — run the FULL suite at the end.

**Files:**
- Create: `lib/features/media/presentation/pages/media_viewer_page.dart` (the generalized viewer — start from `photo_viewer_page.dart`'s content)
- Modify: `lib/features/media/presentation/pages/photo_viewer_page.dart` (becomes a thin dive-scoped wrapper)
- Delete: `lib/features/media/presentation/pages/trip_photo_viewer_page.dart`
- Modify call sites: `lib/features/trips/presentation/pages/trip_gallery_page.dart:425`, `lib/features/media/presentation/widgets/dive_media_section.dart:407`, `lib/features/dive_log/presentation/widgets/photo_marker_overlay.dart:89`
- Modify: l10n arbs (`media_viewer_goToDive` "Go to dive") + gen-l10n
- Test: `test/features/media/presentation/media_viewer_page_test.dart`

**Interfaces:**
- Produces:

```dart
class MediaViewerPage extends ConsumerStatefulWidget {
  const MediaViewerPage({
    super.key,
    required this.mediaList,      // List<MediaItem>, immutable snapshot
    required this.initialMediaId, // String
    this.showGoToDive = false,    // bool: show "Go to dive" on items with diveId
  });
}
```

- [ ] **Step 1: Create MediaViewerPage from PhotoViewerPage**

Copy `photo_viewer_page.dart` to `media_viewer_page.dart`, rename the classes (`MediaViewerPage`/`_MediaViewerPageState`), then make exactly these changes:

1. Replace the `diveId` field with `mediaList` + `showGoToDive` per the interface above.
2. In `build`, delete `final mediaAsync = ref.watch(mediaForDiveProvider(widget.diveId));` and the surrounding `mediaAsync.when(...)` — use `widget.mediaList` directly (the empty-list early return keeps its existing localized message).
3. `final diveAsync = ref.watch(diveProvider(widget.diveId));` — the viewer overlays dive context per item now: replace with a per-current-item lookup `final currentDiveId = mediaList[_currentIndex].diveId;` and watch `diveProvider(currentDiveId)` only when non-null (guard with a small helper that returns `AsyncValue.data(null)` when there is no dive). Everything downstream that used the single dive falls back to hiding itself when the current item has no dive.
4. Every action that operated on "the dive's media list via mediaForDiveProvider" (delete/refresh paths) switches to operating on the passed list; after a delete, remove the item from a local mutable copy and `setState`, popping the page when the copy empties (this matches the trip viewer's snapshot behavior).
5. Add the "Go to dive" overlay action when `showGoToDive && currentItem.diveId != null`: an `IconButton(icon: Icon(Icons.scuba_diving), tooltip: context.l10n.media_viewer_goToDive, onPressed: () { Navigator.of(context).pop(); context.go('/dives/${currentItem.diveId}'); })` placed alongside the existing share/close actions.

- [ ] **Step 2: Convert PhotoViewerPage into a wrapper**

Replace the entire body of `photo_viewer_page.dart` with:

```dart
/// Dive-scoped wrapper around [MediaViewerPage]: resolves the dive's media
/// list, then hands off. Kept so the two dive-detail call sites keep their
/// reactive list resolution.
class PhotoViewerPage extends ConsumerWidget {
  const PhotoViewerPage({
    super.key,
    required this.diveId,
    required this.initialMediaId,
  });

  final String diveId;
  final String initialMediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaForDiveProvider(diveId));
    return mediaAsync.when(
      data: (mediaList) => MediaViewerPage(
        mediaList: mediaList,
        initialMediaId: initialMediaId,
      ),
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('$e', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
```

The two dive call sites (`dive_media_section.dart:407`, `photo_marker_overlay.dart:89`) keep compiling unchanged.

- [ ] **Step 3: Rewire the trip gallery and delete the trip viewer**

In `trip_gallery_page.dart:425` replace the `TripPhotoViewerPage(...)` push with:

```dart
MediaViewerPage(
  mediaList: flatMediaList, // already available via
                            // flatMediaListForTripProvider in that widget
  initialMediaId: item.id,
  showGoToDive: true,
),
```

(read the surrounding build method: the flat list is either already watched or one `ref.watch(flatMediaListForTripProvider(tripId))` away — resolve the AsyncValue before pushing, mirroring how the page currently guards). Delete `trip_photo_viewer_page.dart` and remove its import.

- [ ] **Step 4: Wire the Library grid tap**

In `media_library_view.dart`, `onTileTap`:

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => MediaViewerPage(
      mediaList: entries.map((e) => e.item).toList(),
      initialMediaId: entry.item.id,
      showGoToDive: true,
    ),
  ),
);
```

- [ ] **Step 5: Write viewer widget tests**

```dart
testWidgets('renders the initial item and swipes to the next',
    (tester) async {
  // two photo MediaItems with unresolvable sources (placeholder tiles);
  // pump MediaViewerPage(mediaList: [...], initialMediaId: 'b');
  // assert the PageView's current page is index 1; drag left; index 0.
});

testWidgets('Go to dive action appears only when enabled and linked',
    (tester) async { ... });
```

- [ ] **Step 6: Run the FULL test suite**

Run: `flutter test --timeout 120s`
Expected: ALL PASS. Trip gallery, dive detail, and photo-marker tests are the consumers most likely to break; fix forward within this task. Known pre-existing flakes (backup suite, upload drain, recovery-code yoyo) may fail unrelated to this change — rerun the specific file once to confirm flake vs regression.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A lib/features/media/presentation/pages/ \
        lib/features/trips/presentation/pages/trip_gallery_page.dart \
        lib/features/dive_log/presentation/widgets/photo_marker_overlay.dart \
        lib/l10n/ test/features/media/
git commit -m "Generalize full-screen viewer to shared MediaViewerPage"
```

---

### Task 11: Multi-select with Delete and Share

**Files:**
- Create: `lib/features/media/presentation/providers/media_selection_provider.dart`
- Create: `lib/features/media/presentation/widgets/media_selection_bar.dart`
- Modify: `lib/features/media/presentation/widgets/media_library_grid.dart` and `media_library_grouped_list.dart` (long-press enters selection mode; tap toggles while active; selected tiles show a check overlay)
- Modify: l10n arbs (`media_library_selectedCount` "{count} selected" plural, `media_library_deleteSelected` "Delete", `media_library_shareSelected` "Share", `media_library_deleteConfirmTitle` "Delete {count} items?", `media_library_deleteConfirmBody` "This removes them from the app and any media store. This cannot be undone.", `common_cancel` likely exists — reuse existing cancel/delete keys where present) + gen-l10n
- Test: `test/features/media/presentation/media_selection_test.dart`

**Interfaces:**
- Consumes: the deletion path used by `MediaListNotifier.deleteMultipleMedia` (media_providers.dart:144) — open that method and call the SAME coordinator/provider chain it calls, so library deletes write tombstones and enqueue store deletes identically. Share: the existing share implementation inside the viewer (`media_viewer_page.dart` after Task 10 — it has an `onShare` path); extract its per-item bytes-resolution + `share_plus` call into `lib/features/media/presentation/helpers/media_share_helper.dart` with signature `Future<void> shareMediaItems(BuildContext context, WidgetRef ref, List<MediaItem> items)` and reuse it from both the viewer and the selection bar.
- Produces:

```dart
final mediaSelectionProvider =
    StateNotifierProvider<MediaSelectionNotifier, Set<String>>;
class MediaSelectionNotifier extends StateNotifier<Set<String>> {
  void toggle(String mediaId);
  void clear();
}
// selection mode is active iff the set is non-empty
```

- [ ] **Step 1: Write failing tests**

```dart
test('toggle adds then removes an id', () { ... });

testWidgets('long-press enters selection mode and shows the bar',
    (tester) async {
  // pump the library view with 3 fixture entries; long-press tile 0;
  // expect '1 selected' text and the delete/share actions
});

testWidgets('delete confirms then calls the deletion chain',
    (tester) async {
  // override the deletion provider chain with a recording fake;
  // select 2, tap Delete, tap confirm; expect fake got both ids
  // and the selection cleared
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/media_selection_test.dart --timeout 120s`
Expected: FAIL.

- [ ] **Step 3: Implement**

`MediaSelectionNotifier` is a 15-line StateNotifier over `Set<String>` (immutable set replace, never mutate). `MediaSelectionBar` renders inside `MediaLibraryView` above the content when the set is non-empty: count text, Share button (calls `shareMediaItems` with the selected `MediaItem`s resolved from current entries), Delete button (confirm `AlertDialog` with the localized title/body, then the deletion chain, then `clear()`). Tiles wrap in a `Stack` with a top-right `Icon(Icons.check_circle)` overlay when selected; `GestureDetector.onLongPress` toggles the first id; while non-empty, `onTap` toggles instead of opening the viewer.

- [ ] **Step 4: Run the media presentation tests**

Run: `flutter test test/features/media/presentation/ --timeout 120s`
Expected: ALL PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/ lib/l10n/ test/features/media/
git commit -m "Add library multi-select with delete and share"
```

---

### Task 12: Transfers view, final sweep

**Files:**
- Modify: `lib/features/media_store/presentation/pages/transfers_page.dart` (extract the body into an embeddable widget)
- Create: `lib/features/media_store/presentation/widgets/transfers_view.dart`
- Modify: `lib/features/media/presentation/pages/media_section_page.dart` (transfers section renders `TransfersView`; sidebar badges wire `unlinkedCountProvider`/`missingCountProvider` — Phase 1 shows them on Library only if nonzero is meaningless; wire `badgeCounts` empty for now and leave counts to Phase 2's sections. Keep the providers exercised by tests only.)
- Test: `test/features/media/presentation/media_section_page_test.dart`

**Interfaces:**
- Produces: `TransfersView` — the `TransfersPage` body as a standalone `ConsumerWidget` (page keeps its Scaffold/AppBar and renders `TransfersView` too, so Settings deep links keep working).

- [ ] **Step 1: Extract TransfersView**

`transfers_page.dart:31` — move everything inside `body:` into `TransfersView.build`, and have both `TransfersPage` and the media console render it. Pure widget move: no provider or logic changes.

- [ ] **Step 2: Wire the console's transfers section**

In `media_section_page.dart`: `MediaConsoleSection.transfers => const TransfersView()`.

- [ ] **Step 3: Section page widget test**

```dart
testWidgets('switching sections swaps library and transfers content',
    (tester) async {
  // pump MediaSectionPage at 1100px with overridden providers
  // (library notifier seeded empty; transfer entries provider seeded empty);
  // assert Library content initially; tap 'Transfers'; assert TransfersView
  // is in the tree.
});
```

Run: `flutter test test/features/media/presentation/media_section_page_test.dart --timeout 120s`
Expected: PASS after wiring.

- [ ] **Step 4: Run the media and media_store test directories**

Run: `flutter test test/features/media/ test/features/media_store/ --timeout 120s`
Expected: ALL PASS (the TransfersPage extraction is a pure widget move; its existing tests must stay green).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib/features/media_store/presentation/ \
        lib/features/media/presentation/ test/features/media/
git commit -m "Embed transfers view in Media console"
```

---

### Task 13: Library filter bar (site, trip, date range) and final sweep

The spec's approved Library capability list includes filtering by site, trip, and date range — the query layer (Task 4) already supports them; this task adds the UI.

**Files:**
- Create: `lib/features/media/presentation/widgets/media_library_filter_bar.dart` (replaces the inline chip row from Task 8)
- Modify: `lib/features/media/presentation/pages/media_library_view.dart`
- Modify: l10n arbs (`media_library_filter_site` "Site", `media_library_filter_trip` "Trip", `media_library_filter_dates` "Dates", `media_library_filter_clear` "Clear filters") + gen-l10n
- Test: `test/features/media/presentation/media_library_filter_bar_test.dart`

**Interfaces:**
- Consumes: `mediaLibraryFilterProvider` (Task 7); the app's existing site and trip list providers — open `lib/features/dive_sites/presentation/providers/` and `lib/features/trips/presentation/providers/trip_providers.dart` and use the plain all-sites / all-trips list providers found there for the picker sheets.
- Produces: `MediaLibraryFilterBar` — a `ConsumerWidget` chip row writing `mediaLibraryFilterProvider`.

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('site chip opens picker and writes siteId to the filter',
    (tester) async {
  // override the sites list provider with two fixture sites;
  // tap 'Site' chip; tap the first site in the sheet;
  // expect container.read(mediaLibraryFilterProvider).siteId == 'site-1'
  // and the chip now shows the site name with a clear (x) affordance.
});

testWidgets('date chip uses showDateRangePicker result', (tester) async {
  // tap 'Dates'; select a range; expect fromDate/toDate set on the filter
});

testWidgets('clear filters resets to MediaLibraryFilter.none',
    (tester) async { ... });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/media_library_filter_bar_test.dart --timeout 120s`
Expected: FAIL.

- [ ] **Step 3: Implement**

A single horizontal `SingleChildScrollView` of chips: the Task 8 type chips (All / Photos / Videos) move in here unchanged, then `Site`, `Trip`, `Dates` as `FilterChip`s. Site/Trip chips open a `showModalBottomSheet` listing the provider's items (`ListTile` per item; tap writes `filter.copyWith(siteId: ...)` / `copyWith(tripId: ...)` and pops). Dates uses `showDateRangePicker` writing `fromDate`/`toDate` (end date extended to end-of-day: `DateTime(y, m, d, 23, 59, 59, 999)`). An active chip renders selected with the chosen label and a delete icon that clears just that field. A trailing `Clear filters` `ActionChip` appears when the filter differs from `MediaLibraryFilter.none` and resets the provider. Selected-state comes from watching `mediaLibraryFilterProvider` — the bar is stateless.

- [ ] **Step 4: Run the filter bar tests**

Run: `flutter test test/features/media/presentation/media_library_filter_bar_test.dart --timeout 120s`
Expected: ALL PASS.

- [ ] **Step 5: Full verification sweep**

```bash
dart format .            # must be a no-op now
flutter analyze          # zero issues, infos included
flutter test --timeout 120s
```

Expected: analyzer clean; full suite green (modulo the documented pre-existing flakes — backup suite, upload drain, recovery-code yoyo; rerun any flake-suspect file once in isolation before concluding regression).

- [ ] **Step 6: Commit**

```bash
git add lib/features/media/presentation/ lib/l10n/ test/features/media/
git commit -m "Add library filter bar for site, trip, and date range"
```

---

## Plan self-review notes (already applied)

- Spec coverage for Phase 1: nav (Task 5), console (Task 6), query layer (Task 4), three view modes (Tasks 8-9), shared viewer (Task 10), selection Delete/Share (Task 11), Transfers (Task 12), filter UI for type/site/trip/date (Tasks 8 and 13), v140 + indexes (Tasks 1-2). Badges ship with the providers (Task 7) and light up when Phase 2 adds the Unlinked/Missing sections.
- The spec's "indexes wired into both onCreate and onUpgrade" is implemented via `kPerformanceIndexes` (asserted every open from beforeOpen), which supersedes both — recorded here so the spec deviation is deliberate, not drift.
- Type-consistency: `MediaLibraryEntry`/`MediaLibraryFilter`/`MediaLibraryCursor`/`MediaLibraryPageResult` names match across Tasks 4, 7, 8, 9, 11; `mediaItemFromRow` defined in Task 3, consumed in Task 4; `MediaConsoleSection` defined in Task 6, consumed in Task 12.
