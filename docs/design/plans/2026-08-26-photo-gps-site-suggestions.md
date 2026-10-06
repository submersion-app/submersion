# Photo GPS Site Suggestions (Plan B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing edit-page-only "GPS found in photos" banner into a site suggestion that matches nearby existing and bundled sites before offering to create one, appears on the dive detail page and after multi-dive photo imports, picks the photo nearest the dive's entry time, and remembers a dismissal across devices.

**Architecture:** Photo GPS becomes a second point source for the existing `SiteMatchingService` (`entry ?? exit ?? photo`), which also learns a third apply mode (write coordinates onto a dive's coordinate-less current site) and a `createAndLink` path. One eligibility predicate on `DiveRepository` feeds the banner, the import-wizard button, and a new post-import prompt. Dismissal is a nullable synced column on `dives`. All UI actions route through the service so the banner and the batch review page share one write path.

**Tech Stack:** Flutter, Riverpod (`package:submersion/core/providers/provider.dart` barrel), Drift, mockito codegen for repository mocks, `flutter gen-l10n` with 11 ARB locales.

**Spec:** `docs/superpowers/specs/2026-08-26-photo-gps-site-suggestions-design.md` (Sections 1, 3, 4, 5). Plan A (`2026-08-26-photo-gps-desktop-readers.md`) covers Section 2 and is independent of this plan.

## Global Constraints

- Worktree: `.claude/worktrees/photo-gps-site-suggestions`, branch `worktree-photo-gps-site-suggestions`. Run every command from that directory.
- No em-dashes anywhere (code, comments, commits, ARB strings). No emojis in code or docs.
- Files stay under 800 lines; target 200-400. `dive_edit_page.dart` and `dive_detail_page.dart` are already far over; touch them only at the seams named below and do not add logic to them.
- TDD: failing test, run, implement, run, commit. `dart format .` before every commit; `flutter analyze` clean (infos are fatal in CI).
- Every new user-facing string goes into ALL 11 ARB files (`lib/l10n/arb/app_{en,de,es,fr,it,nl,pt,zh,ar,he,hu}.arb`), then `flutter gen-l10n`, and the regenerated `lib/l10n/arb/app_localizations*.dart` files are committed with the ARBs.
- Schema rung: **v172** (main is at 166; 167 through 171 are claimed by open PRs as of 2026-08-26). Task 1 re-verifies before anything is written.
- Timestamps: `media.taken_at` and `dives.entry_time` are wall-clock-UTC epoch millis; always read them with `isUtc: true`.
- Site writes that touch only coordinates or altitude use the narrow column patches `SiteRepository.updateSiteCoordinates` / `updateSiteAltitude`, never `updateSite(site.copyWith(...))` on a possibly partial entity (issue #1187).
- Network calls (reverse geocode, elevation) never run inside a DB transaction and never block a write from completing.
- Run tests one file at a time as shown; do not overlap `flutter test` runs.

---

## File map

New:

| File | Responsibility |
| --- | --- |
| `lib/features/media/domain/services/photo_gps_point_selector.dart` | `PhotoGpsPoint` record and `selectBestPhotoGps` (pure) |
| `lib/features/dive_sites/presentation/providers/site_suggestion_providers.dart` | `siteMatchingServiceFactoryProvider`, `SiteSuggestion`, `siteSuggestionForDiveProvider` |
| `lib/features/dive_log/presentation/helpers/site_suggestion_actions.dart` | `SiteSuggestionActions`: assign / addLocation / createSite / chooseNearby / dismiss, one write path |
| `lib/features/dive_log/presentation/widgets/site_suggestion_banner.dart` | Presentational banner (five action cases) |
| `lib/features/dive_log/presentation/widgets/site_suggestion_card.dart` | Consumer wrapper: watches the provider, wires the actions, used by edit and detail pages |
| `lib/features/media/presentation/helpers/offer_site_review_after_import.dart` | Post-import snackbar with "Review sites" action |
| `test/core/database/migration_v172_site_suggestion_dismissed_test.dart` | Migration test |

Modified:

| File | Change |
| --- | --- |
| `lib/core/database/database.dart` | `dives.site_suggestion_dismissed_at`, v172 rung, backstop |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | `setSiteSuggestionDismissed`, unified `getDivesNeedingSiteMatch` |
| `lib/features/media/data/repositories/media_repository.dart` | `getBestPhotoGpsForDives`, `isUtc` fix |
| `lib/features/dive_sites/data/services/site_matching_service.dart` | `PointSource`, photo fallback, current-site mode, `createAndLink`, `sitesLocated`, altitude pass |
| `lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart` | Factory provider, `createSiteHere` |
| `lib/features/dive_sites/presentation/pages/site_match_review_page.dart` | Source chip, current-site card, "Create site here", snackbar counts, photo point on the map |
| `lib/features/media/presentation/widgets/quick_site_from_gps_dialog.dart` | Geocode-prefilled Country / Region / City |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | Swap banner, delete the two handlers |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | Card under both site headers |
| `lib/features/trips/presentation/helpers/trip_scan_actions.dart`, `lib/features/media/presentation/widgets/files_tab.dart`, `lib/features/media/presentation/helpers/lightroom_scan_helper.dart`, `lib/features/media/presentation/pages/media_import_view.dart` | Post-import prompt |
| `lib/l10n/arb/*.arb` | New keys (Task 9 lists every string) |
| `docs/FEATURE_ROADMAP.md`, `docs/REMAINING_TASKS.md` | Tick the item |

Deleted: `lib/features/media/presentation/widgets/photo_gps_suggestion_banner.dart`.

---

### Task 1: Rebase and claim the schema rung

**Files:** none edited.

- [ ] **Step 1: Rebase the branch onto current main**

```bash
git fetch origin main
git rebase origin/main
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```
Expected: rebase applies the two docs commits cleanly. If `database.dart` on main now differs, re-read its ladder tail before Task 2.

- [ ] **Step 2: Re-scan the ladder**

```bash
git grep -h -o 'currentSchemaVersion = [0-9]*' origin/main -- lib/core/database/database.dart
for n in $(gh pr list --state open --json number --jq '.[].number'); do echo "PR $n: $(gh pr diff $n 2>/dev/null | grep -E '^\+\s*static const int currentSchemaVersion' | head -1)"; done
```
Expected: main reports 166 and no open PR claims 172. If either changed, take the smallest number above both main and every open claim, and use that number everywhere this plan says 172 (six places: scalar, ladder entry, helper docstring, `onUpgrade` guard pair, `beforeOpen` backstop comment, the test filename and its two asserts).

- [ ] **Step 3: Run the existing migration tests as a baseline**

Run: `flutter test test/core/database/migration_v161_o2_cell_mv_default_test.dart`
Expected: PASS.

---

### Task 2: `dives.site_suggestion_dismissed_at` at v172

**Files:**
- Modify: `lib/core/database/database.dart` (the `Dives` table near line 764, the `currentSchemaVersion` scalar near line 3182, the `migrationVersions` tail near line 3479, `onUpgrade` after the v164 rung near line 8616, `beforeOpen` backstops near line 8820, and a new `_assertSiteSuggestionDismissedAtColumn` helper beside `_assertO2CellMvDefaultColumn` near line 4958)
- Test: `test/core/database/migration_v172_site_suggestion_dismissed_test.dart`

**Interfaces:**
- Produces: Drift column `Dives.siteSuggestionDismissedAt` (`IntColumn`, nullable, SQL `site_suggestion_dismissed_at`), `DivesCompanion.siteSuggestionDismissedAt`.

- [ ] **Step 1: Write the failing migration test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v172 shape: a dives table without the dismissal column,
/// stamped at v171 so the 171 to 172 upgrade runs.
NativeDatabase _dbAt171() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 171');
      rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          dive_datetime INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute(
        "INSERT INTO dives (id, dive_datetime, created_at, updated_at) "
        "VALUES ('d1', 0, 0, 0)",
      );
    },
  );
}

void main() {
  test('v172 adds site_suggestion_dismissed_at defaulting to NULL', () async {
    final db = AppDatabase(_dbAt171());
    addTearDown(() => db.close());

    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('site_suggestion_dismissed_at'));

    final row = await db
        .customSelect('SELECT site_suggestion_dismissed_at AS v FROM dives')
        .getSingle();
    expect(row.readNullable<int>('v'), isNull);
  });

  test('fresh databases get the column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('site_suggestion_dismissed_at'));
  });

  test('the helper no-ops when dives is absent', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 171'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);
    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('v172 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(172));
    expect(AppDatabase.migrationVersions, contains(172));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v172_site_suggestion_dismissed_test.dart`
Expected: FAIL on the column assertions and the ladder assertion.

- [ ] **Step 3: Add the column to the `Dives` table**

Directly after `TextColumn get hlc => text().nullable()();` in `class Dives`:

```dart
  /// When the diver dismissed the site suggestion for this dive (photo GPS or
  /// dive-computer GPS). Null = never dismissed. Synced with the row.
  IntColumn get siteSuggestionDismissedAt => integer().nullable()();
```

- [ ] **Step 4: Bump the scalar and the ladder**

Change `static const int currentSchemaVersion = 164;` (or whatever main now holds) to `172`. Append to the `migrationVersions` list after the last entry:

```dart
    // v172: dives.site_suggestion_dismissed_at, the synced per-dive dismissal
    // of the photo / dive-computer site suggestion. 167 through 171 are
    // reserved by PRs that were open when this branch was cut, so this rung is
    // deliberately non-contiguous, not missing.
    172,
```

- [ ] **Step 5: Add the helper, the `onUpgrade` pair, and the backstop**

Helper, beside `_assertO2CellMvDefaultColumn`:

```dart
  /// v172: site_suggestion_dismissed_at on dives. Null means the site
  /// suggestion (from photo GPS or dive-computer GPS) was never dismissed.
  Future<void> _assertSiteSuggestionDismissedAtColumn() async {
    final cols = await customSelect("PRAGMA table_info('dives')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('site_suggestion_dismissed_at')) {
      await customStatement(
        'ALTER TABLE dives ADD COLUMN site_suggestion_dismissed_at INTEGER',
      );
    }
  }
```

In `onUpgrade`, after the v164 pair (and after any rung main has since added):

```dart
        // v172: dives.site_suggestion_dismissed_at (site suggestion dismissal).
        if (from < 172) {
          await _assertSiteSuggestionDismissedAtColumn();
        }
        if (from < 172) await reportProgress();
```

In `beforeOpen`, after the last existing backstop:

```dart
        // v172 backstop: re-assert dives.site_suggestion_dismissed_at (same
        // parallel-branch version-collision self-heal).
        await _assertSiteSuggestionDismissedAtColumn();
```

- [ ] **Step 6: Regenerate Drift code and run the test**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/database/migration_v172_site_suggestion_dismissed_test.dart
```
Expected: PASS (4 tests).

- [ ] **Step 7: Run the schema-adjacent suites**

Run: `flutter test test/core/database`
Expected: PASS.
Run: `flutter test test/core/services/sync/export_changeset_test.dart`
Expected: PASS (the dives export is table-generic; the new nullable column rides along).

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format lib/core/database test/core/database
flutter analyze lib/core/database test/core/database
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v172_site_suggestion_dismissed_test.dart
git commit -m "feat(db): add dives.site_suggestion_dismissed_at at v172"
```

---

### Task 3: `DiveRepository.setSiteSuggestionDismissed` (synced)

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (beside `setSite`, near line 408)
- Test: `test/features/dive_log/data/repositories/dive_repository_site_match_test.dart`

**Interfaces:**
- Produces: `Future<void> setSiteSuggestionDismissed(String diveId, bool dismissed)`; writes epoch millis or null, bumps the dive HLC through `markRecordPending('dives')`, notifies `SyncEventBus`.

- [ ] **Step 1: Write the failing tests**

Add to `dive_repository_site_match_test.dart` (imports to add: `package:submersion/core/data/repositories/sync_repository.dart`, `package:submersion/core/services/sync/sync_data_serializer.dart`):

```dart
  test('setSiteSuggestionDismissed writes and clears the timestamp', () async {
    await insertDive('d1', lat: 1, lng: 2);

    await repo.setSiteSuggestionDismissed('d1', true);
    var row = await db
        .customSelect(
          "SELECT site_suggestion_dismissed_at AS v FROM dives WHERE id = 'd1'",
        )
        .getSingle();
    expect(row.readNullable<int>('v'), isNotNull);

    await repo.setSiteSuggestionDismissed('d1', false);
    row = await db
        .customSelect(
          "SELECT site_suggestion_dismissed_at AS v FROM dives WHERE id = 'd1'",
        )
        .getSingle();
    expect(row.readNullable<int>('v'), isNull);
  });

  test('a dismissal advances the dive HLC so it exports', () async {
    await insertDive('d1', lat: 1, lng: 2);
    final sync = SyncRepository();
    await sync.markRecordPending(
      entityType: 'dives',
      recordId: 'd1',
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final watermark =
        (await db
                .customSelect("SELECT hlc FROM dives WHERE id = 'd1'")
                .getSingle())
            .read<String>('hlc');
    final serializer = SyncDataSerializer();
    final deviceId = await sync.getDeviceId();

    final before = await serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: watermark,
      deletions: const [],
    );
    expect(before.data.dives.map((d) => d['id']), isNot(contains('d1')));

    await repo.setSiteSuggestionDismissed('d1', true);

    final after = await serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: watermark,
      deletions: const [],
    );
    final exported = after.data.dives.firstWhere((d) => d['id'] == 'd1');
    expect(
      exported['siteSuggestionDismissedAt'],
      isNotNull,
      reason: 'the dismissal must ride the dive row to other devices',
    );
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_site_match_test.dart`
Expected: FAIL, "The method 'setSiteSuggestionDismissed' isn't defined".

- [ ] **Step 3: Implement**

Directly after `setSite` in `dive_repository_impl.dart`:

```dart
  /// Records (or clears, when [dismissed] is false) the diver's dismissal of
  /// the site suggestion for this dive. Single-column update; the dive row
  /// carries its own HLC, so marking it pending is what syncs the flag.
  Future<void> setSiteSuggestionDismissed(String diveId, bool dismissed) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(
          siteSuggestionDismissedAt: Value(dismissed ? now : null),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set site suggestion dismissal on dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_site_match_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/data test/features/dive_log/data
flutter analyze lib/features/dive_log/data test/features/dive_log/data
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_site_match_test.dart
git commit -m "feat(dives): synced site suggestion dismissal"
```

---

### Task 4: Nearest-to-entry photo point and the join query

**Files:**
- Create: `lib/features/media/domain/services/photo_gps_point_selector.dart`
- Modify: `lib/features/media/data/repositories/media_repository.dart:1043-1104`
- Test: `test/features/media/domain/services/photo_gps_point_selector_test.dart`, `test/features/media/data/repositories/media_repository_test.dart`

**Interfaces:**
- Produces:
  - `typedef PhotoGpsPoint = ({String mediaId, GeoPoint location, DateTime takenAt});`
  - `PhotoGpsPoint? selectBestPhotoGps(List<PhotoGpsPoint> samples, DateTime entryTime)`
  - `Future<Map<String, PhotoGpsPoint>> MediaRepository.getBestPhotoGpsForDives(List<String> diveIds)`
  - `MediaRepository.getBestGpsFromDiveMedia(diveId)` keeps its signature and delegates to the above (so `divePhotoGpsProvider` is unchanged).
  - `getGpsFromDiveMedia` returns `takenAt` with `isUtc: true`.

- [ ] **Step 1: Write the failing selector test**

`test/features/media/domain/services/photo_gps_point_selector_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/services/photo_gps_point_selector.dart';

PhotoGpsPoint _p(String id, DateTime at) =>
    (mediaId: id, location: GeoPoint(1, 1), takenAt: at);

void main() {
  final entry = DateTime.utc(2025, 12, 27, 11, 26);

  test('picks the sample nearest the entry time, before or after', () {
    final best = selectBestPhotoGps([
      _p('hotel', DateTime.utc(2025, 12, 27, 7, 0)),
      _p('boat', DateTime.utc(2025, 12, 27, 11, 20)),
      _p('after', DateTime.utc(2025, 12, 27, 12, 30)),
    ], entry);
    expect(best?.mediaId, 'boat');
  });

  test('ties go to the earlier sample', () {
    final best = selectBestPhotoGps([
      _p('later', DateTime.utc(2025, 12, 27, 11, 36)),
      _p('earlier', DateTime.utc(2025, 12, 27, 11, 16)),
    ], entry);
    expect(best?.mediaId, 'earlier');
  });

  test('empty input yields null', () {
    expect(selectBestPhotoGps(const [], entry), isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/domain/services/photo_gps_point_selector_test.dart`
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Create the selector**

```dart
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// One GPS-tagged media row linked to a dive.
typedef PhotoGpsPoint = ({String mediaId, GeoPoint location, DateTime takenAt});

/// The photo most likely shot at the site: the one whose capture time is
/// nearest the dive's entry time. The earliest photo (the previous rule) is
/// often a hotel or car-park shot; the one nearest entry is on the boat or
/// the shore. Every linked photo is eligible, because a manual link is the
/// diver asserting the photo belongs to this dive. Ties go to the earlier
/// sample. Both times are wall-clock-UTC, so they compare directly.
PhotoGpsPoint? selectBestPhotoGps(
  List<PhotoGpsPoint> samples,
  DateTime entryTime,
) {
  PhotoGpsPoint? best;
  Duration? bestGap;
  for (final s in samples) {
    final gap = (s.takenAt.difference(entryTime)).abs();
    final better =
        bestGap == null ||
        gap < bestGap ||
        (gap == bestGap && s.takenAt.isBefore(best!.takenAt));
    if (better) {
      best = s;
      bestGap = gap;
    }
  }
  return best;
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/media/domain/services/photo_gps_point_selector_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing repository tests**

Append a group to `test/features/media/data/repositories/media_repository_test.dart` (the file already has `createTestDiveInDb` and `createTestMediaItem`; `createTestDiveInDb` needs an optional `DateTime? entryTime` parameter, so add `DateTime? entryTime` to its signature and pass `entryTime: entryTime` into the `Dive(...)` it builds):

```dart
  group('getBestPhotoGpsForDives', () {
    test('selects the photo nearest entry per dive and skips dives without GPS', () async {
      final entry = DateTime.utc(2025, 12, 27, 11, 26);
      await createTestDiveInDb(id: 'd1', diveNumber: 1, entryTime: entry);
      await createTestDiveInDb(id: 'd2', diveNumber: 2, entryTime: entry);
      await repository.createMedia(
        createTestMediaItem(
          id: 'hotel',
          diveId: 'd1',
          latitude: 10,
          longitude: 10,
          takenAt: DateTime.utc(2025, 12, 27, 7),
        ),
      );
      await repository.createMedia(
        createTestMediaItem(
          id: 'boat',
          diveId: 'd1',
          latitude: 20.5,
          longitude: -87.25,
          takenAt: DateTime.utc(2025, 12, 27, 11, 20),
        ),
      );
      await repository.createMedia(
        createTestMediaItem(id: 'nogps', diveId: 'd2', takenAt: entry),
      );

      final best = await repository.getBestPhotoGpsForDives(['d1', 'd2']);

      expect(best.keys, ['d1']);
      expect(best['d1']!.mediaId, 'boat');
      expect(best['d1']!.location.latitude, 20.5);
      expect(best['d1']!.takenAt.isUtc, isTrue);
    });

    test('ignores (0,0) fixes and an empty id list', () async {
      await createTestDiveInDb(id: 'd1', diveNumber: 1);
      await repository.createMedia(
        createTestMediaItem(id: 'zero', diveId: 'd1', latitude: 0, longitude: 0),
      );
      expect(await repository.getBestPhotoGpsForDives(['d1']), isEmpty);
      expect(await repository.getBestPhotoGpsForDives(const []), isEmpty);
    });

    test('getBestGpsFromDiveMedia delegates and getGpsFromDiveMedia is UTC', () async {
      final entry = DateTime.utc(2025, 12, 27, 11, 26);
      await createTestDiveInDb(id: 'd1', diveNumber: 1, entryTime: entry);
      await repository.createMedia(
        createTestMediaItem(
          id: 'm',
          diveId: 'd1',
          latitude: 1.5,
          longitude: 2.5,
          takenAt: DateTime.utc(2025, 12, 27, 11, 30),
        ),
      );
      final best = await repository.getBestGpsFromDiveMedia('d1');
      expect(best, (latitude: 1.5, longitude: 2.5));
      final all = await repository.getGpsFromDiveMedia('d1');
      expect(all.single.takenAt.isUtc, isTrue);
      expect(all.single.takenAt, DateTime.utc(2025, 12, 27, 11, 30));
    });
  });
```

- [ ] **Step 6: Run to verify failure**

Run: `flutter test test/features/media/data/repositories/media_repository_test.dart`
Expected: FAIL, "The method 'getBestPhotoGpsForDives' isn't defined".

- [ ] **Step 7: Implement in `media_repository.dart`**

Add imports:

```dart
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/services/photo_gps_point_selector.dart';
```

In `getGpsFromDiveMedia`, change the `takenAt` mapping to `DateTime.fromMillisecondsSinceEpoch(row.data['taken_at'] as int, isUtc: true)` and change the SQL guard `AND latitude != 0 AND longitude != 0` to `AND NOT (latitude = 0 AND longitude = 0)`.

Replace `getBestGpsFromDiveMedia` and add the batch query:

```dart
  /// The best photo fix for each of [diveIds]: the GPS-tagged media row whose
  /// capture time is nearest the dive's entry time (see
  /// [selectBestPhotoGps]). One join query, no dive hydration. Dives with no
  /// usable fix are absent from the map.
  Future<Map<String, PhotoGpsPoint>> getBestPhotoGpsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const {};
    try {
      final samplesByDive = <String, List<PhotoGpsPoint>>{};
      final entryByDive = <String, DateTime>{};
      // SQLite caps bound variables; chunk generously below the limit.
      for (var i = 0; i < diveIds.length; i += 500) {
        final chunk = diveIds.sublist(
          i,
          i + 500 > diveIds.length ? diveIds.length : i + 500,
        );
        final m = _db.media;
        final d = _db.dives;
        final query = _db.select(m).join([innerJoin(d, d.id.equalsExp(m.diveId))])
          ..where(
            m.diveId.isIn(chunk) &
                m.latitude.isNotNull() &
                m.longitude.isNotNull() &
                m.takenAt.isNotNull() &
                (m.latitude.equals(0) & m.longitude.equals(0)).not(),
          );
        for (final row in await query.get()) {
          final media = row.readTable(m);
          final dive = row.readTable(d);
          final diveId = media.diveId!;
          entryByDive[diveId] = DateTime.fromMillisecondsSinceEpoch(
            dive.entryTime ?? dive.diveDateTime,
            isUtc: true,
          );
          samplesByDive.putIfAbsent(diveId, () => []).add((
            mediaId: media.id,
            location: GeoPoint(media.latitude!, media.longitude!),
            takenAt: DateTime.fromMillisecondsSinceEpoch(
              media.takenAt!,
              isUtc: true,
            ),
          ));
        }
      }
      return {
        for (final e in samplesByDive.entries)
          if (selectBestPhotoGps(e.value, entryByDive[e.key]!) case final best?)
            e.key: best,
      };
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get best photo GPS for dives',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The best photo fix for one dive, or null. See [getBestPhotoGpsForDives].
  Future<({double latitude, double longitude})?> getBestGpsFromDiveMedia(
    String diveId,
  ) async {
    final best = (await getBestPhotoGpsForDives([diveId]))[diveId];
    if (best == null) return null;
    return (
      latitude: best.location.latitude,
      longitude: best.location.longitude,
    );
  }
```

If the Drift `Dive` row field for the entry time is not `entryTime`, look it up in `class Dives` in `database.dart` (it is the column paired with `exitTime`) and use that name.

- [ ] **Step 8: Run to verify pass**

Run: `flutter test test/features/media/data/repositories/media_repository_test.dart`
Expected: PASS.
Run: `flutter test test/features/media/presentation/providers`
Expected: PASS (`divePhotoGpsProvider` is unchanged).

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format lib/features/media test/features/media
flutter analyze lib/features/media test/features/media
git add lib/features/media/domain/services/photo_gps_point_selector.dart lib/features/media/data/repositories/media_repository.dart test/features/media/domain/services/photo_gps_point_selector_test.dart test/features/media/data/repositories/media_repository_test.dart
git commit -m "feat(media): nearest-to-entry photo GPS point per dive"
```

---

### Task 5: One eligibility predicate for site suggestions

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:531-560` (`getDivesNeedingSiteMatch`)
- Test: `test/features/dive_log/data/repositories/dive_repository_site_match_test.dart`

**Interfaces:**
- Produces: `getDivesNeedingSiteMatch({String? diverId, List<String>? limitToIds})` now returns dives where `(site_id IS NULL OR the site has no coordinates) AND (dive GPS OR a GPS-tagged media row exists) AND site_suggestion_dismissed_at IS NULL`. Same signature, so the import wizard and the review notifier need no change.

- [ ] **Step 1: Write the failing tests**

In `dive_repository_site_match_test.dart`, extend `insertSite` to accept coordinates and add a media helper (imports to add: `package:submersion/features/media/data/repositories/media_repository.dart`, `package:submersion/features/media/domain/entities/media_item.dart`):

```dart
  Future<String> insertSite(String id, {double? lat, double? lng}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value(id),
            name: Value('Site $id'),
            latitude: Value(lat),
            longitude: Value(lng),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  Future<void> insertPhotoWithGps(String id, String diveId) async {
    final now = DateTime.now();
    await MediaRepository().createMedia(
      MediaItem(
        id: id,
        diveId: diveId,
        filePath: '/photos/$id.jpg',
        mediaType: MediaType.photo,
        latitude: 20.5,
        longitude: -87.25,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
```

Then the tests:

```dart
  group('getDivesNeedingSiteMatch (unified predicate)', () {
    test('includes a siteless dive whose only GPS is a photo', () async {
      await insertDive('photoOnly');
      await insertPhotoWithGps('p1', 'photoOnly');
      final ids = (await repo.getDivesNeedingSiteMatch()).map((d) => d.id);
      expect(ids, contains('photoOnly'));
    });

    test('includes a dive whose site lacks coordinates', () async {
      final bare = await insertSite('bare');
      await insertDive('sitedNoCoords', lat: 1, lng: 2, siteId: bare);
      final ids = (await repo.getDivesNeedingSiteMatch()).map((d) => d.id);
      expect(ids, contains('sitedNoCoords'));
    });

    test('excludes a dive whose site has coordinates', () async {
      final located = await insertSite('located', lat: 5, lng: 6);
      await insertDive('sited', lat: 1, lng: 2, siteId: located);
      final ids = (await repo.getDivesNeedingSiteMatch()).map((d) => d.id);
      expect(ids, isNot(contains('sited')));
    });

    test('excludes a dismissed dive and a dive with no point at all', () async {
      await insertDive('dismissed', lat: 1, lng: 2);
      await repo.setSiteSuggestionDismissed('dismissed', true);
      await insertDive('nothing');
      final ids = (await repo.getDivesNeedingSiteMatch()).map((d) => d.id);
      expect(ids, isNot(contains('dismissed')));
      expect(ids, isNot(contains('nothing')));
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_site_match_test.dart`
Expected: the "photo only", "site lacks coordinates", and "dismissed" cases FAIL.

- [ ] **Step 3: Implement the predicate**

Replace the `where` in `getDivesNeedingSiteMatch` and its doc comment:

```dart
  /// Dives that could be given a site from a GPS point (dive-computer entry
  /// or exit fix, or a GPS-tagged photo) and still need one: no site, or a
  /// site without coordinates. Dives whose suggestion was dismissed are
  /// excluded. When [limitToIds] is provided, restricts to that id set.
  Future<List<domain.Dive>> getDivesNeedingSiteMatch({
    String? diverId,
    List<String>? limitToIds,
  }) async {
    if (limitToIds != null && limitToIds.isEmpty) return [];
    try {
      final query = _db.select(_db.dives)
        ..where((t) {
          final hasDiveGps =
              (t.entryLatitude.isNotNull() & t.entryLongitude.isNotNull()) |
              (t.exitLatitude.isNotNull() & t.exitLongitude.isNotNull());
          final hasPhotoGps = existsQuery(
            _db.select(_db.media)..where(
              (m) =>
                  m.diveId.equalsExp(t.id) &
                  m.latitude.isNotNull() &
                  m.longitude.isNotNull() &
                  (m.latitude.equals(0) & m.longitude.equals(0)).not(),
            ),
          );
          final siteLacksCoordinates = existsQuery(
            _db.select(_db.diveSites)..where(
              (s) =>
                  s.id.equalsExp(t.siteId) &
                  (s.latitude.isNull() | s.longitude.isNull()),
            ),
          );
          var cond =
              (t.siteId.isNull() | siteLacksCoordinates) &
              (hasDiveGps | hasPhotoGps) &
              t.siteSuggestionDismissedAt.isNull();
          if (diverId != null) cond = cond & t.diverId.equals(diverId);
          if (limitToIds != null) cond = cond & t.id.isIn(limitToIds);
          return cond;
        })
        ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);
      final rows = await query.get();
      if (rows.isEmpty) return [];
      return await Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives needing site match',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

`existsQuery` comes from `package:drift/drift.dart`, already imported.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_site_match_test.dart`
Expected: PASS (all old and new tests).
Run: `flutter test test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart`
Expected: PASS (it mocks the repository).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/data test/features/dive_log/data
flutter analyze lib/features/dive_log/data test/features/dive_log/data
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_site_match_test.dart
git commit -m "feat(dives): unified eligibility for site suggestions"
```

---

### Task 6: Photo GPS as a second point source in `SiteMatchingService`

**Files:**
- Modify: `lib/features/dive_sites/data/services/site_matching_service.dart`
- Modify: `lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart:85-98` (constructor call)
- Modify: `lib/features/dive_sites/presentation/pages/site_match_review_page.dart:170-186` (`_MapPanel` reads the proposal point)
- Test: `test/features/dive_sites/data/services/site_matching_service_test.dart` (+ regenerated `.mocks.dart`)

**Interfaces:**
- Consumes: `MediaRepository.getBestPhotoGpsForDives` (Task 4).
- Produces:
  - `enum PointSource { diveComputer, photo }`
  - `MatchProposal` gains `final GeoPoint? point;` and `final PointSource pointSource;` (default `PointSource.diveComputer`).
  - `SiteMatchingService` constructor gains `required MediaRepository mediaRepository`.

- [ ] **Step 1: Write the failing tests**

In `site_matching_service_test.dart`: add `MediaRepository` to `@GenerateMocks`, add `import 'package:submersion/features/media/data/repositories/media_repository.dart';`, a `late MockMediaRepository media;` beside the others, `media = MockMediaRepository();` in `setUp` with the default stub `when(media.getBestPhotoGpsForDives(any)).thenAnswer((_) async => const {});`, and pass `mediaRepository: media` in the `service()` helper. Add a siteless-dive helper and tests:

```dart
Dive _diveWithoutGps(String id) =>
    Dive(id: id, diveNumber: 1, dateTime: DateTime(2026, 1, 1), maxDepth: 18);
```

```dart
  group('photo point source', () {
    test('falls back to the photo fix when the dive has no GPS', () async {
      const existing = DiveSite(
        id: 's1',
        name: 'Blue Hole',
        location: GeoPoint(0, 0),
      );
      when(
        sites.getAllSites(diverId: anyNamed('diverId')),
      ).thenAnswer((_) async => const [existing]);
      when(media.getBestPhotoGpsForDives(['d1'])).thenAnswer(
        (_) async => {
          'd1': (
            mediaId: 'm1',
            location: _eastMeters(33),
            takenAt: DateTime.utc(2026, 1, 1),
          ),
        },
      );

      final proposals = await service().computeProposals([
        _diveWithoutGps('d1'),
      ]);

      expect(proposals.single.status, ProposalStatus.clear);
      expect(proposals.single.recommendedCandidateId, 's1');
      expect(proposals.single.pointSource, PointSource.photo);
      expect(proposals.single.point, _eastMeters(33));
    });

    test('dive-computer GPS wins over a photo fix', () async {
      when(media.getBestPhotoGpsForDives(['d1'])).thenAnswer(
        (_) async => {
          'd1': (
            mediaId: 'm1',
            location: const GeoPoint(10, 10),
            takenAt: DateTime.utc(2026, 1, 1),
          ),
        },
      );
      final proposals = await service().computeProposals([
        _diveAt('d1', _eastMeters(33)),
      ]);
      expect(proposals.single.pointSource, PointSource.diveComputer);
      expect(proposals.single.point, _eastMeters(33));
    });

    test('a dive with neither point is skipped', () async {
      final proposals = await service().computeProposals([
        _diveWithoutGps('d1'),
      ]);
      expect(proposals, isEmpty);
    });

    test('a failing photo query degrades to no photo point', () async {
      when(
        media.getBestPhotoGpsForDives(any),
      ).thenAnswer((_) async => throw StateError('db'));
      final proposals = await service().computeProposals([
        _diveAt('d1', _eastMeters(33)),
        _diveWithoutGps('d2'),
      ]);
      expect(proposals.map((p) => p.dive.id), ['d1']);
    });
  });
```

- [ ] **Step 2: Regenerate mocks and run to verify failure**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/dive_sites/data/services/site_matching_service_test.dart
```
Expected: compile FAIL on `mediaRepository:`, `PointSource`, `pointSource`, `point`.

- [ ] **Step 3: Implement**

In `site_matching_service.dart`:

Add imports:

```dart
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
```

Add the enum above `MatchProposal` and the two fields:

```dart
/// Where a proposal's point came from. Dive-computer fixes are measured
/// entry/exit positions; photo fixes are the surface position of the photo
/// nearest the dive's entry time, so the review page labels them.
enum PointSource { diveComputer, photo }

class MatchProposal {
  final Dive dive;
  final ProposalStatus status;
  final List<MatchCandidateView> candidates; // distance-sorted
  final String? recommendedCandidateId; // matcher's pick (clear only)
  final GeoPoint? point;
  final PointSource pointSource;

  const MatchProposal({
    required this.dive,
    required this.status,
    this.candidates = const [],
    this.recommendedCandidateId,
    this.point,
    this.pointSource = PointSource.diveComputer,
  });
}
```

Constructor and fields:

```dart
  SiteMatchingService({
    required SiteRepository siteRepository,
    required DiveSiteApiService apiService,
    required DiveRepository diveRepository,
    required MediaRepository mediaRepository,
    required this.diverId,
    required this.thresholds,
    TransactionRunner? runInTransaction,
  }) : _siteRepository = siteRepository,
       _apiService = apiService,
       _diveRepository = diveRepository,
       _mediaRepository = mediaRepository,
       _runInTransaction =
           runInTransaction ??
           ((body) => DatabaseService.instance.database.transaction(body));

  final MediaRepository _mediaRepository;
  final _log = LoggerService.forClass(SiteMatchingService);
```

Replace `_pointFor` and the head of `computeProposals`:

```dart
  typedef _ResolvedPoint = ({GeoPoint point, PointSource source});

  /// Dive-computer fixes win; the photo fix is the fallback.
  _ResolvedPoint? _pointFor(Dive dive, Map<String, PhotoGpsPoint> photoFixes) {
    final measured = dive.entryLocation ?? dive.exitLocation;
    if (measured != null) {
      return (point: measured, source: PointSource.diveComputer);
    }
    final photo = photoFixes[dive.id];
    if (photo != null) return (point: photo.location, source: PointSource.photo);
    return null;
  }

  /// Computes proposals for [dives]. Performs NO database writes.
  Future<List<MatchProposal>> computeProposals(List<Dive> dives) async {
    _userSites = (await _siteRepository.getAllSites(
      diverId: diverId,
    )).where((s) => s.location != null).toList();

    Map<String, PhotoGpsPoint> photoFixes = const {};
    try {
      photoFixes = await _mediaRepository.getBestPhotoGpsForDives([
        for (final d in dives) d.id,
      ]);
    } catch (e, stackTrace) {
      // Dive-computer points still match; only photo-only dives drop out.
      _log.error('Photo GPS lookup failed', error: e, stackTrace: stackTrace);
    }

    final proposals = <MatchProposal>[];
    for (final dive in dives) {
      final resolved = _pointFor(dive, photoFixes);
      if (resolved == null) continue;
      final point = resolved.point;
      // ... existing body unchanged from `final bundled = await _apiService.searchNearby(` ...
```

(`typedef` cannot sit inside a class in Dart; put `typedef _ResolvedPoint = ...` at file top level next to `TransactionRunner`. Import `photo_gps_point_selector.dart` for `PhotoGpsPoint`.)

In the `proposals.add(switch (outcome) { ... })` expression add `point: point, pointSource: resolved.source,` to all three `MatchProposal(...)` constructions.

In `site_match_review_notifier.dart` `_init`, add `mediaRepository: _ref.read(mediaRepositoryProvider),` to the `SiteMatchingService(` call and import `package:submersion/features/media/presentation/providers/media_providers.dart`.

In `site_match_review_page.dart` `_MapPanel.build`, replace `final point = p?.dive.entryLocation ?? p?.dive.exitLocation;` with `final point = p?.point;` so photo-sourced proposals get a map.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: PASS.
Run: `flutter test test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart`
Expected: PASS (the real `MediaRepository` runs against the test DB and returns an empty map).
Run: `flutter test test/features/dive_sites/presentation/pages/site_match_review_page_test.dart`
Expected: PASS. If the map-panel tests assert on a rendered map for `_dive(7)`, update `_dive` in that test to also pass `point: const GeoPoint(0, 0)` on the seeded `MatchProposal`s.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_sites test/features/dive_sites
flutter analyze lib/features/dive_sites test/features/dive_sites
git add lib/features/dive_sites test/features/dive_sites
git commit -m "feat(sites): photo GPS as a fallback point source for site matching"
```

---

### Task 7: Locate the current site (third apply mode) and the altitude pass

**Files:**
- Modify: `lib/features/dive_sites/data/services/site_matching_service.dart`
- Test: `test/features/dive_sites/data/services/site_matching_service_test.dart`

**Interfaces:**
- Produces:
  - `MatchCandidateView.isCurrentSite` (`bool`, default false); the current-site candidate id is `'current:<siteId>'` and its `distanceMeters` is 0.
  - `ApplyResult.sitesLocated` (int).
  - Constructor gains `Future<double?> Function(GeoPoint point)? fetchElevation` (null = no altitude pass).
  - `_applyOne` for a current-site candidate calls `SiteRepository.updateSiteCoordinates(siteId, point)`.
  - After the transaction, every site that gained coordinates in this pass and has `altitude == null` gets `updateSiteAltitude` with the fetched value; failures are ignored.

- [ ] **Step 1: Write the failing tests**

```dart
Dive _diveWithBareSite(String id, DiveSite site, {GeoPoint? gps}) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: gps,
  site: site,
);

const _bareSite = DiveSite(id: 'bare', name: 'Typed Twice');
```

```dart
  group('current site without coordinates', () {
    setUp(() {
      when(
        sites.updateSiteCoordinates(any, any, altitude: anyNamed('altitude')),
      ).thenAnswer((_) async {});
      when(sites.updateSiteAltitude(any, any)).thenAnswer((_) async {});
    });

    test('is the clear recommendation when no located site is nearby', () async {
      final proposals = await service().computeProposals([
        _diveWithBareSite('d1', _bareSite, gps: _eastMeters(0)),
      ]);
      final p = proposals.single;
      expect(p.status, ProposalStatus.clear);
      expect(p.recommendedCandidateId, 'current:bare');
      expect(p.candidates.first.isCurrentSite, isTrue);
      expect(p.candidates.first.name, 'Typed Twice');
    });

    test('goes to review when a located user site is within the inner radius', () async {
      const neighbour = DiveSite(
        id: 's1',
        name: 'Blue Hole',
        location: GeoPoint(0, 0),
      );
      when(
        sites.getAllSites(diverId: anyNamed('diverId')),
      ).thenAnswer((_) async => const [neighbour]);
      final proposals = await service().computeProposals([
        _diveWithBareSite('d1', _bareSite, gps: _eastMeters(40)),
      ]);
      final p = proposals.single;
      expect(p.status, ProposalStatus.review);
      expect(p.candidates.map((c) => c.id), ['current:bare', 's1']);
    });

    test('applying the current-site candidate patches coordinates only', () async {
      final s = service();
      await s.computeProposals([
        _diveWithBareSite('d1', _bareSite, gps: _eastMeters(0)),
      ]);
      final result = await s.applyConfirmed([
        const ConfirmedMatch('d1', 'current:bare'),
      ]);
      expect(result.sitesLocated, 1);
      expect(result.divesLinked, 1);
      verify(sites.updateSiteCoordinates('bare', _eastMeters(0))).called(1);
      verifyNever(sites.updateSite(any));
      verifyNever(dives.setSite(any, any));
    });

    test('the altitude pass runs after apply for sites that gained coordinates', () async {
      final s = SiteMatchingService(
        siteRepository: sites,
        apiService: api,
        diveRepository: dives,
        mediaRepository: media,
        diverId: 'diver-1',
        thresholds: SiteMatchSensitivity.balanced.thresholds,
        runInTransaction: (body) => body(),
        fetchElevation: (_) async => 12.0,
      );
      await s.computeProposals([
        _diveWithBareSite('d1', _bareSite, gps: _eastMeters(0)),
      ]);
      await s.applyConfirmed([const ConfirmedMatch('d1', 'current:bare')]);
      verify(sites.updateSiteAltitude('bare', 12.0)).called(1);
    });

    test('an elevation failure does not fail the apply', () async {
      final s = SiteMatchingService(
        siteRepository: sites,
        apiService: api,
        diveRepository: dives,
        mediaRepository: media,
        diverId: 'diver-1',
        thresholds: SiteMatchSensitivity.balanced.thresholds,
        runInTransaction: (body) => body(),
        fetchElevation: (_) async => throw StateError('offline'),
      );
      await s.computeProposals([
        _diveWithBareSite('d1', _bareSite, gps: _eastMeters(0)),
      ]);
      final result = await s.applyConfirmed([
        const ConfirmedMatch('d1', 'current:bare'),
      ]);
      expect(result.sitesLocated, 1);
      verifyNever(sites.updateSiteAltitude(any, any));
    });
  });
```

Also update the existing `applyConfirmed` group's expectations where `ApplyResult` is constructed or compared (none construct it directly; `sitesLocated` is additive).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: compile FAIL on `isCurrentSite`, `sitesLocated`, `fetchElevation`.

- [ ] **Step 3: Implement**

`MatchCandidateView`: add `final bool isCurrentSite;` with `this.isCurrentSite = false,` in the constructor.

`ApplyResult`:

```dart
class ApplyResult {
  final int divesLinked;
  final int sitesCreated;
  final int sitesLocated;
  const ApplyResult({
    required this.divesLinked,
    required this.sitesCreated,
    this.sitesLocated = 0,
  });
}
```

`_CandidateRef`:

```dart
class _CandidateRef {
  final DiveSite? existing; // link the dive to this site
  final ExternalDiveSite? bundled; // materialise, then link
  final DiveSite? currentSite; // keep the dive's site, give it coordinates
  const _CandidateRef.existing(this.existing)
    : bundled = null,
      currentSite = null;
  const _CandidateRef.bundled(this.bundled)
    : existing = null,
      currentSite = null;
  const _CandidateRef.currentSite(this.currentSite)
    : existing = null,
      bundled = null;
}
```

Constructor: add `this.fetchElevation,` and the field `final Future<double?> Function(GeoPoint point)? fetchElevation;`. Add `static String currentSiteCandidateId(String siteId) => 'current:$siteId';` and per-apply bookkeeping `final Map<String, GeoPoint> _locatedThisPass = {};` (site id to point).

In `computeProposals`, after `_refsByDive[dive.id] = refs;` and the ranking, insert the current-site branch before the `switch (outcome)`:

```dart
      final bareSite = dive.site;
      if (bareSite != null && !bareSite.hasCoordinates) {
        final currentId = currentSiteCandidateId(bareSite.id);
        refs[currentId] = _CandidateRef.currentSite(bareSite);
        final currentView = MatchCandidateView(
          id: currentId,
          name: bareSite.name,
          isExisting: true,
          isCurrentSite: true,
          distanceMeters: 0,
          location: point,
          country: bareSite.country,
          region: bareSite.region,
        );
        // A located user site within the inner radius is a probable
        // duplicate: let the diver choose between locating this site and
        // relinking the dive. Otherwise locating the current site is clear.
        final duplicateNearby = ranked.any(
          (r) =>
              r.candidate.isExisting &&
              r.distanceMeters <= thresholds.innerRadiusMeters,
        );
        proposals.add(
          MatchProposal(
            dive: dive,
            status: duplicateNearby
                ? ProposalStatus.review
                : ProposalStatus.clear,
            candidates: [currentView, ...views],
            recommendedCandidateId: duplicateNearby ? null : currentId,
            point: point,
            pointSource: resolved.source,
          ),
        );
        continue;
      }
```

`applyConfirmed` and `_applyOne`:

```dart
  Future<ApplyResult> applyConfirmed(List<ConfirmedMatch> confirmed) async {
    _createdByExternalId.clear();
    _locatedThisPass.clear();
    var linked = 0;
    var created = 0;
    var located = 0;
    await _runInTransaction(() async {
      for (final c in confirmed) {
        final ref = _refsByDive[c.diveId]?[c.candidateId];
        if (ref == null) continue;
        final outcome = await _applyOne(c.diveId, ref);
        linked++;
        if (outcome == _ApplyOutcome.created) created++;
        if (outcome == _ApplyOutcome.located) located++;
      }
    });
    await _fillAltitudes();
    return ApplyResult(
      divesLinked: linked,
      sitesCreated: created,
      sitesLocated: located,
    );
  }

  /// Best-effort altitude for every site that gained coordinates in this
  /// pass. Runs after the transaction commits so a network stall can never
  /// hold a DB lock, and never throws.
  Future<void> _fillAltitudes() async {
    final fetch = fetchElevation;
    if (fetch == null) return;
    for (final entry in _locatedThisPass.entries) {
      try {
        final meters = await fetch(entry.value);
        if (meters != null) {
          await _siteRepository.updateSiteAltitude(entry.key, meters);
        }
      } catch (e, stackTrace) {
        _log.warning(
          'Altitude lookup failed for site ${entry.key}',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<_ApplyOutcome> _applyOne(String diveId, _CandidateRef ref) async {
    if (ref.currentSite != null) {
      final site = ref.currentSite!;
      final point = _refsByDive[diveId] == null
          ? null
          : _pointByDive[diveId];
      if (point == null) return _ApplyOutcome.linked;
      await _siteRepository.updateSiteCoordinates(site.id, point);
      if (site.altitude == null) _locatedThisPass[site.id] = point;
      return _ApplyOutcome.located;
    }
    if (ref.existing != null) {
      await _diveRepository.setSite(diveId, ref.existing!.id);
      return _ApplyOutcome.linked;
    }
    // ... bundled branch as before; on the materialise path add
    //   if (createdSite.altitude == null) _locatedThisPass[createdSite.id] = point;
    // and return _ApplyOutcome.created / _ApplyOutcome.linked instead of true / false.
  }
```

Add `enum _ApplyOutcome { linked, created, located }` at file top level, and a `final Map<String, GeoPoint> _pointByDive = {};` that `computeProposals` fills with `_pointByDive[dive.id] = point;` right after resolving the point (the current-site apply needs the dive's point, and the ref only carries the site). If `LoggerService` has no `warning`, use whatever level it exposes between info and error.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_sites test/features/dive_sites
flutter analyze lib/features/dive_sites test/features/dive_sites
git add lib/features/dive_sites/data/services/site_matching_service.dart test/features/dive_sites/data/services/site_matching_service_test.dart
git commit -m "feat(sites): locate a coordinate-less current site from the review flow"
```

---

### Task 8: `createAndLink` and the notifier's `createSiteHere`

**Files:**
- Modify: `lib/features/dive_sites/data/services/site_matching_service.dart`
- Modify: `lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart`
- Test: `test/features/dive_sites/data/services/site_matching_service_test.dart`, `test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart`

**Interfaces:**
- Produces:
  - `Future<DiveSite> SiteMatchingService.createAndLink(String diveId, DiveSite site)`: `createSite(site.copyWith(diverId: diverId))`, `setSite(diveId, created.id)`, best-effort altitude, returns the created site. A previous coordinate-less site on the dive is left untouched.
  - `Future<DiveSite?> SiteMatchReviewNotifier.createSiteHere(String diveId, DiveSite site)`: calls the above, drops that dive's proposal and selection from state, refreshes the dive and site lists; returns null on failure.

- [ ] **Step 1: Write the failing service test**

```dart
  group('createAndLink', () {
    setUp(() {
      when(sites.createSite(any)).thenAnswer((inv) async {
        final s = inv.positionalArguments.first as DiveSite;
        return s.copyWith(id: 'new-${s.name}');
      });
      when(sites.updateSiteAltitude(any, any)).thenAnswer((_) async {});
    });

    test('creates the site under the diver, links the dive, fills altitude', () async {
      final s = SiteMatchingService(
        siteRepository: sites,
        apiService: api,
        diveRepository: dives,
        mediaRepository: media,
        diverId: 'diver-1',
        thresholds: SiteMatchSensitivity.balanced.thresholds,
        runInTransaction: (body) => body(),
        fetchElevation: (_) async => 3.0,
      );
      final created = await s.createAndLink(
        'd1',
        const DiveSite(id: 'x', name: 'Wall', location: GeoPoint(1, 2)),
      );
      expect(created.id, 'new-Wall');
      final saved = verify(sites.createSite(captureAny)).captured.single as DiveSite;
      expect(saved.diverId, 'diver-1');
      verify(dives.setSite('d1', 'new-Wall')).called(1);
      verify(sites.updateSiteAltitude('new-Wall', 3.0)).called(1);
    });
  });
```

- [ ] **Step 2: Write the failing notifier test**

In `site_match_review_notifier_test.dart`, inside `main()` after the existing tests (the `makeContainer` helper already stubs everything `confirm()` needs; add `when(sites.createSite(any)).thenAnswer((inv) async => (inv.positionalArguments.first as DiveSite).copyWith(id: 'created'));` and `when(sites.updateSiteAltitude(any, any)).thenAnswer((_) async {});` inside `makeContainer` beside the other `sites` stubs):

```dart
  test('createSiteHere links the dive and drops its proposal', () async {
    final container = makeContainer([_dive('d1', _eastMeters(0))]);
    await _settle();
    final notifier = container.read(siteMatchReviewProvider(null).notifier);
    expect(container.read(siteMatchReviewProvider(null)).proposals, hasLength(1));

    final created = await notifier.createSiteHere(
      'd1',
      const DiveSite(id: '', name: 'Wall', location: GeoPoint(0, 0)),
    );

    expect(created?.id, 'created');
    verify(dives.setSite('d1', 'created')).called(1);
    final state = container.read(siteMatchReviewProvider(null));
    expect(state.proposals, isEmpty);
    expect(state.selections, isEmpty);
  });
```

- [ ] **Step 3: Run both to verify failure**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: compile FAIL on `createAndLink`.
Run: `flutter test test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart`
Expected: compile FAIL on `createSiteHere`.

- [ ] **Step 4: Implement the service method**

```dart
  /// Creates [site] for this diver, links [diveId] to it, and fills the
  /// altitude best-effort. The single write path behind both the banner's
  /// "Create site" and the review page's "Create site here". A previous
  /// coordinate-less site on the dive is left as it was.
  Future<DiveSite> createAndLink(String diveId, DiveSite site) async {
    late DiveSite created;
    await _runInTransaction(() async {
      created = await _siteRepository.createSite(
        site.copyWith(diverId: diverId),
      );
      await _diveRepository.setSite(diveId, created.id);
    });
    _locatedThisPass.clear();
    final point = created.location;
    if (point != null && created.altitude == null) {
      _locatedThisPass[created.id] = point;
    }
    await _fillAltitudes();
    return created;
  }
```

- [ ] **Step 5: Implement the notifier method**

In `SiteMatchReviewNotifier`:

```dart
  /// Creates a brand-new site at the dive's point and links the dive right
  /// away (a created site is a named user object, so it is not held as a
  /// pending selection). Returns null on failure; the page shows a snackbar.
  Future<DiveSite?> createSiteHere(String diveId, DiveSite site) async {
    final service = _service;
    if (service == null) return null;
    try {
      final created = await service.createAndLink(diveId, site);
      if (!mounted) return created;
      final selections = Map<String, String>.from(state.selections)
        ..remove(diveId);
      state = state.copyWith(
        proposals: [
          for (final p in state.proposals)
            if (p.dive.id != diveId) p,
        ],
        selections: selections,
        focusedDiveId: state.focusedDiveId == diveId
            ? null
            : state.focusedDiveId,
      );
      await _ref.read(diveListNotifierProvider.notifier).refresh();
      await _ref.read(paginatedDiveListProvider.notifier).refresh();
      _ref.invalidate(diveProvider(diveId));
      await _ref.read(siteListNotifierProvider.notifier).refresh();
      return created;
    } catch (e) {
      return null;
    }
  }
```

Import `package:submersion/features/dive_sites/domain/entities/dive_site.dart`. `SiteMatchReviewState.copyWith` currently cannot clear `focusedDiveId` (it uses `??`); pass the existing value when the focused dive is not the created one and accept that clearing is a no-op, or add a `bool clearFocus = false` parameter to `copyWith` that sets `focusedDiveId` to null when true. Use the parameter; it is three lines.

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: PASS.
Run: `flutter test test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/features/dive_sites test/features/dive_sites
flutter analyze lib/features/dive_sites test/features/dive_sites
git add lib/features/dive_sites test/features/dive_sites
git commit -m "feat(sites): create-and-link a new site from a dive's point"
```

---

### Task 9: Localized strings (all 11 locales)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` plus `app_{de,es,fr,it,nl,pt,zh,ar,he,hu}.arb`
- Generated: `lib/l10n/arb/app_localizations*.dart` (committed)

**Interfaces:**
- Produces the `AppLocalizations` getters used by Tasks 11 through 16. Existing keys reused unchanged: `media_gpsBanner_createSiteButton`, `media_gpsBanner_dismissTooltip`, `media_gpsBanner_coordinates`, `diveLog_edit_createdSite`, `diveLog_edit_addedGps`, `siteMatchReview_awayMeters`, `siteMatchReview_applyError`, `diveSites_edit_field_country_label`, `diveSites_edit_field_region_label`, `diveSites_edit_field_city_label`.

- [ ] **Step 1: Add the keys to `app_en.arb`**

Place each key in the alphabetical neighbourhood of its prefix; `@` metadata entries go only in `app_en.arb` (the template), beside the file's other metadata:

```json
  "siteSuggestion_titlePhoto": "Location found in photos",
  "siteSuggestion_titleDiveComputer": "Location from dive computer",
  "siteSuggestion_assignButton": "Assign {name}",
  "@siteSuggestion_assignButton": { "placeholders": { "name": { "type": "Object" } } },
  "siteSuggestion_chooseNearbyButton": "Choose nearby site ({count})",
  "@siteSuggestion_chooseNearbyButton": { "placeholders": { "count": { "type": "int" } } },
  "siteSuggestion_addLocationButton": "Add location to {name}",
  "@siteSuggestion_addLocationButton": { "placeholders": { "name": { "type": "Object" } } },
  "siteSuggestion_assignedSnack": "Assigned {name}",
  "@siteSuggestion_assignedSnack": { "placeholders": { "name": { "type": "Object" } } },
  "siteMatchReview_sourcePhoto": "from photo",
  "siteMatchReview_sourceDiveComputer": "from dive computer",
  "siteMatchReview_currentSiteCard": "Add location to this site",
  "siteMatchReview_createHereButton": "Create site here",
  "mediaImport_offerSiteReview": "{count} dives could get a site from their photos",
  "@mediaImport_offerSiteReview": { "placeholders": { "count": { "type": "int" } } },
  "mediaImport_reviewSitesAction": "Review sites",
  "filesTab_linkedItems": "{count, plural, =1{Linked 1 item} other{Linked {count} items}}",
  "@filesTab_linkedItems": { "placeholders": { "count": { "type": "int" } } },
  "filesTab_attachedToSite": "{count, plural, =1{Attached 1 item to this site} other{Attached {count} items to this site}}",
  "@filesTab_attachedToSite": { "placeholders": { "count": { "type": "int" } } },
  "filesTab_undo": "Undo",
```

And change the existing `siteMatchReview_appliedSnack` to three placeholders:

```json
  "siteMatchReview_appliedSnack": "Linked {dives} dives · added {sites} sites · located {located} sites",
  "@siteMatchReview_appliedSnack": {
    "placeholders": {
      "dives": { "type": "int" },
      "sites": { "type": "int" },
      "located": { "type": "int" }
    }
  },
```

- [ ] **Step 2: Add the translations to the other ten ARBs**

For `siteMatchReview_appliedSnack`, keep each locale's existing text and append the suffix shown. Every other key is the full value.

`siteSuggestion_titlePhoto`
- de: `Standort in Fotos gefunden` · es: `Ubicación encontrada en las fotos` · fr: `Position trouvée dans les photos` · it: `Posizione trovata nelle foto` · nl: `Locatie gevonden in foto's` · pt: `Localização encontrada nas fotos` · zh: `在照片中找到位置` · ar: `تم العثور على الموقع في الصور` · he: `נמצא מיקום בתמונות` · hu: `Helyszín található a fotókban`

`siteSuggestion_titleDiveComputer`
- de: `Standort vom Tauchcomputer` · es: `Ubicación del ordenador de buceo` · fr: `Position de l'ordinateur de plongée` · it: `Posizione dal computer subacqueo` · nl: `Locatie van duikcomputer` · pt: `Localização do computador de mergulho` · zh: `来自潜水电脑的位置` · ar: `الموقع من كمبيوتر الغوص` · he: `מיקום ממחשב הצלילה` · hu: `Helyszín a búvárkomputerből`

`siteSuggestion_assignButton`
- de: `{name} zuweisen` · es: `Asignar {name}` · fr: `Attribuer {name}` · it: `Assegna {name}` · nl: `{name} toewijzen` · pt: `Atribuir {name}` · zh: `指定 {name}` · ar: `تعيين {name}` · he: `שיוך {name}` · hu: `{name} hozzárendelése`

`siteSuggestion_chooseNearbyButton`
- de: `Nahegelegenen Platz wählen ({count})` · es: `Elegir sitio cercano ({count})` · fr: `Choisir un site proche ({count})` · it: `Scegli sito vicino ({count})` · nl: `Nabijgelegen stek kiezen ({count})` · pt: `Escolher local próximo ({count})` · zh: `选择附近潜点 ({count})` · ar: `اختيار موقع قريب ({count})` · he: `בחירת אתר קרוב ({count})` · hu: `Közeli helyszín választása ({count})`

`siteSuggestion_addLocationButton`
- de: `Standort zu {name} hinzufügen` · es: `Añadir ubicación a {name}` · fr: `Ajouter la position à {name}` · it: `Aggiungi posizione a {name}` · nl: `Locatie toevoegen aan {name}` · pt: `Adicionar localização a {name}` · zh: `为 {name} 添加位置` · ar: `إضافة الموقع إلى {name}` · he: `הוספת מיקום ל-{name}` · hu: `Helyszín hozzáadása: {name}`

`siteSuggestion_assignedSnack`
- de: `{name} zugewiesen` · es: `Asignado {name}` · fr: `{name} attribué` · it: `Assegnato {name}` · nl: `{name} toegewezen` · pt: `{name} atribuído` · zh: `已指定 {name}` · ar: `تم تعيين {name}` · he: `{name} שויך` · hu: `{name} hozzárendelve`

`siteMatchReview_sourcePhoto`
- de: `aus Foto` · es: `de foto` · fr: `depuis photo` · it: `da foto` · nl: `uit foto` · pt: `da foto` · zh: `来自照片` · ar: `من صورة` · he: `מתמונה` · hu: `fotóból`

`siteMatchReview_sourceDiveComputer`
- de: `vom Tauchcomputer` · es: `del ordenador de buceo` · fr: `de l'ordinateur de plongée` · it: `dal computer subacqueo` · nl: `van duikcomputer` · pt: `do computador de mergulho` · zh: `来自潜水电脑` · ar: `من كمبيوتر الغوص` · he: `ממחשב הצלילה` · hu: `búvárkomputerből`

`siteMatchReview_currentSiteCard`
- de: `Standort zu diesem Platz hinzufügen` · es: `Añadir ubicación a este sitio` · fr: `Ajouter la position à ce site` · it: `Aggiungi posizione a questo sito` · nl: `Locatie toevoegen aan deze stek` · pt: `Adicionar localização a este local` · zh: `为此潜点添加位置` · ar: `إضافة الموقع إلى هذا الموقع` · he: `הוספת מיקום לאתר זה` · hu: `Helyszín hozzáadása ehhez a helyhez`

`siteMatchReview_createHereButton`
- de: `Platz hier erstellen` · es: `Crear sitio aquí` · fr: `Créer un site ici` · it: `Crea sito qui` · nl: `Stek hier aanmaken` · pt: `Criar local aqui` · zh: `在此创建潜点` · ar: `إنشاء موقع هنا` · he: `יצירת אתר כאן` · hu: `Helyszín létrehozása itt`

`siteMatchReview_appliedSnack` (append to the existing value)
- de: ` · {located} Plätze verortet` · es: ` · {located} sitios ubicados` · fr: ` · {located} sites localisés` · it: ` · {located} siti localizzati` · nl: ` · {located} stekken gelokaliseerd` · pt: ` · {located} locais localizados` · zh: ` · 已定位 {located} 个潜点` · ar: ` · تم تحديد موقع {located} مواقع` · he: ` · {located} אתרים מוקמו` · hu: ` · {located} helyszín elhelyezve`

`mediaImport_offerSiteReview`
- de: `{count} Tauchgänge könnten aus ihren Fotos einen Platz erhalten` · es: `{count} inmersiones podrían obtener un sitio a partir de sus fotos` · fr: `{count} plongées pourraient obtenir un site à partir de leurs photos` · it: `{count} immersioni potrebbero ottenere un sito dalle foto` · nl: `{count} duiken kunnen een stek krijgen uit hun foto's` · pt: `{count} mergulhos podem obter um local a partir das fotos` · zh: `{count} 次潜水可根据照片获得潜点` · ar: `يمكن لـ {count} غوصات الحصول على موقع من صورها` · he: `{count} צלילות יכולות לקבל אתר מהתמונות שלהן` · hu: `{count} merülés kaphat helyszínt a fotóiból`

`mediaImport_reviewSitesAction`
- de: `Plätze prüfen` · es: `Revisar sitios` · fr: `Vérifier les sites` · it: `Rivedi siti` · nl: `Stekken bekijken` · pt: `Rever locais` · zh: `查看潜点` · ar: `مراجعة المواقع` · he: `סקירת אתרים` · hu: `Helyszínek áttekintése`

`filesTab_linkedItems`
- de: `{count, plural, =1{1 Element verknüpft} other{{count} Elemente verknüpft}}`
- es: `{count, plural, =1{1 elemento vinculado} other{{count} elementos vinculados}}`
- fr: `{count, plural, =1{1 élément lié} other{{count} éléments liés}}`
- it: `{count, plural, =1{1 elemento collegato} other{{count} elementi collegati}}`
- nl: `{count, plural, =1{1 item gekoppeld} other{{count} items gekoppeld}}`
- pt: `{count, plural, =1{1 item vinculado} other{{count} itens vinculados}}`
- zh: `{count, plural, other{已关联 {count} 个项目}}`
- ar: `{count, plural, =1{تم ربط عنصر واحد} other{تم ربط {count} عناصر}}`
- he: `{count, plural, =1{פריט אחד קושר} other{{count} פריטים קושרו}}`
- hu: `{count, plural, =1{1 elem összekapcsolva} other{{count} elem összekapcsolva}}`

`filesTab_attachedToSite`
- de: `{count, plural, =1{1 Element an diesen Platz angehängt} other{{count} Elemente an diesen Platz angehängt}}`
- es: `{count, plural, =1{1 elemento adjuntado a este sitio} other{{count} elementos adjuntados a este sitio}}`
- fr: `{count, plural, =1{1 élément joint à ce site} other{{count} éléments joints à ce site}}`
- it: `{count, plural, =1{1 elemento allegato a questo sito} other{{count} elementi allegati a questo sito}}`
- nl: `{count, plural, =1{1 item aan deze stek gekoppeld} other{{count} items aan deze stek gekoppeld}}`
- pt: `{count, plural, =1{1 item anexado a este local} other{{count} itens anexados a este local}}`
- zh: `{count, plural, other{已将 {count} 个项目附加到此潜点}}`
- ar: `{count, plural, =1{تم إرفاق عنصر واحد بهذا الموقع} other{تم إرفاق {count} عناصر بهذا الموقع}}`
- he: `{count, plural, =1{פריט אחד צורף לאתר זה} other{{count} פריטים צורפו לאתר זה}}`
- hu: `{count, plural, =1{1 elem csatolva ehhez a helyhez} other{{count} elem csatolva ehhez a helyhez}}`

`filesTab_undo`
- de: `Rückgängig` · es: `Deshacer` · fr: `Annuler` · it: `Annulla` · nl: `Ongedaan maken` · pt: `Desfazer` · zh: `撤销` · ar: `تراجع` · he: `ביטול` · hu: `Visszavonás`

- [ ] **Step 3: Regenerate and fix the one existing caller**

```bash
flutter gen-l10n
```
`site_match_review_page.dart` line 33 calls `siteMatchReview_appliedSnack(result.divesLinked, result.sitesCreated)`; add the third argument `result.sitesLocated`. Then:

```bash
flutter analyze lib/l10n lib/features/dive_sites
```
Expected: no issues. If `gen-l10n` reports a key present in the template but missing from a locale, add it; no key may be missing from any locale.

- [ ] **Step 4: Run the review page test and commit**

Run: `flutter test test/features/dive_sites/presentation/pages/site_match_review_page_test.dart`
Expected: PASS (`Linked 2 dives` is still a substring of the new snackbar).

```bash
dart format lib/l10n lib/features/dive_sites
git add lib/l10n/arb lib/features/dive_sites/presentation/pages/site_match_review_page.dart
git commit -m "l10n: site suggestion, review page, import prompt, and files tab strings"
```

---

### Task 10: Suggestion providers

**Files:**
- Create: `lib/features/dive_sites/presentation/providers/site_suggestion_providers.dart`
- Modify: `lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart:85-98` (use the factory)
- Test: `test/features/dive_sites/presentation/providers/site_suggestion_providers_test.dart`, `test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart`

**Interfaces:**
- Produces:
  - `final siteMatchingServiceFactoryProvider = Provider<SiteMatchingService Function(String? diverId)>`: builds the service from `siteRepositoryProvider`, `diveSiteApiServiceProvider`, `diveRepositoryProvider`, `mediaRepositoryProvider`, `settingsProvider.siteMatchSensitivity.thresholds`, and `elevationServiceProvider` as `fetchElevation`.
  - `class SiteSuggestion { final MatchProposal proposal; final SiteMatchingService service; GeoPoint get point; PointSource get pointSource; }` (the service instance is carried because `applyConfirmed` needs the refs `computeProposals` cached).
  - `final siteSuggestionForDiveProvider = FutureProvider.autoDispose.family<SiteSuggestion?, String>`: null when the dive is not eligible (located site, dismissed, no point); re-evaluates on media, dive, and site table ticks.

- [ ] **Step 1: Write the failing provider test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

import '../../../../helpers/mock_providers.dart';
import 'site_suggestion_providers_test.mocks.dart';

@GenerateMocks([SiteRepository, DiveSiteApiService, DiveRepository, MediaRepository])
void main() {
  late MockSiteRepository sites;
  late MockDiveSiteApiService api;
  late MockDiveRepository dives;
  late MockMediaRepository media;

  ProviderContainer makeContainer({required List<Dive> eligible}) {
    sites = MockSiteRepository();
    api = MockDiveSiteApiService();
    dives = MockDiveRepository();
    media = MockMediaRepository();
    when(
      dives.getDivesNeedingSiteMatch(
        diverId: anyNamed('diverId'),
        limitToIds: anyNamed('limitToIds'),
      ),
    ).thenAnswer((_) async => eligible);
    when(dives.watchDivesChanges()).thenAnswer((_) => const Stream<void>.empty());
    when(sites.watchSitesChanges()).thenAnswer((_) => const Stream<void>.empty());
    when(media.watchMediaChanges()).thenAnswer((_) => const Stream<void>.empty());
    when(media.getBestPhotoGpsForDives(any)).thenAnswer((_) async => const {});
    when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer((_) async => const []);
    when(
      api.searchNearby(
        latitude: anyNamed('latitude'),
        longitude: anyNamed('longitude'),
        radiusKm: anyNamed('radiusKm'),
      ),
    ).thenAnswer((_) async => const DiveSiteSearchResult(sites: []));
    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(dives),
        siteRepositoryProvider.overrideWithValue(sites),
        diveSiteApiServiceProvider.overrideWithValue(api),
        mediaRepositoryProvider.overrideWithValue(media),
        validatedCurrentDiverIdProvider.overrideWith((ref) => 'diver-1'),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        weatherHttpClientProvider.overrideWithValue(
          MockClient((_) async => http.Response('', 500)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('returns null when the dive is not eligible', () async {
    final container = makeContainer(eligible: const []);
    expect(await container.read(siteSuggestionForDiveProvider('d1').future), isNull);
  });

  test('returns a proposal with its service when eligible', () async {
    final container = makeContainer(
      eligible: [
        Dive(
          id: 'd1',
          diveNumber: 1,
          dateTime: DateTime(2026, 1, 1),
          maxDepth: 18,
          entryLocation: const GeoPoint(0, 0),
        ),
      ],
    );
    final s = await container.read(siteSuggestionForDiveProvider('d1').future);
    expect(s, isNotNull);
    expect(s!.proposal.status, ProposalStatus.none);
    expect(s.point, const GeoPoint(0, 0));
    expect(s.pointSource, PointSource.diveComputer);
    expect(s.service, isA<SiteMatchingService>());
  });

  test('the factory wires the sensitivity thresholds', () {
    final container = makeContainer(eligible: const []);
    final service = container.read(siteMatchingServiceFactoryProvider)('diver-1');
    expect(service.thresholds, MockSettingsNotifier().state.siteMatchSensitivity.thresholds);
  });
}
```

- [ ] **Step 2: Generate mocks and run to verify failure**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/dive_sites/presentation/providers/site_suggestion_providers_test.dart
```
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Create the providers file**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

/// Builds a [SiteMatchingService] for [diverId] from the app's providers.
/// The review notifier and the per-dive suggestion share it, so a widget
/// test can override one provider to fake the whole matching pipeline.
final siteMatchingServiceFactoryProvider =
    Provider<SiteMatchingService Function(String? diverId)>((ref) {
      return (diverId) => SiteMatchingService(
        siteRepository: ref.read(siteRepositoryProvider),
        apiService: ref.read(diveSiteApiServiceProvider),
        diveRepository: ref.read(diveRepositoryProvider),
        mediaRepository: ref.read(mediaRepositoryProvider),
        diverId: diverId,
        thresholds: ref.read(settingsProvider).siteMatchSensitivity.thresholds,
        fetchElevation: (point) => ref
            .read(elevationServiceProvider)
            .fetchElevation(
              latitude: point.latitude,
              longitude: point.longitude,
            ),
      );
    });

/// One dive's site suggestion, with the service instance that computed it
/// (its apply methods rely on refs cached during computeProposals).
class SiteSuggestion {
  const SiteSuggestion({required this.proposal, required this.service});
  final MatchProposal proposal;
  final SiteMatchingService service;
  GeoPoint get point => proposal.point!;
  PointSource get pointSource => proposal.pointSource;
}

/// The suggestion for [diveId], or null when the dive needs none: it has a
/// located site, the diver dismissed it, or there is no point to match.
/// Eligibility is the same repository predicate the batch review uses.
final siteSuggestionForDiveProvider = FutureProvider.autoDispose
    .family<SiteSuggestion?, String>((ref, diveId) async {
      final diveRepo = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(diveRepo.watchDivesChanges());
      ref.invalidateSelfWhen(ref.watch(siteRepositoryProvider).watchSitesChanges());
      ref.invalidateSelfWhen(ref.watch(mediaRepositoryProvider).watchMediaChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final dives = await diveRepo.getDivesNeedingSiteMatch(
        diverId: diverId,
        limitToIds: [diveId],
      );
      if (dives.isEmpty) return null;
      final service = ref.read(siteMatchingServiceFactoryProvider)(diverId);
      final proposals = await service.computeProposals(dives);
      if (proposals.isEmpty || proposals.single.point == null) return null;
      return SiteSuggestion(proposal: proposals.single, service: service);
    });
```

`invalidateSelfWhen` is the project's `Ref` extension used by `media_providers.dart`; import whatever file declares it if the barrel does not export it (grep `invalidateSelfWhen` in `lib/core/providers`).

- [ ] **Step 4: Point the notifier at the factory**

In `SiteMatchReviewNotifier._init`, replace the inline `SiteMatchingService(...)` construction with `_service = _ref.read(siteMatchingServiceFactoryProvider)(diverId);` and drop the now-unused imports. In `site_match_review_notifier_test.dart` `makeContainer`, add `weatherHttpClientProvider.overrideWithValue(MockClient((_) async => http.Response('', 500)))` (imports: `package:http/http.dart as http`, `package:http/testing.dart`, `.../weather/presentation/providers/weather_providers.dart`) so the elevation client is never real.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/dive_sites/presentation/providers/site_suggestion_providers_test.dart`
Expected: PASS.
Run: `flutter test test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/dive_sites test/features/dive_sites
flutter analyze lib/features/dive_sites test/features/dive_sites
git add lib/features/dive_sites test/features/dive_sites
git commit -m "feat(sites): per-dive site suggestion provider and service factory"
```

---

### Task 11: `SiteSuggestionBanner` (presentational)

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/site_suggestion_banner.dart`
- Test: `test/features/dive_log/presentation/widgets/site_suggestion_banner_test.dart`

**Interfaces:**
- Produces:

```dart
class SiteSuggestionBanner extends StatelessWidget {
  const SiteSuggestionBanner({
    super.key,
    required this.pointSource,        // PointSource
    required this.coordinates,        // pre-formatted by the caller's UnitFormatter
    required this.status,             // ProposalStatus
    required this.hasSite,            // dive.site != null (site without coordinates)
    required this.siteName,           // current site name, or the recommended candidate's name
    required this.candidateCount,     // candidates.length
    required this.recommendedDistanceMeters, // null unless status == clear && !hasSite
    required this.onAssign,           // VoidCallback?
    required this.onChooseNearby,     // VoidCallback?
    required this.onCreate,           // VoidCallback?
    required this.onAddLocation,      // VoidCallback?
    required this.onDismiss,          // VoidCallback
  });
}
```

Rendering table (primary button is `FilledButton.icon`, secondary is `OutlinedButton`, both inside an `OverflowBar` with `spacing: 8`):

| hasSite | status | Primary | Secondary |
| --- | --- | --- | --- |
| false | clear | `siteSuggestion_assignButton(siteName)` + ` · ` + `siteMatchReview_awayMeters(distance)` | `media_gpsBanner_createSiteButton` |
| false | review | `siteSuggestion_chooseNearbyButton(candidateCount)` | `media_gpsBanner_createSiteButton` |
| false | none | `media_gpsBanner_createSiteButton` | none |
| true | clear | `siteSuggestion_addLocationButton(siteName)` | none |
| true | review | `siteSuggestion_addLocationButton(siteName)` | `siteSuggestion_chooseNearbyButton(candidateCount - 1)` |

Title is `siteSuggestion_titlePhoto` or `siteSuggestion_titleDiveComputer`; the second line is `media_gpsBanner_coordinates(coordinates)`; the X uses `media_gpsBanner_dismissTooltip`.

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_banner.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';

import '../../../../helpers/test_app.dart';

void main() {
  Widget banner({
    required ProposalStatus status,
    required bool hasSite,
    PointSource source = PointSource.photo,
    int candidateCount = 1,
    double? distance,
    VoidCallback? onAssign,
    VoidCallback? onChooseNearby,
    VoidCallback? onCreate,
    VoidCallback? onAddLocation,
    VoidCallback? onDismiss,
    Locale? locale,
  }) => testApp(
    locale: locale ?? const Locale('en'),
    child: SiteSuggestionBanner(
      pointSource: source,
      coordinates: '20.5000, -87.2500',
      status: status,
      hasSite: hasSite,
      siteName: 'Blue Hole',
      candidateCount: candidateCount,
      recommendedDistanceMeters: distance,
      onAssign: onAssign,
      onChooseNearby: onChooseNearby,
      onCreate: onCreate,
      onAddLocation: onAddLocation,
      onDismiss: onDismiss ?? () {},
    ),
  );

  testWidgets('siteless clear: Assign primary, Create secondary', (tester) async {
    var assigned = false;
    var created = false;
    await tester.pumpWidget(banner(
      status: ProposalStatus.clear,
      hasSite: false,
      distance: 40,
      onAssign: () => assigned = true,
      onCreate: () => created = true,
    ));
    expect(find.text('Location found in photos'), findsOneWidget);
    expect(find.textContaining('Assign Blue Hole'), findsOneWidget);
    expect(find.textContaining('40 m away'), findsOneWidget);
    await tester.tap(find.textContaining('Assign Blue Hole'));
    expect(assigned, isTrue);
    await tester.tap(find.text('Create Site'));
    expect(created, isTrue);
  });

  testWidgets('siteless review: Choose nearby primary, Create secondary', (tester) async {
    var chose = false;
    await tester.pumpWidget(banner(
      status: ProposalStatus.review,
      hasSite: false,
      candidateCount: 3,
      onChooseNearby: () => chose = true,
      onCreate: () {},
    ));
    await tester.tap(find.text('Choose nearby site (3)'));
    expect(chose, isTrue);
    expect(find.text('Create Site'), findsOneWidget);
  });

  testWidgets('siteless none: Create only', (tester) async {
    await tester.pumpWidget(banner(status: ProposalStatus.none, hasSite: false, onCreate: () {}));
    expect(find.text('Create Site'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('site without coordinates, clear: Add location only', (tester) async {
    var added = false;
    await tester.pumpWidget(banner(
      status: ProposalStatus.clear,
      hasSite: true,
      source: PointSource.diveComputer,
      onAddLocation: () => added = true,
    ));
    expect(find.text('Location from dive computer'), findsOneWidget);
    await tester.tap(find.text('Add location to Blue Hole'));
    expect(added, isTrue);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('site without coordinates, review: Add location + Choose nearby', (tester) async {
    await tester.pumpWidget(banner(
      status: ProposalStatus.review,
      hasSite: true,
      candidateCount: 3,
      onAddLocation: () {},
      onChooseNearby: () {},
    ));
    expect(find.text('Add location to Blue Hole'), findsOneWidget);
    expect(find.text('Choose nearby site (2)'), findsOneWidget);
  });

  testWidgets('dismiss fires', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(banner(
      status: ProposalStatus.none,
      hasSite: false,
      onCreate: () {},
      onDismiss: () => dismissed = true,
    ));
    await tester.tap(find.byIcon(Icons.close));
    expect(dismissed, isTrue);
  });

  testWidgets('German at 360 dp does not overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(banner(
      status: ProposalStatus.review,
      hasSite: true,
      candidateCount: 3,
      onAddLocation: () {},
      onChooseNearby: () {},
      locale: const Locale('de'),
    ));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Blue Hole'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/site_suggestion_banner_test.dart`
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Create the banner**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Suggests a site for a dive from a GPS point (photo or dive computer).
/// Purely presentational: the caller resolves the proposal and wires the
/// actions (see SiteSuggestionCard). Which buttons appear depends on whether
/// the dive already has a (coordinate-less) site and on the match status.
class SiteSuggestionBanner extends StatelessWidget {
  const SiteSuggestionBanner({
    super.key,
    required this.pointSource,
    required this.coordinates,
    required this.status,
    required this.hasSite,
    required this.siteName,
    required this.candidateCount,
    required this.recommendedDistanceMeters,
    required this.onAssign,
    required this.onChooseNearby,
    required this.onCreate,
    required this.onAddLocation,
    required this.onDismiss,
  });

  final PointSource pointSource;
  final String coordinates;
  final ProposalStatus status;
  final bool hasSite;
  final String siteName;
  final int candidateCount;
  final double? recommendedDistanceMeters;
  final VoidCallback? onAssign;
  final VoidCallback? onChooseNearby;
  final VoidCallback? onCreate;
  final VoidCallback? onAddLocation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pointSource == PointSource.photo
                      ? l10n.siteSuggestion_titlePhoto
                      : l10n.siteSuggestion_titleDiveComputer,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant),
                tooltip: l10n.media_gpsBanner_dismissTooltip,
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.media_gpsBanner_coordinates(coordinates),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          OverflowBar(
            spacing: 8,
            overflowSpacing: 8,
            children: _actions(l10n),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(dynamic l10n) {
    final create = OutlinedButton.icon(
      onPressed: onCreate,
      icon: const Icon(Icons.add_location_alt, size: 18),
      label: Text(l10n.media_gpsBanner_createSiteButton),
    );
    Widget choose(int count) => OutlinedButton.icon(
      onPressed: onChooseNearby,
      icon: const Icon(Icons.map_outlined, size: 18),
      label: Text(l10n.siteSuggestion_chooseNearbyButton(count)),
    );
    if (hasSite) {
      final add = FilledButton.icon(
        onPressed: onAddLocation,
        icon: const Icon(Icons.edit_location_alt, size: 18),
        label: Text(l10n.siteSuggestion_addLocationButton(siteName)),
      );
      return switch (status) {
        ProposalStatus.review => [add, choose(candidateCount - 1)],
        _ => [add],
      };
    }
    return switch (status) {
      ProposalStatus.clear => [
        FilledButton.icon(
          onPressed: onAssign,
          icon: const Icon(Icons.push_pin_outlined, size: 18),
          label: Text(
            '${l10n.siteSuggestion_assignButton(siteName)} · '
            '${l10n.siteMatchReview_awayMeters((recommendedDistanceMeters ?? 0).round())}',
          ),
        ),
        create,
      ],
      ProposalStatus.review => [
        FilledButton.icon(
          onPressed: onChooseNearby,
          icon: const Icon(Icons.map_outlined, size: 18),
          label: Text(l10n.siteSuggestion_chooseNearbyButton(candidateCount)),
        ),
        create,
      ],
      ProposalStatus.none => [
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_location_alt, size: 18),
          label: Text(l10n.media_gpsBanner_createSiteButton),
        ),
      ],
    };
  }
}
```

Replace `dynamic l10n` with the concrete `AppLocalizations` type (import `package:submersion/l10n/arb/app_localizations.dart`); `dynamic` is shown only to keep the snippet short and must not be committed.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_log/presentation/widgets/site_suggestion_banner_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets test/features/dive_log/presentation/widgets
flutter analyze lib/features/dive_log/presentation/widgets test/features/dive_log/presentation/widgets
git add lib/features/dive_log/presentation/widgets/site_suggestion_banner.dart test/features/dive_log/presentation/widgets/site_suggestion_banner_test.dart
git commit -m "feat(dives): source-agnostic site suggestion banner"
```

---

### Task 12: `SiteSuggestionActions` and `SiteSuggestionCard`

**Files:**
- Create: `lib/features/dive_log/presentation/helpers/site_suggestion_actions.dart`
- Create: `lib/features/dive_log/presentation/widgets/site_suggestion_card.dart`
- Test: `test/features/dive_log/presentation/helpers/site_suggestion_actions_test.dart`, `test/features/dive_log/presentation/widgets/site_suggestion_card_test.dart`

**Interfaces:**
- Consumes: `SiteSuggestion`, `siteSuggestionForDiveProvider` (Task 10); `SiteMatchingService.applyConfirmed`, `createAndLink`, `currentSiteCandidateId` (Tasks 7-8); `DiveRepository.setSiteSuggestionDismissed` (Task 3); `QuickSiteFromGpsDialog.show` (Task 14 extends it, the current signature already works).
- Produces:

```dart
/// One write path for every banner action; no BuildContext, no snackbars.
class SiteSuggestionActions {
  SiteSuggestionActions({
    required this.diveId,
    required this.suggestion,
    required this.diveRepository,
  });
  /// Links the dive to [candidateId] (existing or bundled). Returns the
  /// resulting site when the candidate was an existing site, else null.
  Future<ApplyResult> assign(String candidateId);
  /// Locates the dive's coordinate-less current site at the point.
  Future<ApplyResult> addLocation();
  /// Creates [site] and links the dive to it.
  Future<DiveSite> create(DiveSite site);
  Future<void> dismiss();
}

/// Watches the suggestion for [diveId] and renders SiteSuggestionBanner.
/// [onSiteChanged] fires with the site the dive now has after assign /
/// addLocation / create, so an edit form can update its unsaved state.
class SiteSuggestionCard extends ConsumerWidget {
  const SiteSuggestionCard({
    super.key,
    required this.diveId,
    required this.currentSite,
    this.onSiteChanged,
    this.refreshLists,   // test seam; defaults to refreshing the dive and site list notifiers
  });
}
```

- [ ] **Step 1: Write the failing actions test**

`test/features/dive_log/presentation/helpers/site_suggestion_actions_test.dart` (generate `MockDiveRepository` here with `@GenerateMocks([DiveRepository])`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/helpers/site_suggestion_actions.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

import 'site_suggestion_actions_test.mocks.dart';

/// Records apply calls instead of touching a database. The base constructor
/// only stores its dependencies, so zero-arg repositories are safe here.
class FakeMatchingService extends SiteMatchingService {
  FakeMatchingService()
    : super(
        siteRepository: SiteRepository(),
        apiService: DiveSiteApiService(),
        diveRepository: DiveRepository(),
        mediaRepository: MediaRepository(),
        diverId: 'diver-1',
        thresholds: SiteMatchSensitivity.balanced.thresholds,
        runInTransaction: (body) => body(),
      );

  final applied = <ConfirmedMatch>[];
  final created = <DiveSite>[];

  @override
  Future<ApplyResult> applyConfirmed(List<ConfirmedMatch> confirmed) async {
    applied.addAll(confirmed);
    return const ApplyResult(divesLinked: 1, sitesCreated: 0);
  }

  @override
  Future<DiveSite> createAndLink(String diveId, DiveSite site) async {
    created.add(site);
    return site.copyWith(id: 'created');
  }
}

SiteSuggestion suggestionFor(
  FakeMatchingService service, {
  DiveSite? site,
  ProposalStatus status = ProposalStatus.clear,
  String? recommended,
}) => SiteSuggestion(
  proposal: MatchProposal(
    dive: Dive(
      id: 'd1',
      diveNumber: 1,
      dateTime: DateTime(2026, 1, 1),
      maxDepth: 18,
      site: site,
    ),
    status: status,
    recommendedCandidateId: recommended,
    point: const GeoPoint(20.5, -87.25),
    pointSource: PointSource.photo,
  ),
  service: service,
);

@GenerateMocks([DiveRepository])
void main() {
  late FakeMatchingService service;
  late MockDiveRepository dives;

  setUp(() {
    service = FakeMatchingService();
    dives = MockDiveRepository();
    when(dives.setSiteSuggestionDismissed(any, any)).thenAnswer((_) async {});
  });

  test('assign applies the chosen candidate through the service', () async {
    final actions = SiteSuggestionActions(
      diveId: 'd1',
      suggestion: suggestionFor(service, recommended: 's1'),
      diveRepository: dives,
    );
    await actions.assign('s1');
    expect(service.applied.single.diveId, 'd1');
    expect(service.applied.single.candidateId, 's1');
  });

  test('addLocation applies the current-site candidate', () async {
    const bare = DiveSite(id: 'bare', name: 'Typed Twice');
    final actions = SiteSuggestionActions(
      diveId: 'd1',
      suggestion: suggestionFor(service, site: bare),
      diveRepository: dives,
    );
    await actions.addLocation();
    expect(
      service.applied.single.candidateId,
      SiteMatchingService.currentSiteCandidateId('bare'),
    );
  });

  test('create routes through createAndLink', () async {
    final actions = SiteSuggestionActions(
      diveId: 'd1',
      suggestion: suggestionFor(service, status: ProposalStatus.none),
      diveRepository: dives,
    );
    final created = await actions.create(
      const DiveSite(id: '', name: 'Wall', location: GeoPoint(20.5, -87.25)),
    );
    expect(created.id, 'created');
    expect(service.created.single.name, 'Wall');
  });

  test('dismiss writes the synced flag', () async {
    final actions = SiteSuggestionActions(
      diveId: 'd1',
      suggestion: suggestionFor(service),
      diveRepository: dives,
    );
    await actions.dismiss();
    verify(dives.setSiteSuggestionDismissed('d1', true)).called(1);
  });
}
```

If `DiveSiteApiService()` needs constructor arguments, pass the same ones `diveSiteApiServiceProvider` passes (`site_providers.dart:528`).

- [ ] **Step 2: Generate mocks and run to verify failure**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/dive_log/presentation/helpers/site_suggestion_actions_test.dart
```
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Create the actions helper**

```dart
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';

/// The write side of a site suggestion. Every action goes through the
/// [SiteMatchingService] that computed the suggestion, so the banner and the
/// batch review page share the coincidence guard, bundled-site
/// materialisation, and the post-commit altitude pass. UI concerns (dialogs,
/// snackbars, navigation, provider refreshes) live in SiteSuggestionCard.
class SiteSuggestionActions {
  SiteSuggestionActions({
    required this.diveId,
    required this.suggestion,
    required this.diveRepository,
  });

  final String diveId;
  final SiteSuggestion suggestion;
  final DiveRepository diveRepository;

  /// Links the dive to [candidateId] (an existing site id or a bundled
  /// site's external id).
  Future<ApplyResult> assign(String candidateId) =>
      suggestion.service.applyConfirmed([ConfirmedMatch(diveId, candidateId)]);

  /// Writes the point onto the dive's coordinate-less current site.
  Future<ApplyResult> addLocation() {
    final site = suggestion.proposal.dive.site;
    if (site == null) {
      throw StateError('addLocation needs a dive with a current site');
    }
    return suggestion.service.applyConfirmed([
      ConfirmedMatch(diveId, SiteMatchingService.currentSiteCandidateId(site.id)),
    ]);
  }

  /// Creates [site] at the point and links the dive to it.
  Future<DiveSite> create(DiveSite site) =>
      suggestion.service.createAndLink(diveId, site);

  /// Hides the suggestion for this dive on every device.
  Future<void> dismiss() =>
      diveRepository.setSiteSuggestionDismissed(diveId, true);
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_log/presentation/helpers/site_suggestion_actions_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing card test**

`test/features/dive_log/presentation/widgets/site_suggestion_card_test.dart` (reuse `FakeMatchingService` and `suggestionFor` by importing the actions test file's helpers; move them into `test/features/dive_log/presentation/support/fake_matching_service.dart` first, and import that from both tests):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_card.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../media/presentation/support/media_widget_harness.dart';
import '../support/fake_matching_service.dart';

class _StubDiveRepository extends DiveRepository {
  final dismissed = <String>[];
  @override
  Future<void> setSiteSuggestionDismissed(String diveId, bool value) async {
    if (value) dismissed.add(diveId);
  }
}

void main() {
  late FakeMatchingService service;
  late _StubDiveRepository dives;
  var refreshed = 0;

  setUp(() {
    service = FakeMatchingService();
    dives = _StubDiveRepository();
    refreshed = 0;
  });

  Future<Widget> host(
    SiteSuggestion? suggestion, {
    DiveSite? currentSite,
    void Function(DiveSite?)? onSiteChanged,
  }) => mediaTestApp(
    overrides: [
      siteSuggestionForDiveProvider('d1').overrideWith((ref) async => suggestion),
      diveRepositoryProvider.overrideWithValue(dives),
    ],
    home: Scaffold(
      body: SiteSuggestionCard(
        diveId: 'd1',
        currentSite: currentSite,
        onSiteChanged: onSiteChanged,
        refreshLists: () async => refreshed++,
      ),
    ),
  );

  testWidgets('renders nothing when there is no suggestion', (tester) async {
    await tester.pumpWidget(await host(null));
    await tester.pumpAndSettle();
    expect(find.byType(SiteSuggestionCard), findsOneWidget);
    expect(find.textContaining('Location'), findsNothing);
  });

  testWidgets('assign applies and reports the assigned site', (tester) async {
    const blueHole = DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0));
    final s = suggestionFor(
      service,
      recommended: 's1',
      candidates: [
        const MatchCandidateView(
          id: 's1',
          name: 'Blue Hole',
          isExisting: true,
          distanceMeters: 40,
          location: GeoPoint(0, 0),
        ),
      ],
    );
    DiveSite? reported;
    await tester.pumpWidget(await host(s, onSiteChanged: (site) => reported = site));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Assign Blue Hole'));
    await tester.pumpAndSettle();
    expect(service.applied.single.candidateId, 's1');
    expect(reported?.id, blueHole.id);
    expect(refreshed, 1);
    expect(find.text('Assigned Blue Hole'), findsOneWidget);
  });

  testWidgets('dismiss writes the flag', (tester) async {
    await tester.pumpWidget(await host(suggestionFor(service, status: ProposalStatus.none)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(dives.dismissed, ['d1']);
  });

  testWidgets('create opens the quick dialog and links the new site', (tester) async {
    DiveSite? reported;
    await tester.pumpWidget(await host(
      suggestionFor(service, status: ProposalStatus.none),
      onSiteChanged: (site) => reported = site,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Site'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Wall');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Site'));
    await tester.pumpAndSettle();
    expect(service.created.single.name, 'Wall');
    expect(reported?.id, 'created');
    expect(find.textContaining('Created site: Wall'), findsOneWidget);
  });
}
```

`suggestionFor` in the shared support file gains an optional `List<MatchCandidateView> candidates = const []` parameter passed into `MatchProposal.candidates`. For the assign test, `onSiteChanged` receives the existing candidate resolved to a `DiveSite` by id from `proposal.candidates` (name and location from the view); `_StubDiveRepository` must also override `getDiveById` to return null so the card does not hit the database when re-reading the dive (see Step 6).

- [ ] **Step 6: Create the card**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/helpers/site_suggestion_actions.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_banner.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';
import 'package:submersion/features/media/presentation/widgets/quick_site_from_gps_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Watches the site suggestion for [diveId] and renders the banner with its
/// actions wired. Renders nothing when there is no suggestion, so callers
/// place it unconditionally. Used by the dive edit and detail pages.
class SiteSuggestionCard extends ConsumerWidget {
  const SiteSuggestionCard({
    super.key,
    required this.diveId,
    required this.currentSite,
    this.onSiteChanged,
    this.refreshLists,
  });

  final String diveId;
  final DiveSite? currentSite;
  final void Function(DiveSite? site)? onSiteChanged;

  /// Refreshes the dive and site lists after a write. Injectable for tests.
  final Future<void> Function()? refreshLists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(siteSuggestionForDiveProvider(diveId));
    final suggestion = async.value;
    if (suggestion == null) return const SizedBox.shrink();

    final proposal = suggestion.proposal;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final hasSite = currentSite != null || proposal.dive.site != null;
    final recommended = proposal.recommendedCandidateId == null
        ? null
        : proposal.candidates
              .where((c) => c.id == proposal.recommendedCandidateId)
              .firstOrNull;
    final siteName =
        currentSite?.name ?? proposal.dive.site?.name ?? recommended?.name ?? '';

    final actions = SiteSuggestionActions(
      diveId: diveId,
      suggestion: suggestion,
      diveRepository: ref.read(diveRepositoryProvider),
    );

    return SiteSuggestionBanner(
      pointSource: suggestion.pointSource,
      coordinates: units.formatCoordinates(
        suggestion.point.latitude,
        suggestion.point.longitude,
      ),
      status: proposal.status,
      hasSite: hasSite,
      siteName: siteName,
      candidateCount: proposal.candidates.length,
      recommendedDistanceMeters: recommended?.distanceMeters,
      onAssign: recommended == null
          ? null
          : () => _run(context, ref, () async {
              await actions.assign(recommended.id);
              final site = DiveSite(
                id: recommended.id,
                name: recommended.name,
                location: recommended.location,
                country: recommended.country,
                region: recommended.region,
              );
              return (site, context.l10n.siteSuggestion_assignedSnack(site.name));
            }),
      onChooseNearby: () => context.push('/dives/match-sites', extra: [diveId]),
      onCreate: () => _create(context, ref, actions, suggestion),
      onAddLocation: !hasSite
          ? null
          : () => _run(context, ref, () async {
              await actions.addLocation();
              final base = currentSite ?? proposal.dive.site!;
              final site = base.copyWith(location: suggestion.point);
              return (site, context.l10n.diveLog_edit_addedGps(site.name));
            }),
      onDismiss: () => _run(context, ref, () async {
        await actions.dismiss();
        return null;
      }),
    );
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    SiteSuggestionActions actions,
    SiteSuggestion suggestion,
  ) async {
    final draft = await QuickSiteFromGpsDialog.show(
      context,
      latitude: suggestion.point.latitude,
      longitude: suggestion.point.longitude,
    );
    if (draft == null || !context.mounted) return;
    await _run(context, ref, () async {
      final created = await actions.create(draft);
      return (created, context.l10n.diveLog_edit_createdSite(created.name));
    });
  }

  /// Runs a write, then refreshes what depends on it and reports the result.
  /// A failure keeps the banner up and shows the shared apply error.
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<(DiveSite, String)?> Function() write,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final result = await write();
      ref.invalidate(siteSuggestionForDiveProvider(diveId));
      ref.invalidate(diveProvider(diveId));
      await (refreshLists ?? () => _defaultRefresh(ref))();
      if (result != null) {
        onSiteChanged?.call(result.$1);
        messenger.showSnackBar(
          SnackBar(content: Text(result.$2), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.siteMatchReview_applyError)));
    }
  }

  Future<void> _defaultRefresh(WidgetRef ref) async {
    await ref.read(diveListNotifierProvider.notifier).refresh();
    await ref.read(paginatedDiveListProvider.notifier).refresh();
    await ref.read(siteListNotifierProvider.notifier).refresh();
  }
}
```

- [ ] **Step 7: Run both tests to verify pass**

Run: `flutter test test/features/dive_log/presentation/helpers/site_suggestion_actions_test.dart`
Expected: PASS.
Run: `flutter test test/features/dive_log/presentation/widgets/site_suggestion_card_test.dart`
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format lib/features/dive_log test/features/dive_log
flutter analyze lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/presentation/helpers/site_suggestion_actions.dart lib/features/dive_log/presentation/widgets/site_suggestion_card.dart test/features/dive_log/presentation
git commit -m "feat(dives): site suggestion card with one write path"
```

---

### Task 13: Wire the card into the edit and detail pages; delete the old banner

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (lines 92-93 imports, 297 `_gpsSuggestionDismissed`, 2191-2200 banner, 2212-2285 handlers)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildEmbeddedHeader` around line 1000, `_buildHeaderSection` around line 1210)
- Delete: `lib/features/media/presentation/widgets/photo_gps_suggestion_banner.dart`
- Test: existing `test/features/dive_log/presentation/pages/dive_edit_page_test.dart` and `dive_detail_page_test.dart` (run; add the override below where they pump a saved dive)

- [ ] **Step 1: Edit page**

Replace the `PhotoGpsSuggestionBanner(...)` block with:

```dart
    if (widget.diveId != null) {
      children.add(
        SiteSuggestionCard(
          diveId: widget.diveId!,
          currentSite: _selectedSite,
          onSiteChanged: (site) => setState(() => _assignSite(site)),
        ),
      );
    }
```

Delete `_createSiteFromPhotoGps`, `_updateSiteWithPhotoGps`, the `_gpsSuggestionDismissed` field, and the imports of `photo_gps_suggestion_banner.dart`, `quick_site_from_gps_dialog.dart`, and `media_providers.dart` if nothing else in the file uses them (grep for `divePhotoGpsProvider` and `elevationServiceProvider` first; `elevationServiceProvider` is still used at line ~4103). Add `import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_card.dart';`.

- [ ] **Step 2: Detail page**

In `_buildEmbeddedHeader`, the site column is `Expanded(child: Column(...children: [...]))`; the card does not belong inside a one-line header row, so wrap the header: change the method's returned `Container(...)` into a `Column(mainAxisSize: MainAxisSize.min, children: [ <existing Container>, Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SiteSuggestionCard(diveId: dive.id, currentSite: dive.site)) ])`.

In `_buildHeaderSection`, inside the outer `Column` under the `Row(...)` that holds the avatar and the site column (directly after that `Row`'s closing `),`), add:

```dart
          SiteSuggestionCard(diveId: dive.id, currentSite: dive.site),
```

Add the import. Both placements are unconditional; the card renders nothing when there is no suggestion.

- [ ] **Step 3: Delete the old banner and fix references**

```bash
git rm lib/features/media/presentation/widgets/photo_gps_suggestion_banner.dart
grep -rn "PhotoGpsSuggestionBanner\|photo_gps_suggestion_banner" lib test
```
Expected: no matches. (`divePhotoGpsProvider` and `allDivePhotoGpsProvider` stay; other code invalidates them.)

- [ ] **Step 4: Run the page tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart`
Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart`
Expected: PASS. If a test fails because `siteSuggestionForDiveProvider` reaches the database, add `siteSuggestionForDiveProvider(<id>).overrideWith((ref) async => null)` to that test's overrides (or a `siteSuggestionForDiveProvider` family-wide `overrideWith((ref, id) async => null)`), and add the same family override to `getBaseOverrides` in `test/helpers/mock_providers.dart` so every page test gets it by default.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(dives): site suggestion on the edit and detail pages"
```

---

### Task 14: Geocode-prefilled quick-create dialog

**Files:**
- Modify: `lib/features/media/presentation/widgets/quick_site_from_gps_dialog.dart`
- Test: `test/features/media/presentation/widgets/quick_site_from_gps_dialog_test.dart`

**Interfaces:**
- `QuickSiteFromGpsDialog.show(context, {latitude, longitude})` unchanged. The returned `DiveSite` now carries `country`, `region`, `city` from editable fields prefilled by `locationServiceProvider.reverseGeocode` (best-effort; empty when it fails). The name hint shows the locality when known.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/presentation/widgets/quick_site_from_gps_dialog.dart';

import '../support/media_widget_harness.dart';

class _FakeLocationService extends LocationService {
  _FakeLocationService(this.result, {this.fail = false});
  final ({String? country, String? region, String? locality}) result;
  final bool fail;
  @override
  Future<({String? country, String? region, String? locality})> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    if (fail) throw StateError('offline');
    return result;
  }
}

void main() {
  Future<DiveSite?> open(WidgetTester tester, LocationService geocoder) async {
    DiveSite? result;
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [locationServiceProvider.overrideWithValue(geocoder)],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await QuickSiteFromGpsDialog.show(
                  context,
                  latitude: 20.5,
                  longitude: -87.25,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('prefills country, region and city from the geocoder', (tester) async {
    final geocoder = _FakeLocationService(
      (country: 'Mexico', region: 'Quintana Roo', locality: 'Tulum'),
    );
    final pending = open(tester, geocoder);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Mexico'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Quintana Roo'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Tulum'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Cenote Wall');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Site'));
    await tester.pumpAndSettle();
    final site = await pending;
    expect(site?.name, 'Cenote Wall');
    expect(site?.country, 'Mexico');
    expect(site?.region, 'Quintana Roo');
    expect(site?.city, 'Tulum');
    expect(site?.location, const GeoPoint(20.5, -87.25));
  });

  testWidgets('a failed geocode leaves the fields empty and still creates', (tester) async {
    final geocoder = _FakeLocationService(
      (country: null, region: null, locality: null),
      fail: true,
    );
    final pending = open(tester, geocoder);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Somewhere');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Site'));
    await tester.pumpAndSettle();
    final site = await pending;
    expect(site?.name, 'Somewhere');
    expect(site?.country, isNull);
  });
}
```

`LocationService` is a singleton with a private constructor in production; if `extends LocationService` is not possible, check how `site_edit_page_test.dart` fakes it (memory: it uses a fake through `locationServiceProvider`) and copy that fake's shape.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/widgets/quick_site_from_gps_dialog_test.dart`
Expected: FAIL (no Country field; the returned site has no country).

- [ ] **Step 3: Implement**

In `_QuickSiteFromGpsDialogState`: add `_countryController`, `_regionController`, `_cityController`, `String? _locality`, and in `initState` kick off the lookup:

```dart
  @override
  void initState() {
    super.initState();
    unawaited(_prefill());
  }

  /// Fill-empty geocoding at explicit capture time (the same rule as the
  /// site edit page's "Use my location"); never at save time.
  Future<void> _prefill() async {
    try {
      final place = await ref
          .read(locationServiceProvider)
          .reverseGeocode(widget.latitude, widget.longitude);
      if (!mounted) return;
      setState(() {
        if (_countryController.text.isEmpty) {
          _countryController.text = place.country ?? '';
        }
        if (_regionController.text.isEmpty) {
          _regionController.text = place.region ?? '';
        }
        if (_cityController.text.isEmpty) {
          _cityController.text = place.locality ?? '';
        }
        _locality = place.locality;
      });
    } catch (_) {
      // Offline or unsupported platform: the diver types what they know.
    }
  }
```

Below the name field add three `TextFormField`s with `labelText: context.l10n.diveSites_edit_field_country_label` / `..._region_label` / `..._city_label` (no validators). Use `hintText: _locality ?? context.l10n.media_quickSiteDialog_siteNameHint` on the name field. In `_createSite`, build the site with the extra fields, mapping empty strings to null:

```dart
    String? orNull(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final site = DiveSite(
      id: _uuid.v4(),
      name: _nameController.text.trim(),
      location: GeoPoint(widget.latitude, widget.longitude),
      country: orNull(_countryController),
      region: orNull(_regionController),
      city: orNull(_cityController),
    );
```

Dispose the new controllers. Wrap the dialog content in a `SingleChildScrollView` so four fields fit on a phone. Imports: `dart:async`, `package:submersion/core/providers/location_service_provider.dart`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/media/presentation/widgets/quick_site_from_gps_dialog_test.dart`
Expected: PASS.
Run: `flutter test test/features/dive_log/presentation/widgets/site_suggestion_card_test.dart`
Expected: PASS (the card test's `mediaTestApp` has no `locationServiceProvider` override; the real singleton's geocode fails fast in tests and the catch swallows it; if it instead hangs, add `locationServiceProvider.overrideWithValue(_FakeLocationService(...))` to that test too, moving the fake into `test/features/media/presentation/support/fake_location_service.dart`).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/media test/features/media
flutter analyze lib/features/media test/features/media
git add lib/features/media/presentation/widgets/quick_site_from_gps_dialog.dart test/features/media/presentation
git commit -m "feat(media): prefill country, region and city in the quick site dialog"
```

---

### Task 15: Review page: source chip, current-site card, "Create site here"

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_match_review_page.dart` (`_DiveRow` around line 196, `_CandidateCard` around line 272, `onConfirm` snackbar at line 33)
- Test: `test/features/dive_sites/presentation/pages/site_match_review_page_test.dart`

**Interfaces:**
- Consumes: `MatchProposal.pointSource`, `MatchCandidateView.isCurrentSite`, `ApplyResult.sitesLocated`, `SiteMatchReviewNotifier.createSiteHere` (Tasks 6-8), l10n keys (Task 9), `QuickSiteFromGpsDialog` (Task 14).
- Produces: `_DiveRow` gains `required VoidCallback onCreateHere`.

- [ ] **Step 1: Write the failing tests**

Extend `_SeededNotifier` in the test with a recorded `createSiteHere`:

```dart
  final createdHere = <(String, DiveSite)>[];
  @override
  Future<DiveSite?> createSiteHere(String diveId, DiveSite site) async {
    createdHere.add((diveId, site));
    state = state.copyWith(
      proposals: [for (final p in state.proposals) if (p.dive.id != diveId) p],
    );
    return site.copyWith(id: 'created');
  }
```

Add `import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';` if missing, and make `_harness` return the notifier too (or keep a `late _SeededNotifier notifier` assigned inside the `overrideWith` closure). Then:

```dart
  testWidgets('photo-sourced proposals show the source chip', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
          point: const GeoPoint(0, 0),
          pointSource: PointSource.photo,
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();
    expect(find.text('from photo'), findsOneWidget);
  });

  testWidgets('the current-site candidate is labelled and preselected', (tester) async {
    final current = MatchCandidateView(
      id: SiteMatchingService.currentSiteCandidateId('bare'),
      name: 'Typed Twice',
      isExisting: true,
      isCurrentSite: true,
      distanceMeters: 0,
      location: const GeoPoint(0, 0),
    );
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [current],
          recommendedCandidateId: current.id,
          point: const GeoPoint(0, 0),
        ),
      ],
      focusedDiveId: 'd7',
      selections: {'d7': current.id},
    );
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();
    expect(find.text('Add location to this site'), findsOneWidget);
    expect(find.text('Typed Twice'), findsWidgets);
    expect(find.textContaining('0 m away'), findsNothing);
  });

  testWidgets('Create site here opens the dialog and links immediately', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.none,
          point: const GeoPoint(0, 0),
        ),
      ],
      focusedDiveId: 'd7',
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();
    await tester.tap(find.text('Create site here'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Wall');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Site'));
    await tester.pumpAndSettle();
    expect(notifier.createdHere.single.$1, 'd7');
    expect(notifier.createdHere.single.$2.name, 'Wall');
    expect(find.textContaining('Created site: Wall'), findsOneWidget);
    expect(find.text('Nothing to match.'), findsOneWidget);
  });

  testWidgets('confirm snackbar reports located sites', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
          point: const GeoPoint(0, 0),
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(
      _harness(seeded, confirmResult: const ApplyResult(divesLinked: 1, sitesCreated: 0, sitesLocated: 1)),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm 1 matches'));
    await tester.pump();
    expect(find.textContaining('located 1 sites'), findsOneWidget);
  });
```

The `QuickSiteFromGpsDialog` inside the harness needs `locationServiceProvider` overridden with the fake from Task 14 (move it to `test/features/media/presentation/support/fake_location_service.dart` and add `locationServiceProvider.overrideWithValue(FakeLocationService((country: null, region: null, locality: null)))` to `_harness`'s overrides).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_sites/presentation/pages/site_match_review_page_test.dart`
Expected: the four new tests FAIL.

- [ ] **Step 3: Implement**

`onConfirm` snackbar: pass `result.sitesLocated` as the third argument (done in Task 9 if not already).

`_DiveRow`: add `required this.onCreateHere` and render, inside the `Column` after the `ListTile`, a trailing action row for every focused proposal:

```dart
        if (focused)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                if (proposal.pointSource == PointSource.photo)
                  Chip(
                    avatar: const Icon(Icons.photo_camera_outlined, size: 16),
                    label: Text(l10n.siteMatchReview_sourcePhoto),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Chip(
                    avatar: const Icon(Icons.watch_outlined, size: 16),
                    label: Text(l10n.siteMatchReview_sourceDiveComputer),
                    visualDensity: VisualDensity.compact,
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onCreateHere,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: Text(l10n.siteMatchReview_createHereButton),
                ),
              ],
            ),
          ),
```

For `ProposalStatus.none` rows the same row renders (the chip plus the button), which is the primary action for that case.

`_CandidateCard`: when `c.isCurrentSite`, the trailing source label becomes `l10n.siteMatchReview_currentSiteCard` and the `meta` list omits `awayMeters` (start `meta` as `<String>[if (!c.isCurrentSite) l10n.siteMatchReview_awayMeters(...), ...]`).

Page: build `onCreateHere` per row:

```dart
    Future<void> createHere(MatchProposal p) async {
      final point = p.point;
      if (point == null) return;
      final draft = await QuickSiteFromGpsDialog.show(
        context,
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (draft == null || !context.mounted) return;
      final created = await notifier.createSiteHere(p.dive.id, draft);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created == null
                ? l10n.siteMatchReview_applyError
                : l10n.diveLog_edit_createdSite(created.name),
          ),
        ),
      );
    }
```

and pass `onCreateHere: () => createHere(p)` into each `_DiveRow`. Import `quick_site_from_gps_dialog.dart`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_sites/presentation/pages/site_match_review_page_test.dart`
Expected: PASS (15 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_sites test/features/dive_sites
flutter analyze lib/features/dive_sites test/features/dive_sites
git add lib/features/dive_sites test/features/dive_sites test/features/media/presentation/support
git commit -m "feat(sites): source chip, current-site card and create-here on the review page"
```

---

### Task 16: Post-import prompt and the Files-tab snackbar

**Files:**
- Create: `lib/features/media/presentation/helpers/offer_site_review_after_import.dart`
- Modify: `lib/features/trips/presentation/helpers/trip_scan_actions.dart:168-178`, `lib/features/media/presentation/widgets/files_tab.dart:326-356`, `lib/features/media/presentation/helpers/lightroom_scan_helper.dart:35-48`, `lib/features/media/presentation/pages/media_import_view.dart` (where `importResolved`'s result snackbar is shown)
- Test: `test/features/media/presentation/helpers/offer_site_review_after_import_test.dart`

**Interfaces:**
- Produces: `Future<void> offerSiteReviewAfterImport(BuildContext context, WidgetRef ref, Iterable<String> diveIds, {ScaffoldMessengerState? messenger})`: reads `eligibleImportedDivesProvider(ImportedDiveIds(ids))`; when non-empty shows a snackbar `mediaImport_offerSiteReview(n)` with action `mediaImport_reviewSitesAction` that pushes `/dives/match-sites` with the eligible ids. No-op for an empty id list or when nothing is eligible.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/media/presentation/helpers/offer_site_review_after_import.dart';

import '../../../../helpers/test_app.dart';

void main() {
  Future<(WidgetTester, List<Object?>)> pump(
    WidgetTester tester,
    List<String> eligible, {
    required List<String> imported,
  }) async {
    final pushed = <Object?>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => offerSiteReviewAfterImport(context, ref, imported),
                child: const Text('done'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/dives/match-sites',
          builder: (context, state) {
            pushed.add(state.extra);
            return const Scaffold(body: Text('review page'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          eligibleImportedDivesProvider(ImportedDiveIds(imported)).overrideWith((ref) async => eligible),
        ],
      ),
    );
    return (tester, pushed);
  }

  testWidgets('offers a review with the eligible count and navigates', (tester) async {
    final (_, pushed) = await pump(tester, ['d1', 'd2'], imported: ['d1', 'd2', 'd3']);
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(find.text('2 dives could get a site from their photos'), findsOneWidget);
    await tester.tap(find.text('Review sites'));
    await tester.pumpAndSettle();
    expect(find.text('review page'), findsOneWidget);
    expect(pushed.single, ['d1', 'd2']);
  });

  testWidgets('stays silent when nothing is eligible or nothing was imported', (tester) async {
    await pump(tester, const [], imported: ['d1']);
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/helpers/offer_site_review_after_import_test.dart`
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Create the helper**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// After a multi-dive photo import, offers the batch site review for the
/// dives that just became eligible (siteless or coordinate-less site, now
/// with a GPS point, not dismissed). Silent when there is nothing to offer.
/// Pass [messenger] when the calling page is about to pop, so the snackbar
/// lands on the page underneath.
Future<void> offerSiteReviewAfterImport(
  BuildContext context,
  WidgetRef ref,
  Iterable<String> diveIds, {
  ScaffoldMessengerState? messenger,
}) async {
  final ids = diveIds.toSet().toList();
  if (ids.isEmpty) return;
  final l10n = context.l10n;
  final scaffold = messenger ?? ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final eligible = await ref.read(
    eligibleImportedDivesProvider(ImportedDiveIds(ids)).future,
  );
  if (eligible.isEmpty) return;
  scaffold.showSnackBar(
    SnackBar(
      content: Text(l10n.mediaImport_offerSiteReview(eligible.length)),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: l10n.mediaImport_reviewSitesAction,
        onPressed: () => router.push('/dives/match-sites', extra: eligible),
      ),
    ),
  );
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/media/presentation/helpers/offer_site_review_after_import_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the four call sites**

1. `trip_scan_actions.dart` `_importPhotos`: after the `trips_detail_scan_linkedPhotos` snackbar, add
   `await offerSiteReviewAfterImport(context, ref, photosByDive.keys.map((d) => d.id));` guarded by `if (context.mounted)`.
2. `files_tab.dart` `_commit`: capture `final diveIds = ref.read(filesTabNotifierProvider).match.matched.keys.toList();` BEFORE `notifier.commit(...)` (commit clears the state); replace the hardcoded snackbar text with `_isSiteSession ? context.l10n.filesTab_attachedToSite(created.length) : context.l10n.filesTab_linkedItems(created.length)` and the action label with `context.l10n.filesTab_undo` (read `l10n` before the pop); after showing it, `if (!_isSiteSession) await offerSiteReviewAfterImport(context, ref, diveIds, messenger: messenger);` (the page has popped, so pass the captured root messenger; the helper's `GoRouter.of(context)` still resolves through the popped route's context, and `context.mounted` is false, so call it with the messenger BEFORE `navigator.pop()` instead, and reorder: show the linked snackbar, offer the review, then pop). Remove the `TODO(media): l10n` comments those strings carried.
3. `lightroom_scan_helper.dart` `runLightroomScan`: after the summary snackbar and the invalidation loop, `if (context.mounted) await offerSiteReviewAfterImport(context, ref, dives.map((d) => d.id));`.
4. `media_import_view.dart`: `importResolved` returns `ImportReviewResult`; add `linkedDiveIds: byDive.keys.toList()` to that result (new `final List<String> linkedDiveIds;` field, default `const []`), and where `_launch` shows its result snackbar, follow it with `await offerSiteReviewAfterImport(context, ref, result.linkedDiveIds);`.

- [ ] **Step 6: Run the touched suites**

Run: `flutter test test/features/media/presentation`
Run: `flutter test test/features/trips`
Expected: PASS. If a Files-tab test asserts the old hardcoded snackbar text, update it to the localized string.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(media): offer the site review after multi-dive photo imports"
```

---

### Task 17: Roadmap, docs, whole-project verification

**Files:**
- Modify: `docs/FEATURE_ROADMAP.md:851`, `docs/REMAINING_TASKS.md:151`

- [ ] **Step 1: Tick the roadmap item**

Change `- [ ] GPS extraction from photos (suggest site creation)` to `- [x] GPS extraction from photos (suggest site creation): desktop and video readers, nearest-site matching, detail-page and post-import surfacing, synced dismissal` in both files.

- [ ] **Step 2: Format and analyze everything**

```bash
dart format .
flutter analyze
```
Expected: no changes, "No issues found!".

- [ ] **Step 3: Full test suite once**

Run: `flutter test`
Expected: PASS. Rerun any known-flaky file alone before treating a failure as a regression.

- [ ] **Step 4: Manual smoke on macOS**

Run `flutter run -d macos`. Open a dive without a site that has a GPS-tagged photo (after Plan A, a desktop JPEG import works; before it, use a dive synced from a phone). Confirm: the banner appears on the detail page; "Assign" links the nearest site; dismiss hides it and survives reopening the dive; a Files-tab folder import over several dives ends with the "Review sites" snackbar; the review page shows the "from photo" chip and can create a site.

- [ ] **Step 5: Commit**

```bash
git add docs/FEATURE_ROADMAP.md docs/REMAINING_TASKS.md
git commit -m "docs: tick the photo GPS site suggestion roadmap item"
```

---

## Self-review notes

- Spec coverage: Section 1 (Tasks 4-8), Section 3 (Tasks 10-14), Section 4 (Tasks 15-16), Section 5 (Tasks 2-3 schema and sync, error handling inside Tasks 6-8 and 12, testing throughout). Section 2 is Plan A.
- Type consistency: `PhotoGpsPoint` (Task 4) is what `getBestPhotoGpsForDives` returns and what `_pointFor` consumes (Task 6); `SiteMatchingService.currentSiteCandidateId` (Task 7) is used by Tasks 12 and 15; `ApplyResult.sitesLocated` (Task 7) is read by Task 9's snackbar and Task 15; `SiteSuggestion` (Task 10) is consumed by Tasks 12-13; `createSiteHere` (Task 8) by Task 15.
- Deliberate deviations from the spec text: the current-site apply uses `updateSiteCoordinates` (column patch) rather than `updateSite(site.copyWith(...))`, because `Dive.site` may be a partially hydrated entity (issue #1187); the dismissal column name is `site_suggestion_dismissed_at` as approved in Section 1 v2; the rung is v172, not v169, because main moved.
