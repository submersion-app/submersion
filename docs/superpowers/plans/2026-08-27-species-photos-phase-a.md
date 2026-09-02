# Species Photos, Phase A, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver tag the photos already on their dives with the species in them, see every photo of a species in one gallery on the species detail page, tag from the photo viewer, and import camera-roll photos into a species through the existing reviewed importer.

**Architecture:** The dormant `media_species` table becomes live behind a new read/write `MediaSpeciesRepository`; a `SpeciesTaggingService` composes it with the media and species repositories so a tag adds a missing sighting. Sync registration copies `site_species` point for point (a clockless child exported by its parent's HLC). UI is additive: a Photos section on the species detail page, a purpose-built tag picker page, a viewer action with a bottom sheet, and a wrapper viewer page, all following the dive and site media sections' patterns.

**Tech Stack:** Flutter, Riverpod (`package:submersion/core/providers/provider.dart`), Drift (typed selects with joins plus `customSelect` for aggregates), the shared `SelectionController` and `DragSelectGridView`, `flutter gen-l10n` ARB localization, `flutter_test` with the media widget harness.

**Spec:** `docs/superpowers/specs/2026-08-26-species-photos-design.md` (sections 1 to 6 and 8 to 10 are phase A; section 7 is phase B and is NOT in this plan).

## Global Constraints

- Work only in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos` on branch `worktree-species-photos` (cut from `origin/main` dd6b435f62a, codegen already run). Every path below is relative to that root; every shell command starts with `cd` into it. `flutter analyze` prints `Analyzing species-photos...` when it runs in the right tree; that line is the receipt.
- **No schema change.** `media_species` already exists (created in the `CREATE TABLE IF NOT EXISTS media_species` migration step and by `createAll()` on fresh databases). Do not touch `lib/core/database/database.dart`. Uniqueness of (media, species) is enforced in the repository; gallery queries are `DISTINCT`.
- The bounding-box and notes columns of `media_species` stay unused.
- "Attached or absent" is untouched: no new `MediaAttachTarget` case, no change to the orphan sweep, unlink or deletion cascades. A tag only ever sits on a photo that already has a dive or site.
- Tagging a species on a photo whose dive has no sighting of it adds the sighting (count 1, no notes). Untagging never removes a sighting.
- No em-dashes anywhere (code, comments, docs, ARB strings, commit messages). No emojis in code or docs.
- Immutability: entities are `const`-constructible `Equatable`s with `copyWith`; never mutate lists passed in.
- Imports grouped: dart, flutter, packages, local. Files snake_case, classes PascalCase, 200-400 lines typical, 800 max.
- Tests first. Run single test files with `flutter test <file>` and check the exit code; never pipe the command into `grep` or `tail` (the pipe replaces the exit code).
- Localization: every new user-visible string is an ARB key in all 11 locales (`ar de en es fr he hu it nl pt zh`); the `flutter gen-l10n` output under `lib/l10n/arb/` is tracked and committed with the ARB change.
- Dates and depths go through `UnitFormatter(ref.watch(settingsProvider))`.
- `dart format .` before every commit.
- Sync: a `FutureProvider` overridden to an error never delivers under `testWidgets` in this repo, so widget tests cover success paths; error branches stay trivial and analyzer-checked.

---

### Task 1: `MediaSpeciesRepository` core (tags for a photo, add, remove, tick) and shared test fixtures

**Files:**
- Create: `lib/features/media/data/repositories/media_species_repository.dart`
- Create: `test/features/media/data/repositories/species_photo_fixtures.dart` (test support, reused by Tasks 2, 4 and 5)
- Test: `test/features/media/data/repositories/media_species_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` via `DatabaseService.instance.database`; `SyncRepository.markRecordPending({entityType, recordId, localUpdatedAt})` and `logDeletion({entityType, recordId})` from `lib/core/data/repositories/sync_repository.dart`; `SyncEventBus.notifyLocalChange()` from `lib/core/services/sync/sync_event_bus.dart`; `MediaSpeciesTag` from `lib/features/media/domain/entities/media_item.dart` (fields `id, mediaId, speciesId, sightingId, bboxX, bboxY, bboxWidth, bboxHeight, notes, createdAt`); the Drift row class `MediaSpecy` and companion `MediaSpeciesCompanion`.
- Produces:
  ```dart
  class MediaSpeciesRepository {
    Stream<void> watchTagChanges();
    Future<List<MediaSpeciesTag>> getTagsForMedia(String mediaId);
    Future<Map<String, List<MediaSpeciesTag>>> getTagsForMediaIds(List<String> mediaIds);
    Future<MediaSpeciesTag> addTag({required String mediaId, required String speciesId, String? sightingId});
    Future<void> removeTag({required String mediaId, required String speciesId});
  }
  ```
  and the fixture helpers `insertTestDiver(id)`, `insertTestSite(id, name)`, `insertTestDive({id, at, diverId, siteId, number})`, `insertTestSpecies({id, name, category, builtIn})`, `insertTestSighting({id, diveId, speciesId})`, `insertTestMedia({id, diveId, siteId, takenAt, fileType})`.

Background: `media_species` has no `hlc` column and no `updatedAt`; it is a "clockless child" exactly like `site_species`, so add and remove follow `SpeciesRepository.addExpectedSpecies` / `removeExpectedSpecies` to the letter (insert, `markRecordPending`, notify; select id by pair, delete by id, `logDeletion`, notify). Test databases run with foreign keys off, so insert parents before children anyway.

- [ ] **Step 1: Write the shared fixtures**

`test/features/media/data/repositories/species_photo_fixtures.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// Row-level fixtures for species-photo tests. Every helper inserts one row
/// into the test database and nothing else; compose them in the order
/// parent then child (divers, sites, dives, species, sightings, media).
Future<void> insertTestDiver(String id) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.divers)
      .insertOnConflictUpdate(
        DiversCompanion(
          id: Value(id),
          name: Value('Diver $id'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> insertTestSite(String id, String name) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.diveSites)
      .insertOnConflictUpdate(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(name),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> insertTestDive({
  required String id,
  required DateTime at,
  String? diverId,
  String? siteId,
  int? number,
}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveNumber: Value(number),
          diveDateTime: Value(at.millisecondsSinceEpoch),
          diverId: Value(diverId),
          siteId: Value(siteId),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> insertTestSpecies({
  required String id,
  required String name,
  SpeciesCategory category = SpeciesCategory.fish,
  bool builtIn = false,
}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.species)
      .insert(
        SpeciesCompanion(
          id: Value(id),
          commonName: Value(name),
          category: Value(category.name),
          isBuiltIn: Value(builtIn),
        ),
      );
}

Future<void> insertTestSighting({
  required String id,
  required String diveId,
  required String speciesId,
}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.sightings)
      .insert(
        SightingsCompanion(
          id: Value(id),
          diveId: Value(diveId),
          speciesId: Value(speciesId),
        ),
      );
}

/// A photo row. [takenAt] orders galleries (newest first); it is stored as
/// epoch millis the way the importer stores wall-clock UTC.
Future<void> insertTestMedia({
  required String id,
  String? diveId,
  String? siteId,
  DateTime? takenAt,
  String fileType = 'photo',
}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.media)
      .insert(
        MediaCompanion(
          id: Value(id),
          diveId: Value(diveId),
          siteId: Value(siteId),
          filePath: Value('/tmp/$id.jpg'),
          fileType: Value(fileType),
          takenAt: Value(takenAt?.millisecondsSinceEpoch),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}
```

- [ ] **Step 2: Write the failing repository test**

`test/features/media/data/repositories/media_species_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../../helpers/test_database.dart';
import 'species_photo_fixtures.dart';

void main() {
  late MediaSpeciesRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = MediaSpeciesRepository();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'sp_whale_shark', name: 'Whale Shark');
    await insertTestSpecies(id: 'c1', name: 'My Nudibranch');
    await insertTestSighting(id: 'sg1', diveId: 'd1', speciesId: 'sp_whale_shark');
    await insertTestMedia(id: 'm1', diveId: 'd1');
    await insertTestMedia(id: 'm2', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a photo starts with no tags', () async {
    expect(await repository.getTagsForMedia('m1'), isEmpty);
  });

  test('addTag inserts a row linked to the sighting', () async {
    final tag = await repository.addTag(
      mediaId: 'm1',
      speciesId: 'sp_whale_shark',
      sightingId: 'sg1',
    );

    expect(tag.mediaId, 'm1');
    expect(tag.speciesId, 'sp_whale_shark');
    expect(tag.sightingId, 'sg1');
    final tags = await repository.getTagsForMedia('m1');
    expect(tags.single.id, tag.id);
  });

  test('addTag is idempotent for the same photo and species', () async {
    final first = await repository.addTag(mediaId: 'm1', speciesId: 'c1');
    final second = await repository.addTag(mediaId: 'm1', speciesId: 'c1');

    expect(second.id, first.id);
    expect(await repository.getTagsForMedia('m1'), hasLength(1));
  });

  test('getTagsForMediaIds groups tags by photo and skips untagged ones',
      () async {
    await repository.addTag(mediaId: 'm1', speciesId: 'sp_whale_shark');
    await repository.addTag(mediaId: 'm1', speciesId: 'c1');

    final byMedia = await repository.getTagsForMediaIds(['m1', 'm2']);

    expect(byMedia.keys, ['m1']);
    expect(
      byMedia['m1']!.map((t) => t.speciesId).toSet(),
      {'sp_whale_shark', 'c1'},
    );
  });

  test('removeTag deletes the pair and is a no-op when absent', () async {
    await repository.addTag(mediaId: 'm1', speciesId: 'c1');

    await repository.removeTag(mediaId: 'm1', speciesId: 'c1');
    await repository.removeTag(mediaId: 'm1', speciesId: 'c1');

    expect(await repository.getTagsForMedia('m1'), isEmpty);
  });

  test('watchTagChanges ticks when a tag is written', () async {
    final ticks = <void>[];
    final sub = repository.watchTagChanges().listen(ticks.add);
    addTearDown(sub.cancel);

    await repository.addTag(mediaId: 'm2', speciesId: 'c1');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(ticks, isNotEmpty);
    // The database is what ticked, not the repository: a sync writing the
    // row directly must reach the same watchers.
    final db = DatabaseService.instance.database;
    expect(await db.select(db.mediaSpecies).get(), hasLength(1));
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/features/media/data/repositories/media_species_repository_test.dart`
Expected: compilation error, `media_species_repository.dart` not found.

- [ ] **Step 4: Write the repository**

`lib/features/media/data/repositories/media_species_repository.dart`:

```dart
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Species tags on photos: the `media_species` link table.
///
/// A tag sits on a photo that already belongs to a dive or a site; this
/// repository never creates media rows. The table has no `hlc` column, so
/// like `site_species` it syncs as a clockless child: add marks the row
/// pending, remove tombstones it by id, and the incremental export keys off
/// the parent `media.hlc`.
class MediaSpeciesRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const Uuid _uuid = Uuid();

  /// Bound-variable budget per `isIn` chunk, well under SQLite's 999 limit.
  static const int _chunkSize = 500;

  /// Ticks whenever `media_species` changes, from any writer.
  Stream<void> watchTagChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.mediaSpecies));

  Future<List<MediaSpeciesTag>> getTagsForMedia(String mediaId) async {
    final rows =
        await (_db.select(_db.mediaSpecies)
              ..where((t) => t.mediaId.equals(mediaId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows.map(_tagFromRow).toList();
  }

  /// Tags for many photos in one pass, keyed by media id. Photos without a
  /// tag are absent from the map.
  Future<Map<String, List<MediaSpeciesTag>>> getTagsForMediaIds(
    List<String> mediaIds,
  ) async {
    final result = <String, List<MediaSpeciesTag>>{};
    for (var i = 0; i < mediaIds.length; i += _chunkSize) {
      final chunk = mediaIds.sublist(i, min(i + _chunkSize, mediaIds.length));
      final rows = await (_db.select(
        _db.mediaSpecies,
      )..where((t) => t.mediaId.isIn(chunk))).get();
      for (final row in rows) {
        result.putIfAbsent(row.mediaId, () => []).add(_tagFromRow(row));
      }
    }
    return result;
  }

  /// Tags [mediaId] with [speciesId]. Returns the existing tag when the pair
  /// is already linked: uniqueness lives here, not in a schema constraint.
  Future<MediaSpeciesTag> addTag({
    required String mediaId,
    required String speciesId,
    String? sightingId,
  }) async {
    final existing = await _findTag(mediaId, speciesId);
    if (existing != null) return _tagFromRow(existing);

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.mediaSpecies)
        .insert(
          MediaSpeciesCompanion(
            id: Value(id),
            mediaId: Value(mediaId),
            speciesId: Value(speciesId),
            sightingId: Value(sightingId),
            createdAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'mediaSpecies',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();

    return MediaSpeciesTag(
      id: id,
      mediaId: mediaId,
      speciesId: speciesId,
      sightingId: sightingId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  /// Removes the tag linking [mediaId] and [speciesId], tombstoning it by
  /// row id so other devices drop the same row. No-op when absent.
  Future<void> removeTag({
    required String mediaId,
    required String speciesId,
  }) async {
    final existing = await _findTag(mediaId, speciesId);
    if (existing == null) return;

    await (_db.delete(
      _db.mediaSpecies,
    )..where((t) => t.id.equals(existing.id))).go();
    await _syncRepository.logDeletion(
      entityType: 'mediaSpecies',
      recordId: existing.id,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<MediaSpecy?> _findTag(String mediaId, String speciesId) =>
      (_db.select(_db.mediaSpecies)
            ..where(
              (t) => t.mediaId.equals(mediaId) & t.speciesId.equals(speciesId),
            )
            ..limit(1))
          .getSingleOrNull();

  MediaSpeciesTag _tagFromRow(MediaSpecy row) => MediaSpeciesTag(
    id: row.id,
    mediaId: row.mediaId,
    speciesId: row.speciesId,
    sightingId: row.sightingId,
    bboxX: row.bboxX,
    bboxY: row.bboxY,
    bboxWidth: row.bboxWidth,
    bboxHeight: row.bboxHeight,
    notes: row.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
  );
}
```

If the analyzer reports that `MediaSpecy` is not the generated row class name, open `lib/core/database/database.g.dart`, search for `class MediaSpec`, and use the name it declares; the companion is `MediaSpeciesCompanion` either way.

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/data/repositories/media_species_repository_test.dart`
Expected: `All tests passed!` (6 tests), exit code 0.

- [ ] **Step 6: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format lib/features/media/data/repositories/media_species_repository.dart test/features/media/data/repositories/
git add lib/features/media/data/repositories/media_species_repository.dart test/features/media/data/repositories/species_photo_fixtures.dart test/features/media/data/repositories/media_species_repository_test.dart
git commit -m "feat(media): add MediaSpeciesRepository for species tags on photos"
```

---

### Task 2: Gallery, candidate, count and chip queries

**Files:**
- Create: `lib/features/media/domain/entities/species_tag_candidate_group.dart`
- Create: `lib/features/media/domain/entities/species_tag_chip.dart`
- Modify: `lib/features/media/data/repositories/media_species_repository.dart` (add methods after `removeTag`)
- Test: `test/features/media/data/repositories/media_species_queries_test.dart`

**Interfaces:**
- Consumes: Task 1; `mediaItemFromRow(MediaData row, [MediaEnrichmentData? enrichmentRow])` from `lib/features/media/data/repositories/media_row_mapper.dart`; `MediaItem.isDocument` from `media_item.dart`; `Species`, `SpeciesCategory`.
- Produces:
  ```dart
  class SpeciesTagCandidateGroup { diveId, diveNumber, diveDateTime, siteName, sightingId, List<MediaItem> items }
  class SpeciesTagChip { speciesId, storedName, category, isBuiltIn }
  Future<List<MediaItem>> getMediaForSpecies(String speciesId, {String? diverId});
  Future<List<SpeciesTagCandidateGroup>> getTagCandidatesForSpecies(String speciesId, {String? diverId});
  Future<List<SpeciesTagChip>> getTagChipsForMedia(String mediaId);
  Future<Map<String, int>> getPhotoCountsBySpeciesForDive(String diveId);
  Future<Map<String, MediaItem>> getCoverMediaBySpecies({String? diverId});
  Future<Map<String, int>> tagCountsBySpecies();
  ```

Background: the library's diver rule is `media.dive_id IS NULL OR dives.diver_id = ?`, which keeps site-only photos; copy it. `getMediaForDive` in `MediaRepository` is the join shape to reproduce (`select(media).join([leftOuterJoin(mediaEnrichment, ...)])` then `mediaItemFromRow(row.readTable(media), row.readTableOrNull(mediaEnrichment))`). Drift's `useColumns: false` on a join keeps that table out of the selected columns, which is what makes `distinct: true` meaningful. `isNotInQuery` takes a `selectOnly` statement.

- [ ] **Step 1: Write the entities**

`lib/features/media/domain/entities/species_tag_candidate_group.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';

/// One dive on which a species was sighted, with the photos on that dive
/// that are not yet tagged with it. Feeds the tag picker's grouped grid.
class SpeciesTagCandidateGroup extends Equatable {
  final String diveId;
  final int? diveNumber;
  final DateTime diveDateTime;
  final String? siteName;

  /// The dive's sighting of the species; a tag made from this group links
  /// to it.
  final String sightingId;
  final List<MediaItem> items;

  const SpeciesTagCandidateGroup({
    required this.diveId,
    this.diveNumber,
    required this.diveDateTime,
    this.siteName,
    required this.sightingId,
    required this.items,
  });

  SpeciesTagCandidateGroup copyWith({
    String? diveId,
    int? diveNumber,
    DateTime? diveDateTime,
    String? siteName,
    String? sightingId,
    List<MediaItem>? items,
  }) {
    return SpeciesTagCandidateGroup(
      diveId: diveId ?? this.diveId,
      diveNumber: diveNumber ?? this.diveNumber,
      diveDateTime: diveDateTime ?? this.diveDateTime,
      siteName: siteName ?? this.siteName,
      sightingId: sightingId ?? this.sightingId,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
    diveId,
    diveNumber,
    diveDateTime,
    siteName,
    sightingId,
    items,
  ];
}
```

`lib/features/media/domain/entities/species_tag_chip.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// A species tag as the viewer shows it: enough to render a chip and to
/// localize the name at display time (built-ins resolve through their id).
class SpeciesTagChip extends Equatable {
  final String speciesId;
  final String storedName;
  final SpeciesCategory category;
  final bool isBuiltIn;

  const SpeciesTagChip({
    required this.speciesId,
    required this.storedName,
    required this.category,
    required this.isBuiltIn,
  });

  SpeciesTagChip copyWith({
    String? speciesId,
    String? storedName,
    SpeciesCategory? category,
    bool? isBuiltIn,
  }) {
    return SpeciesTagChip(
      speciesId: speciesId ?? this.speciesId,
      storedName: storedName ?? this.storedName,
      category: category ?? this.category,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  List<Object?> get props => [speciesId, storedName, category, isBuiltIn];
}
```

- [ ] **Step 2: Write the failing query tests**

`test/features/media/data/repositories/media_species_queries_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../../helpers/test_database.dart';
import 'species_photo_fixtures.dart';

/// diver-a: d1 (Blue Hole, Jan, #101) with photos p1, p2, p3 and a PDF doc1;
///          d2 (no site, Mar, #102) with photo p4.
/// diver-b: d3 (Shark Point, May) with photo p5.
/// site-only photo s1 (Blue Hole, no dive).
/// Whale shark sighted on d1 (sg1), d2 (sg2), d3 (sg3). Turtle on d1 (sg4).
Future<void> seed() async {
  await insertTestDiver('diver-a');
  await insertTestDiver('diver-b');
  await insertTestSite('s1', 'Blue Hole');
  await insertTestSite('s2', 'Shark Point');
  await insertTestDive(
    id: 'd1',
    at: DateTime(2024, 1, 10),
    diverId: 'diver-a',
    siteId: 's1',
    number: 101,
  );
  await insertTestDive(
    id: 'd2',
    at: DateTime(2024, 3, 5),
    diverId: 'diver-a',
    number: 102,
  );
  await insertTestDive(
    id: 'd3',
    at: DateTime(2024, 5, 1),
    diverId: 'diver-b',
    siteId: 's2',
    number: 7,
  );
  await insertTestSpecies(
    id: 'sp_whale_shark',
    name: 'Whale Shark',
    category: SpeciesCategory.shark,
    builtIn: true,
  );
  await insertTestSpecies(
    id: 'sp_green_sea_turtle',
    name: 'Green Sea Turtle',
    category: SpeciesCategory.turtle,
    builtIn: true,
  );
  await insertTestSighting(id: 'sg1', diveId: 'd1', speciesId: 'sp_whale_shark');
  await insertTestSighting(id: 'sg2', diveId: 'd2', speciesId: 'sp_whale_shark');
  await insertTestSighting(id: 'sg3', diveId: 'd3', speciesId: 'sp_whale_shark');
  await insertTestSighting(
    id: 'sg4',
    diveId: 'd1',
    speciesId: 'sp_green_sea_turtle',
  );
  await insertTestMedia(id: 'p1', diveId: 'd1', takenAt: DateTime(2024, 1, 10, 9));
  await insertTestMedia(id: 'p2', diveId: 'd1', takenAt: DateTime(2024, 1, 10, 10));
  await insertTestMedia(id: 'p3', diveId: 'd1', takenAt: DateTime(2024, 1, 10, 11));
  await insertTestMedia(id: 'doc1', diveId: 'd1', fileType: 'document');
  await insertTestMedia(id: 'p4', diveId: 'd2', takenAt: DateTime(2024, 3, 5, 9));
  await insertTestMedia(id: 'p5', diveId: 'd3', takenAt: DateTime(2024, 5, 1, 9));
  await insertTestMedia(id: 's1', siteId: 's1', takenAt: DateTime(2024, 6, 1));
}

void main() {
  late MediaSpeciesRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = MediaSpeciesRepository();
    await seed();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('getMediaForSpecies', () {
    test('returns tagged photos newest first, once each, scoped to the diver',
        () async {
      await repository.addTag(mediaId: 'p1', speciesId: 'sp_whale_shark');
      await repository.addTag(mediaId: 'p4', speciesId: 'sp_whale_shark');
      await repository.addTag(mediaId: 'p5', speciesId: 'sp_whale_shark');
      await repository.addTag(mediaId: 'p2', speciesId: 'sp_green_sea_turtle');

      final mine = await repository.getMediaForSpecies(
        'sp_whale_shark',
        diverId: 'diver-a',
      );
      final everyone = await repository.getMediaForSpecies('sp_whale_shark');

      expect(mine.map((m) => m.id).toList(), ['p4', 'p1']);
      expect(everyone.map((m) => m.id).toList(), ['p5', 'p4', 'p1']);
    });

    test('keeps a site-only photo under a diver scope', () async {
      await repository.addTag(mediaId: 's1', speciesId: 'sp_whale_shark');

      final mine = await repository.getMediaForSpecies(
        'sp_whale_shark',
        diverId: 'diver-a',
      );

      expect(mine.map((m) => m.id).toList(), ['s1']);
    });
  });

  group('getTagCandidatesForSpecies', () {
    test('groups untagged photos by dive with the sighting, newest dive first',
        () async {
      await repository.addTag(
        mediaId: 'p1',
        speciesId: 'sp_whale_shark',
        sightingId: 'sg1',
      );

      final groups = await repository.getTagCandidatesForSpecies(
        'sp_whale_shark',
        diverId: 'diver-a',
      );

      expect(groups.map((g) => g.diveId).toList(), ['d2', 'd1']);
      final d1 = groups.last;
      expect(d1.sightingId, 'sg1');
      expect(d1.diveNumber, 101);
      expect(d1.siteName, 'Blue Hole');
      // p1 is already tagged and doc1 is a document: both excluded.
      expect(d1.items.map((m) => m.id).toSet(), {'p2', 'p3'});
      expect(groups.first.siteName, isNull);
      expect(groups.first.items.map((m) => m.id).toList(), ['p4']);
    });

    test('omits dives whose photos are all tagged and other divers\' dives',
        () async {
      await repository.addTag(mediaId: 'p4', speciesId: 'sp_whale_shark');

      final groups = await repository.getTagCandidatesForSpecies(
        'sp_whale_shark',
        diverId: 'diver-a',
      );

      expect(groups.map((g) => g.diveId).toList(), ['d1']);
    });

    test('is empty for a species never sighted', () async {
      await insertTestSpecies(id: 'c9', name: 'Nobody');
      expect(await repository.getTagCandidatesForSpecies('c9'), isEmpty);
    });
  });

  test('getTagChipsForMedia joins the species row in tag order', () async {
    await repository.addTag(mediaId: 'p1', speciesId: 'sp_green_sea_turtle');
    await repository.addTag(mediaId: 'p1', speciesId: 'sp_whale_shark');

    final chips = await repository.getTagChipsForMedia('p1');

    expect(chips.map((c) => c.speciesId).toList(), [
      'sp_green_sea_turtle',
      'sp_whale_shark',
    ]);
    expect(chips.first.storedName, 'Green Sea Turtle');
    expect(chips.first.category, SpeciesCategory.turtle);
    expect(chips.first.isBuiltIn, isTrue);
  });

  test('getPhotoCountsBySpeciesForDive counts distinct photos per species',
      () async {
    await repository.addTag(mediaId: 'p1', speciesId: 'sp_whale_shark');
    await repository.addTag(mediaId: 'p2', speciesId: 'sp_whale_shark');
    await repository.addTag(mediaId: 'p2', speciesId: 'sp_green_sea_turtle');
    await repository.addTag(mediaId: 'p4', speciesId: 'sp_whale_shark');

    final counts = await repository.getPhotoCountsBySpeciesForDive('d1');

    expect(counts, {'sp_whale_shark': 2, 'sp_green_sea_turtle': 1});
  });

  test('getCoverMediaBySpecies picks the newest tagged photo per species',
      () async {
    await repository.addTag(mediaId: 'p1', speciesId: 'sp_whale_shark');
    await repository.addTag(mediaId: 'p4', speciesId: 'sp_whale_shark');
    await repository.addTag(mediaId: 'p5', speciesId: 'sp_whale_shark');
    await repository.addTag(mediaId: 'p2', speciesId: 'sp_green_sea_turtle');

    final mine = await repository.getCoverMediaBySpecies(diverId: 'diver-a');
    final everyone = await repository.getCoverMediaBySpecies();

    expect(mine['sp_whale_shark']!.id, 'p4');
    expect(mine['sp_green_sea_turtle']!.id, 'p2');
    expect(everyone['sp_whale_shark']!.id, 'p5');
  });

  test('tagCountsBySpecies counts rows per species', () async {
    await repository.addTag(mediaId: 'p1', speciesId: 'sp_whale_shark');
    await repository.addTag(mediaId: 'p2', speciesId: 'sp_whale_shark');

    expect(await repository.tagCountsBySpecies(), {'sp_whale_shark': 2});
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/data/repositories/media_species_queries_test.dart`
Expected: compilation errors, `getMediaForSpecies` and friends are not defined.

- [ ] **Step 4: Add the queries**

Add these imports to `media_species_repository.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/species_tag_candidate_group.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
```

Add these methods to the class after `removeTag`:

```dart
  /// Every photo tagged with [speciesId], newest first, once each.
  ///
  /// Scoped to [diverId] through the photo's dive while keeping site-only
  /// photos, the library's own rule (`media.dive_id IS NULL OR
  /// dives.diver_id = ?`).
  Future<List<MediaItem>> getMediaForSpecies(
    String speciesId, {
    String? diverId,
  }) async {
    final m = _db.media;
    final query =
        _db.select(m, distinct: true).join([
            innerJoin(
              _db.mediaSpecies,
              _db.mediaSpecies.mediaId.equalsExp(m.id),
              useColumns: false,
            ),
            leftOuterJoin(
              _db.mediaEnrichment,
              _db.mediaEnrichment.mediaId.equalsExp(m.id),
            ),
            leftOuterJoin(
              _db.dives,
              _db.dives.id.equalsExp(m.diveId),
              useColumns: false,
            ),
          ])
          ..where(
            _db.mediaSpecies.speciesId.equals(speciesId) &
                _diverScope(diverId),
          )
          ..orderBy([OrderingTerm.desc(m.takenAt), OrderingTerm.asc(m.id)]);
    final rows = await query.get();
    return rows
        .map(
          (row) => mediaItemFromRow(
            row.readTable(m),
            row.readTableOrNull(_db.mediaEnrichment),
          ),
        )
        .toList();
  }

  /// Photos the diver could tag with [speciesId]: the photos and videos on
  /// dives with a sighting of it that carry no tag for it yet, grouped by
  /// dive, newest dive first. Documents are not candidates.
  Future<List<SpeciesTagCandidateGroup>> getTagCandidatesForSpecies(
    String speciesId, {
    String? diverId,
  }) async {
    final diverClause = diverId != null ? 'AND d.diver_id = ?' : '';
    final diveRows = await _db
        .customSelect(
          '''
      SELECT s.id AS sighting_id, d.id AS dive_id, d.dive_number,
             d.dive_date_time, ds.name AS site_name
      FROM sightings s
      JOIN dives d ON d.id = s.dive_id
      LEFT JOIN dive_sites ds ON ds.id = d.site_id
      WHERE s.species_id = ? $diverClause
      ORDER BY d.dive_date_time DESC, s.id ASC
    ''',
          variables: [
            Variable.withString(speciesId),
            if (diverId != null) Variable.withString(diverId),
          ],
        )
        .get();
    if (diveRows.isEmpty) return const [];

    // One group per dive even if the dive logged the species twice.
    final seenDives = <String>{};
    final headers = diveRows.where(
      (r) => seenDives.add(r.read<String>('dive_id')),
    );
    final diveIds = headers.map((r) => r.read<String>('dive_id')).toList();

    final taggedIds = _db.selectOnly(_db.mediaSpecies)
      ..addColumns([_db.mediaSpecies.mediaId])
      ..where(_db.mediaSpecies.speciesId.equals(speciesId));
    final m = _db.media;
    final mediaQuery =
        _db.select(m).join([
            leftOuterJoin(
              _db.mediaEnrichment,
              _db.mediaEnrichment.mediaId.equalsExp(m.id),
            ),
          ])
          ..where(m.diveId.isIn(diveIds) & m.id.isNotInQuery(taggedIds))
          ..orderBy([OrderingTerm.asc(m.takenAt), OrderingTerm.asc(m.id)]);
    final byDive = <String, List<MediaItem>>{};
    for (final row in await mediaQuery.get()) {
      final item = mediaItemFromRow(
        row.readTable(m),
        row.readTableOrNull(_db.mediaEnrichment),
      );
      if (item.isDocument) continue;
      byDive.putIfAbsent(item.diveId!, () => []).add(item);
    }

    return [
      for (final r in headers)
        if (byDive[r.read<String>('dive_id')] case final items?
            when items.isNotEmpty)
          SpeciesTagCandidateGroup(
            diveId: r.read<String>('dive_id'),
            diveNumber: r.read<int?>('dive_number'),
            diveDateTime: DateTime.fromMillisecondsSinceEpoch(
              r.read<int>('dive_date_time'),
            ),
            siteName: r.read<String?>('site_name'),
            sightingId: r.read<String>('sighting_id'),
            items: items,
          ),
    ];
  }

  /// The species tagged on one photo, in tag order, with what a chip needs.
  Future<List<SpeciesTagChip>> getTagChipsForMedia(String mediaId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT sp.id, sp.common_name, sp.category, sp.is_built_in
      FROM media_species ms
      JOIN species sp ON sp.id = ms.species_id
      WHERE ms.media_id = ?
      ORDER BY ms.created_at ASC, ms.id ASC
    ''',
          variables: [Variable.withString(mediaId)],
        )
        .get();
    return rows.map((row) {
      final categoryName = row.read<String>('category');
      return SpeciesTagChip(
        speciesId: row.read<String>('id'),
        storedName: row.read<String>('common_name'),
        category: SpeciesCategory.values.firstWhere(
          (c) => c.name == categoryName,
          orElse: () => SpeciesCategory.other,
        ),
        isBuiltIn: row.read<bool>('is_built_in'),
      );
    }).toList();
  }

  /// How many distinct photos on [diveId] are tagged with each species.
  Future<Map<String, int>> getPhotoCountsBySpeciesForDive(
    String diveId,
  ) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT ms.species_id, COUNT(DISTINCT ms.media_id) AS n
      FROM media_species ms
      JOIN media m ON m.id = ms.media_id
      WHERE m.dive_id = ?
      GROUP BY ms.species_id
    ''',
          variables: [Variable.withString(diveId)],
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('species_id'): row.read<int>('n'),
    };
  }

  /// The newest tagged photo per species, for cover thumbnails. Derived,
  /// never chosen: a chosen cover would live on the species row, and
  /// built-in species rows never sync.
  Future<Map<String, MediaItem>> getCoverMediaBySpecies({
    String? diverId,
  }) async {
    final diverClause = diverId != null
        ? 'AND (m.dive_id IS NULL OR d.diver_id = ?)'
        : '';
    final rows = await _db
        .customSelect(
          '''
      SELECT species_id, media_id FROM (
        SELECT ms.species_id, ms.media_id,
               ROW_NUMBER() OVER (
                 PARTITION BY ms.species_id
                 ORDER BY m.taken_at DESC, m.id ASC
               ) AS rn
        FROM media_species ms
        JOIN media m ON m.id = ms.media_id
        LEFT JOIN dives d ON d.id = m.dive_id
        WHERE 1=1 $diverClause
      ) WHERE rn = 1
    ''',
          variables: [if (diverId != null) Variable.withString(diverId)],
        )
        .get();
    if (rows.isEmpty) return const {};
    final coverIdBySpecies = {
      for (final row in rows)
        row.read<String>('species_id'): row.read<String>('media_id'),
    };
    final items = await _getMediaByIds(coverIdBySpecies.values.toList());
    return {
      for (final entry in coverIdBySpecies.entries)
        if (items[entry.value] case final item?) entry.key: item,
    };
  }

  /// Tag rows per species, the photo-side twin of
  /// `SpeciesRepository.sightingCountsBySpecies`.
  Future<Map<String, int>> tagCountsBySpecies() async {
    final rows = await _db
        .customSelect(
          'SELECT species_id, COUNT(*) AS n FROM media_species '
          'GROUP BY species_id',
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('species_id'): row.read<int>('n'),
    };
  }

  Future<Map<String, MediaItem>> _getMediaByIds(List<String> ids) async {
    final m = _db.media;
    final result = <String, MediaItem>{};
    for (var i = 0; i < ids.length; i += _chunkSize) {
      final chunk = ids.sublist(i, min(i + _chunkSize, ids.length));
      final query = _db.select(m).join([
        leftOuterJoin(
          _db.mediaEnrichment,
          _db.mediaEnrichment.mediaId.equalsExp(m.id),
        ),
      ])..where(m.id.isIn(chunk));
      for (final row in await query.get()) {
        final item = mediaItemFromRow(
          row.readTable(m),
          row.readTableOrNull(_db.mediaEnrichment),
        );
        result[item.id] = item;
      }
    }
    return result;
  }

  Expression<bool> _diverScope(String? diverId) {
    if (diverId == null) return const Constant(true);
    return _db.media.diveId.isNull() | _db.dives.diverId.equals(diverId);
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/data/repositories/media_species_queries_test.dart test/features/media/data/repositories/media_species_repository_test.dart`
Expected: `All tests passed!` (15 tests), exit code 0. If `getMediaForSpecies` returns a photo twice, the `distinct: true` is not reaching the generated SQL: check that both `useColumns: false` flags are present, since any selected column from the joined tables defeats `DISTINCT`.

- [ ] **Step 6: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format lib/features/media/data/repositories/media_species_repository.dart lib/features/media/domain/entities test/features/media/data/repositories
git add lib/features/media/data/repositories/media_species_repository.dart lib/features/media/domain/entities/species_tag_candidate_group.dart lib/features/media/domain/entities/species_tag_chip.dart test/features/media/data/repositories/media_species_queries_test.dart
git commit -m "feat(media): add species gallery, tag candidate, count and chip queries"
```

---

### Task 3: Sync registration for `mediaSpecies`

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (the `SyncData` class field list, constructor, `toJson`, `fromJson`; `_baseTables`; the `_safeExport` block; the `fetchRecord`, `upsertRecord`, `upsertRecords`, `recordIdsFor`, `_syncTableFor` and `deleteRecord` switches; a new `_exportMediaSpecies`)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder`, `entityHasUpdatedAt`, `parentRefs`, and the comment above the extra-entities block)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart`, `sync_serializer_upsert_test.dart`, `sync_data_serializer_batch_coverage_test.dart`, `sync_serializer_fetch_record_test.dart`
- Test: `test/core/services/sync/sync_media_species_registration_test.dart` (new)

**Interfaces:**
- Consumes: Task 1's `MediaSpeciesRepository.addTag` (for the registration test); the Drift row class `MediaSpecy` and table `_db.mediaSpecies`.
- Produces: the sync entity type string `'mediaSpecies'`, exported under the JSON key `mediaSpecies`, merged after `media` and `species`.

Background: every `siteSpecies` touch point in these two files is the template; `mediaSpecies` is inserted **immediately after** each one so the ordering assertions (the streaming parity test compares `_baseTables` order with `SyncData.toJson` key order) keep holding. In `_exportSiteSpecies`, the incremental branch selects rows whose *parent* changed (`diveSites.hlc > hlcSince`) because the child has no clock; the media twin filters by `media.hlc`.

- [ ] **Step 1: Write the failing registration test**

`test/core/services/sync/sync_media_species_registration_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../features/media/data/repositories/species_photo_fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestMedia(id: 'p1', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a tag written through the repository is fetchable by sync type',
      () async {
    final tag = await MediaSpeciesRepository().addTag(
      mediaId: 'p1',
      speciesId: 'c1',
    );

    final record = await serializer.fetchRecord('mediaSpecies', tag.id);

    expect(record, isNotNull);
    expect(record!['mediaId'], 'p1');
    expect(record['speciesId'], 'c1');
  });

  test('upsertRecord and deleteRecord round-trip a remote tag', () async {
    await serializer.upsertRecord('mediaSpecies', {
      'id': 'mst-remote',
      'mediaId': 'p1',
      'speciesId': 'c1',
      'createdAt': 1000,
    });
    expect(await serializer.fetchRecord('mediaSpecies', 'mst-remote'), isNotNull);

    await serializer.deleteRecord('mediaSpecies', 'mst-remote');

    expect(await serializer.fetchRecord('mediaSpecies', 'mst-remote'), isNull);
  });

  test('SyncData carries mediaSpecies through toJson and fromJson', () {
    const data = SyncData(
      mediaSpecies: [
        {'id': 'mst-1', 'mediaId': 'p1', 'speciesId': 'c1', 'createdAt': 1},
      ],
    );

    final restored = SyncData.fromJson(data.toJson());

    expect(restored.mediaSpecies.single['id'], 'mst-1');
  });

  test('mediaSpecies merges as a clockless child of media and species', () {
    expect(SyncService.entityHasUpdatedAt['mediaSpecies'], isFalse);
    final refs = SyncService.parentRefs['mediaSpecies']!;
    expect(
      refs.map((r) => (r.field, r.parent, r.nullable)).toSet(),
      {('mediaId', 'media', false), ('speciesId', 'species', false)},
    );
  });
}
```

If `SyncService.entityHasUpdatedAt` or `SyncService.parentRefs` are not accessible under those names, open `sync_service.dart` around the `'siteSpecies': false,` line and the `'siteSpecies': [` parentRefs entry to read their declared names and visibility, and adjust the last test to whatever the file exposes (an `@visibleForTesting` getter is acceptable to add if neither is reachable).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/sync_media_species_registration_test.dart`
Expected: compilation error (`mediaSpecies` is not a `SyncData` parameter) or runtime failures on the unknown entity type.

- [ ] **Step 3: Register the entity in the serializer**

In `lib/core/services/sync/sync_data_serializer.dart`, make these six edits, each directly after the `siteSpecies` line it names:

1. Field (after `final List<Map<String, dynamic>> siteSpecies;`):
```dart
  final List<Map<String, dynamic>> mediaSpecies;
```
2. Constructor default (after `this.siteSpecies = const [],`):
```dart
    this.mediaSpecies = const [],
```
3. `toJson` (after `'siteSpecies': siteSpecies,`):
```dart
    'mediaSpecies': mediaSpecies,
```
4. `fromJson` (after `siteSpecies: _parseList(json['siteSpecies']),`):
```dart
      mediaSpecies: _parseList(json['mediaSpecies']),
```
5. `_baseTables` (after `(key: 'siteSpecies', table: _db.siteSpecies, blob: false, full: null),`):
```dart
    (key: 'mediaSpecies', table: _db.mediaSpecies, blob: false, full: null),
```
6. The export block (after the `siteSpecies: await _safeExport('siteSpecies', ...)` entry):
```dart
      mediaSpecies: await _safeExport(
        'mediaSpecies',
        () => _exportMediaSpecies(hlcSince),
      ),
```

Then add a `case 'mediaSpecies':` arm directly after each `case 'siteSpecies':` arm in the six switches:

`fetchRecord`:
```dart
      case 'mediaSpecies':
        final row = await (_db.select(
          _db.mediaSpecies,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

`upsertRecord`:
```dart
      case 'mediaSpecies':
        await _db
            .into(_db.mediaSpecies)
            .insertOnConflictUpdate(
              MediaSpecy.fromJson(_withTimestampDefaults(data)),
            );
        return;
```

`upsertRecords`:
```dart
      case 'mediaSpecies':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.mediaSpecies,
            records
                .map((r) => MediaSpecy.fromJson(_withTimestampDefaults(r)))
                .toList(),
          ),
        );
        return;
```

`recordIdsFor`:
```dart
      case 'mediaSpecies':
        return plain(_db.mediaSpecies, _db.mediaSpecies.id);
```

`_syncTableFor`:
```dart
      case 'mediaSpecies':
        return _db.mediaSpecies;
```

`deleteRecord`:
```dart
      case 'mediaSpecies':
        await (_db.delete(
          _db.mediaSpecies,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

And add the export method directly after `_exportSiteSpecies`:

```dart
  /// `media_species` has no clock of its own, so an incremental export
  /// ships the tags of every photo whose `media.hlc` advanced; a full export
  /// ships the table.
  Future<List<Map<String, dynamic>>> _exportMediaSpecies(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedMedia = await (_db.select(
        _db.media,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final mediaIds = modifiedMedia.map((m) => m.id).toSet();
      if (mediaIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.mediaSpecies,
      )..where((t) => t.mediaId.isIn(mediaIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.mediaSpecies).get();
    return rows.map((r) => r.toJson()).toList();
  }
```

- [ ] **Step 4: Register the entity in the sync service**

In `lib/core/services/sync/sync_service.dart`:

1. In `mergeOrder`, after `(type: 'siteSpecies', records: data.siteSpecies, hasUpdatedAt: false),` add:
```dart
          (
            type: 'mediaSpecies',
            records: data.mediaSpecies,
            hasUpdatedAt: false,
          ),
```
   and in the comment above that block change "Four are append-only ... (no updatedAt column: diveCustomFields, diveDataSources, siteSpecies, fieldPresets)" to "Five are append-only ... (no updatedAt column: diveCustomFields, diveDataSources, siteSpecies, mediaSpecies, fieldPresets)".
2. In the `entityHasUpdatedAt` map, after `'siteSpecies': false,` add:
```dart
    'mediaSpecies': false,
```
3. In `parentRefs`, after the `'siteSpecies': [...]` entry add:
```dart
    'mediaSpecies': [
      (field: 'mediaId', parent: 'media', nullable: false),
      (field: 'speciesId', parent: 'species', nullable: false),
    ],
```
   `sightingId` gets no entry: `sightings` is not a deletable parent in that map, and the FK already sets it null.

- [ ] **Step 5: Extend the enumerating tests**

- `test/core/services/sync/sync_parent_refs_completeness_test.dart`: after `    'site_species': 'siteSpecies',` add `    'media_species': 'mediaSpecies',`.
- `test/core/services/sync/sync_serializer_upsert_test.dart`: after `(type: 'siteSpecies', table: db.siteSpecies.actualTableName),` add `(type: 'mediaSpecies', table: db.mediaSpecies.actualTableName),`.
- `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart`: same addition after its `siteSpecies` tuple.
- `test/core/services/sync/sync_serializer_fetch_record_test.dart`: after `      'siteSpecies',` in the string list add `      'mediaSpecies',`, and after the `(type: 'siteSpecies', table: db.siteSpecies.actualTableName),` tuple add the `mediaSpecies` tuple.

- [ ] **Step 6: Run the new test and the whole sync suite**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/core/services/sync/`
Expected: `All tests passed!`, exit code 0. If `sync_base_streaming_parity_test.dart` fails on key order, the `_baseTables` entry is not directly after `siteSpecies`; move it. If the parent-refs completeness test still fails, read its message: it names the table, field and expected nullability.

- [ ] **Step 7: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format lib/core/services/sync test/core/services/sync
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/
git commit -m "feat(sync): register media_species as a clockless child of media and species"
```

---

### Task 4: Integrity rules: tags count as "in use", unlink warnings, media watch stream

**Files:**
- Modify: `lib/features/marine_life/data/repositories/species_repository.dart` (`isSpeciesInUse`, `deleteSpecies`)
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`watchMediaChanges`, `idsWithUserMetadata` and its doc comment)
- Modify: `lib/features/marine_life/presentation/pages/species_manage_page.dart` (delete eligibility)
- Create: `lib/features/media/presentation/providers/species_media_providers.dart` (only `mediaSpeciesRepositoryProvider` and `speciesTagCountsProvider` for now; Task 6 adds the rest)
- Test: `test/features/marine_life/data/repositories/species_repository_tags_test.dart` (new), `test/features/media/data/repositories/media_repository_species_test.dart` (new)
- Regression: `test/features/marine_life/presentation/pages/species_manage_page_test.dart` (must stay green)

**Interfaces:**
- Consumes: Tasks 1 and 2 (`MediaSpeciesRepository.tagCountsBySpecies`, `watchTagChanges`).
- Produces: `speciesTagCountsProvider: FutureProvider<Map<String, int>>`; `SpeciesRepository.isSpeciesInUse` true when tags exist; `deleteSpecies` removes the species' tags; `MediaRepository.idsWithUserMetadata` includes tagged photos; `watchMediaChanges` ticks on `media_species`.

- [ ] **Step 1: Write the failing repository tests**

`test/features/marine_life/data/repositories/species_repository_tags_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../../helpers/test_database.dart';
import '../../../media/data/repositories/species_photo_fixtures.dart';

void main() {
  late SpeciesRepository species;
  late MediaSpeciesRepository tags;

  setUp(() async {
    await setUpTestDatabase();
    species = SpeciesRepository();
    tags = MediaSpeciesRepository();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestMedia(id: 'p1', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a species with a photo tag but no sighting is in use', () async {
    expect(await species.isSpeciesInUse('c1'), isFalse);

    await tags.addTag(mediaId: 'p1', speciesId: 'c1');

    expect(await species.isSpeciesInUse('c1'), isTrue);
  });

  test('deleteSpecies refuses while a tag exists', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'c1');

    expect(() => species.deleteSpecies('c1'), throwsException);
  });

  test('deleteSpecies removes stale tag rows of an unused species', () async {
    // Simulate a tag that outlived the in-use check (foreign keys are off
    // in tests, so the cascade cannot do it for us).
    await tags.addTag(mediaId: 'p1', speciesId: 'c1');
    await tags.removeTag(mediaId: 'p1', speciesId: 'c1');
    final db = DatabaseService.instance.database;
    expect(await db.select(db.mediaSpecies).get(), isEmpty);

    await species.deleteSpecies('c1');

    expect(await species.getSpeciesById('c1'), isNull);
  });
}
```

`test/features/media/data/repositories/media_repository_species_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../../helpers/test_database.dart';
import 'species_photo_fixtures.dart';

void main() {
  late MediaRepository media;
  late MediaSpeciesRepository tags;

  setUp(() async {
    await setUpTestDatabase();
    media = MediaRepository();
    tags = MediaSpeciesRepository();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a tagged photo counts as carrying user metadata', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'c1');

    expect(await media.idsWithUserMetadata(['p1', 'p2']), {'p1'});
  });

  test('watchMediaChanges ticks when a tag is written', () async {
    final ticks = <void>[];
    final sub = media.watchMediaChanges().listen(ticks.add);
    addTearDown(sub.cancel);

    await tags.addTag(mediaId: 'p2', speciesId: 'c1');
    // The stream is debounced; give it time to flush.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(ticks, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/marine_life/data/repositories/species_repository_tags_test.dart test/features/media/data/repositories/media_repository_species_test.dart`
Expected: the "in use", "refuses" and "user metadata" tests fail; the watch test may fail.

- [ ] **Step 3: Implement the rules**

In `species_repository.dart`, replace `isSpeciesInUse` with:

```dart
  /// Whether anything references the species: a sighting on a dive or a
  /// tag on a photo. Both are diver data, so both block deletion.
  Future<bool> isSpeciesInUse(String id) async {
    final result = await _db
        .customSelect(
          '''
      SELECT
        (SELECT COUNT(*) FROM sightings WHERE species_id = ?) +
        (SELECT COUNT(*) FROM media_species WHERE species_id = ?) AS count
    ''',
          variables: [Variable.withString(id), Variable.withString(id)],
        )
        .getSingle();
    return (result.data['count'] as int) > 0;
  }
```

In `deleteSpecies`, after the `site_species` delete block add:

```dart
    // Tags of an unused species are stale rows (the in-use check above
    // refuses while any exist); clear them the way site_species is cleared,
    // relying on the species tombstone downstream.
    await (_db.delete(
      _db.mediaSpecies,
    )..where((t) => t.speciesId.equals(id))).go();
```

and change the doc comment to `/// Delete a species. Throws if the species is referenced by sightings or photo tags.` and the exception text to `'Cannot delete species that is referenced by sightings or photo tags'`.

In `media_repository.dart`, replace the `watchMediaChanges` table list with:

```dart
        TableUpdateQuery.onAllTables([
          _db.media,
          _db.mediaEnrichment,
          _db.mediaSpecies,
        ]),
```

and replace `idsWithUserMetadata` and its doc comment with:

```dart
  /// Ids of [mediaIds] whose rows carry something the diver typed that the
  /// source file does not hold: a caption, the favorite flag, or a species
  /// tag.
  ///
  /// Used to decide whether an unlink needs to warn before it removes the
  /// rows.
  Future<Set<String>> idsWithUserMetadata(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return {};
    final rows =
        await (_db.select(_db.media)..where(
              (t) =>
                  t.id.isIn(mediaIds) &
                  (t.isFavorite.equals(true) |
                      (t.caption.isNotNull() & t.caption.equals('').not())),
            ))
            .get();
    final tagged = await (_db.selectOnly(_db.mediaSpecies)
          ..addColumns([_db.mediaSpecies.mediaId])
          ..where(_db.mediaSpecies.mediaId.isIn(mediaIds)))
        .get();
    return {
      for (final row in rows) row.id,
      for (final row in tagged) row.read(_db.mediaSpecies.mediaId)!,
    };
  }
```

Create `lib/features/media/presentation/providers/species_media_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

final mediaSpeciesRepositoryProvider = Provider<MediaSpeciesRepository>((ref) {
  return MediaSpeciesRepository();
});

/// Photo-tag rows per species, the twin of `speciesSightingCountsProvider`:
/// the catalog manager refuses to delete a species that either one counts.
final speciesTagCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(mediaSpeciesRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTagChanges());
  return repository.tagCountsBySpecies();
});
```

In `species_manage_page.dart`: add the import
`import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';`,
add a field `Map<String, int> _tagCounts = const {};` under `_sightingCounts`, change `_isSelectable` to

```dart
  bool _isSelectable(Species s) =>
      !s.isBuiltIn &&
      (_sightingCounts[s.id] ?? 0) == 0 &&
      (_tagCounts[s.id] ?? 0) == 0;
```

and in `build`, directly after the `_sightingCounts = ...` assignment add
`_tagCounts = ref.watch(speciesTagCountsProvider).value ?? const {};`.
Where the page invalidates `speciesSightingCountsProvider` after a delete, also `ref.invalidate(speciesTagCountsProvider);`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/marine_life/data/repositories/species_repository_tags_test.dart test/features/media/data/repositories/media_repository_species_test.dart test/features/marine_life/presentation/pages/species_manage_page_test.dart test/features/marine_life/data/repositories/species_repository_test.dart`
Expected: `All tests passed!`, exit code 0. The manage page test overrides `speciesSightingCountsProvider` but not the new provider; if it now reaches the database, add `speciesTagCountsProvider.overrideWith((ref) async => const {})` to that test's `host()` overrides next to the sighting-counts override.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format lib/features/marine_life lib/features/media test/features/marine_life test/features/media
git add lib/features/marine_life/data/repositories/species_repository.dart lib/features/media/data/repositories/media_repository.dart lib/features/marine_life/presentation/pages/species_manage_page.dart lib/features/media/presentation/providers/species_media_providers.dart test/features/marine_life/data/repositories/species_repository_tags_test.dart test/features/media/data/repositories/media_repository_species_test.dart test/features/marine_life/presentation/pages/species_manage_page_test.dart
git commit -m "feat(marine-life): treat photo tags as species usage and user metadata"
```

---

### Task 5: `SpeciesTaggingService`

**Files:**
- Create: `lib/features/media/data/services/species_tagging_service.dart`
- Test: `test/features/media/data/services/species_tagging_service_test.dart`

**Interfaces:**
- Consumes: `MediaSpeciesRepository.addTag/removeTag` (Task 1); `MediaRepository.getMediaById(String) -> Future<MediaItem?>`; `SpeciesRepository.getSightingsForDive(String) -> Future<List<Sighting>>` and `addSighting({required String diveId, required String speciesId, int count = 1, String notes = ''}) -> Future<Sighting>`; `Sighting.id`, `Sighting.speciesId` from `lib/features/marine_life/domain/entities/species.dart`.
- Produces:
  ```dart
  class TagPhotosResult { final int tagged; final Map<String, String> failures; }
  class SpeciesTaggingService {
    SpeciesTaggingService({required MediaSpeciesRepository tags, required MediaRepository media, required SpeciesRepository species});
    Future<MediaSpeciesTag> tagPhoto({required String mediaId, required String speciesId});
    Future<TagPhotosResult> tagPhotos({required List<String> mediaIds, required String speciesId});
    Future<void> untagPhoto({required String mediaId, required String speciesId});
  }
  ```

- [ ] **Step 1: Write the failing service test**

`test/features/media/data/services/species_tagging_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';

import '../../../../helpers/test_database.dart';
import '../repositories/species_photo_fixtures.dart';

void main() {
  late SpeciesRepository species;
  late MediaSpeciesRepository tags;
  late SpeciesTaggingService service;

  setUp(() async {
    await setUpTestDatabase();
    species = SpeciesRepository();
    tags = MediaSpeciesRepository();
    service = SpeciesTaggingService(
      tags: tags,
      media: MediaRepository(),
      species: species,
    );
    await insertTestSite('s1', 'Blue Hole');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), siteId: 's1');
    await insertTestSpecies(id: 'sp_whale_shark', name: 'Whale Shark');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
    await insertTestMedia(id: 'site-photo', siteId: 's1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('tagging adds the missing sighting and links the tag to it', () async {
    expect(await species.getSightingsForDive('d1'), isEmpty);

    final tag = await service.tagPhoto(
      mediaId: 'p1',
      speciesId: 'sp_whale_shark',
    );

    final sightings = await species.getSightingsForDive('d1');
    expect(sightings.single.speciesId, 'sp_whale_shark');
    expect(sightings.single.count, 1);
    expect(tag.sightingId, sightings.single.id);
  });

  test('a second photo on the same dive reuses the sighting', () async {
    final first = await service.tagPhoto(
      mediaId: 'p1',
      speciesId: 'sp_whale_shark',
    );
    final second = await service.tagPhoto(
      mediaId: 'p2',
      speciesId: 'sp_whale_shark',
    );

    expect(second.sightingId, first.sightingId);
    expect(await species.getSightingsForDive('d1'), hasLength(1));
  });

  test('an existing sighting is linked, not duplicated', () async {
    final existing = await species.addSighting(
      diveId: 'd1',
      speciesId: 'sp_whale_shark',
      count: 3,
    );

    final tag = await service.tagPhoto(
      mediaId: 'p1',
      speciesId: 'sp_whale_shark',
    );

    expect(tag.sightingId, existing.id);
    expect((await species.getSightingsForDive('d1')).single.count, 3);
  });

  test('a site-only photo is tagged without a sighting', () async {
    final tag = await service.tagPhoto(
      mediaId: 'site-photo',
      speciesId: 'sp_whale_shark',
    );

    expect(tag.sightingId, isNull);
    expect(await species.getSightingsForDive('d1'), isEmpty);
  });

  test('untagging keeps the sighting', () async {
    await service.tagPhoto(mediaId: 'p1', speciesId: 'sp_whale_shark');

    await service.untagPhoto(mediaId: 'p1', speciesId: 'sp_whale_shark');

    expect(await tags.getTagsForMedia('p1'), isEmpty);
    expect(await species.getSightingsForDive('d1'), hasLength(1));
  });

  test('tagPhotos tags what it can and reports the rest', () async {
    final result = await service.tagPhotos(
      mediaIds: ['p1', 'missing', 'p2'],
      speciesId: 'sp_whale_shark',
    );

    expect(result.tagged, 2);
    expect(result.failures.keys, ['missing']);
    expect(await tags.getTagsForMedia('p1'), hasLength(1));
    expect(await tags.getTagsForMedia('p2'), hasLength(1));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/data/services/species_tagging_service_test.dart`
Expected: compilation error, `species_tagging_service.dart` not found.

- [ ] **Step 3: Write the service**

`lib/features/media/data/services/species_tagging_service.dart`:

```dart
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// What [SpeciesTaggingService.tagPhotos] managed to do.
class TagPhotosResult {
  final int tagged;

  /// Media id to failure message, for the photos that could not be tagged.
  final Map<String, String> failures;

  const TagPhotosResult({required this.tagged, this.failures = const {}});
}

/// Tags photos with species and keeps the dive log consistent while doing
/// it: a photo is evidence, so a tag on a dive photo adds the dive's
/// sighting of that species when none exists yet. Untagging never removes
/// a sighting; the diver may have logged it independently.
class SpeciesTaggingService {
  final MediaSpeciesRepository _tags;
  final MediaRepository _media;
  final SpeciesRepository _species;

  SpeciesTaggingService({
    required MediaSpeciesRepository tags,
    required MediaRepository media,
    required SpeciesRepository species,
  }) : _tags = tags,
       _media = media,
       _species = species;

  Future<MediaSpeciesTag> tagPhoto({
    required String mediaId,
    required String speciesId,
  }) async {
    final item = await _media.getMediaById(mediaId);
    if (item == null) {
      throw StateError('Media $mediaId does not exist');
    }
    final diveId = item.diveId;
    // A site-only photo has no dive to log the sighting on.
    if (diveId == null) {
      return _tags.addTag(mediaId: mediaId, speciesId: speciesId);
    }
    final sightingId = await _sightingIdFor(diveId, speciesId);
    return _tags.addTag(
      mediaId: mediaId,
      speciesId: speciesId,
      sightingId: sightingId,
    );
  }

  /// [tagPhoto] over many photos; one failure never stops the rest.
  Future<TagPhotosResult> tagPhotos({
    required List<String> mediaIds,
    required String speciesId,
  }) async {
    var tagged = 0;
    final failures = <String, String>{};
    for (final mediaId in mediaIds) {
      try {
        await tagPhoto(mediaId: mediaId, speciesId: speciesId);
        tagged += 1;
      } catch (e) {
        failures[mediaId] = e.toString();
      }
    }
    return TagPhotosResult(tagged: tagged, failures: failures);
  }

  Future<void> untagPhoto({
    required String mediaId,
    required String speciesId,
  }) => _tags.removeTag(mediaId: mediaId, speciesId: speciesId);

  Future<String> _sightingIdFor(String diveId, String speciesId) async {
    final sightings = await _species.getSightingsForDive(diveId);
    for (final sighting in sightings) {
      if (sighting.speciesId == speciesId) return sighting.id;
    }
    final created = await _species.addSighting(
      diveId: diveId,
      speciesId: speciesId,
    );
    return created.id;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/data/services/species_tagging_service_test.dart`
Expected: `All tests passed!` (6 tests), exit code 0.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format lib/features/media/data/services/species_tagging_service.dart test/features/media/data/services/species_tagging_service_test.dart
git add lib/features/media/data/services/species_tagging_service.dart test/features/media/data/services/species_tagging_service_test.dart
git commit -m "feat(media): add SpeciesTaggingService that keeps sightings in step with tags"
```

---

### Task 6: Providers for species media

**Files:**
- Modify: `lib/features/media/presentation/providers/species_media_providers.dart` (created in Task 4; add the rest)
- Test: `test/features/media/presentation/providers/species_media_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 2, 5; `mediaRepositoryProvider` from `lib/features/media/presentation/providers/media_providers.dart`; `speciesRepositoryProvider` from `lib/features/marine_life/presentation/providers/species_providers.dart` (with `watchSpeciesChanges()` and `watchSightingChanges()`); `currentDiverIdProvider` from `lib/features/divers/presentation/providers/diver_providers.dart`.
- Produces:
  ```dart
  final speciesTaggingServiceProvider = Provider<SpeciesTaggingService>;
  final mediaForSpeciesProvider = FutureProvider.family<List<MediaItem>, String>;          // speciesId
  final speciesTagCandidatesProvider = FutureProvider.family<List<SpeciesTagCandidateGroup>, String>; // speciesId
  final mediaTagChipsProvider = FutureProvider.family<List<SpeciesTagChip>, String>;      // mediaId
  ```

- [ ] **Step 1: Write the failing provider test**

`test/features/media/presentation/providers/species_media_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';

Future<T> _eventually<T>(
  Future<T> Function() read,
  bool Function(T value) until,
) async {
  late T value;
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    value = await read();
    if (until(value)) break;
  }
  return value;
}

void main() {
  late SharedPreferences prefs;
  late MediaSpeciesRepository tags;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    tags = MediaSpeciesRepository();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestSighting(id: 'sg1', diveId: 'd1', speciesId: 'c1');
    await insertTestMedia(id: 'p1', diveId: 'd1', takenAt: DateTime(2024, 1, 10, 9));
    await insertTestMedia(id: 'p2', diveId: 'd1', takenAt: DateTime(2024, 1, 10, 10));
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('mediaForSpeciesProvider refreshes when a tag is added', () async {
    final container = makeContainer();
    final sub = container.listen(mediaForSpeciesProvider('c1'), (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(mediaForSpeciesProvider('c1').future), isEmpty);

    await tags.addTag(mediaId: 'p2', speciesId: 'c1');

    final items = await _eventually(
      () => container.read(mediaForSpeciesProvider('c1').future),
      (v) => v.isNotEmpty,
    );
    expect(items.single.id, 'p2');
  });

  test('speciesTagCandidatesProvider drops a photo once it is tagged',
      () async {
    final container = makeContainer();
    final sub = container.listen(
      speciesTagCandidatesProvider('c1'),
      (_, _) {},
    );
    addTearDown(sub.close);
    final before = await container.read(speciesTagCandidatesProvider('c1').future);
    expect(before.single.items.map((m) => m.id).toList(), ['p1', 'p2']);

    await tags.addTag(mediaId: 'p1', speciesId: 'c1', sightingId: 'sg1');

    final after = await _eventually(
      () => container.read(speciesTagCandidatesProvider('c1').future),
      (v) => v.single.items.length == 1,
    );
    expect(after.single.items.single.id, 'p2');
  });

  test('mediaTagChipsProvider lists chips and refreshes on removal', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'c1');
    final container = makeContainer();
    final sub = container.listen(mediaTagChipsProvider('p1'), (_, _) {});
    addTearDown(sub.close);
    final chips = await container.read(mediaTagChipsProvider('p1').future);
    expect(chips.single.storedName, 'Grouper');

    await tags.removeTag(mediaId: 'p1', speciesId: 'c1');

    final after = await _eventually(
      () => container.read(mediaTagChipsProvider('p1').future),
      (v) => v.isEmpty,
    );
    expect(after, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/presentation/providers/species_media_providers_test.dart`
Expected: compilation errors, the three providers are not defined.

- [ ] **Step 3: Add the providers**

Replace the whole of `lib/features/media/presentation/providers/species_media_providers.dart` with:

```dart
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_candidate_group.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

final mediaSpeciesRepositoryProvider = Provider<MediaSpeciesRepository>((ref) {
  return MediaSpeciesRepository();
});

final speciesTaggingServiceProvider = Provider<SpeciesTaggingService>((ref) {
  return SpeciesTaggingService(
    tags: ref.watch(mediaSpeciesRepositoryProvider),
    media: ref.watch(mediaRepositoryProvider),
    species: ref.watch(speciesRepositoryProvider),
  );
});

/// Photo-tag rows per species, the twin of `speciesSightingCountsProvider`:
/// the catalog manager refuses to delete a species that either one counts.
final speciesTagCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(mediaSpeciesRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTagChanges());
  return repository.tagCountsBySpecies();
});

/// Every photo tagged with a species, newest first, for the current diver.
///
/// Not scoped by the Statistics filter: the species detail page is a
/// logbook surface. Ticks on tags and on media (a photo edit, unlink or
/// delete changes the gallery without touching `media_species`).
final mediaForSpeciesProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  speciesId,
) async {
  final repository = ref.watch(mediaSpeciesRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  ref.invalidateSelfWhen(repository.watchTagChanges());
  ref.invalidateSelfWhen(ref.watch(mediaRepositoryProvider).watchMediaChanges());
  return repository.getMediaForSpecies(speciesId, diverId: diverId);
});

/// Untagged photos on the dives where the species was sighted, grouped by
/// dive. Also ticks on sightings: logging the species on another dive
/// brings that dive's photos into the picker.
final speciesTagCandidatesProvider =
    FutureProvider.family<List<SpeciesTagCandidateGroup>, String>((
      ref,
      speciesId,
    ) async {
      final repository = ref.watch(mediaSpeciesRepositoryProvider);
      final speciesRepository = ref.watch(speciesRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      ref.invalidateSelfWhen(repository.watchTagChanges());
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      ref.invalidateSelfWhen(speciesRepository.watchSightingChanges());
      return repository.getTagCandidatesForSpecies(speciesId, diverId: diverId);
    });

/// The species tags on one photo, as the viewer's chips show them. Ticks on
/// species too, so a renamed custom species relabels its chip.
final mediaTagChipsProvider =
    FutureProvider.family<List<SpeciesTagChip>, String>((ref, mediaId) async {
      final repository = ref.watch(mediaSpeciesRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTagChanges());
      ref.invalidateSelfWhen(
        ref.watch(speciesRepositoryProvider).watchSpeciesChanges(),
      );
      return repository.getTagChipsForMedia(mediaId);
    });
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/presentation/providers/species_media_providers_test.dart test/features/marine_life/presentation/pages/species_manage_page_test.dart`
Expected: `All tests passed!`, exit code 0.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format lib/features/media/presentation/providers/species_media_providers.dart test/features/media/presentation/providers/species_media_providers_test.dart
git add lib/features/media/presentation/providers/species_media_providers.dart test/features/media/presentation/providers/species_media_providers_test.dart
git commit -m "feat(media): add species media providers"
```

---

### Task 7: Localization keys for phase A

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Test: `test/l10n/species_photos_strings_test.dart`

**Interfaces:**
- Produces `AppLocalizations` members: `media_species_actionTooltip`, `_sheetTitle`, `_sightedOnDive`, `_otherSpecies`, `_noDiveHint`, `_chipsLabel`; `marineLife_speciesPhotos_title(Object count)`, `_empty`, `_tagPhotos`, `_addPhotos`, `_thumbnailLabel`, `_importAdded(int)`, `_importSkipped(int)`, `_importFailed(int)`; `marineLife_tagPicker_title`, `_empty`, `_emptyHint`, `_selectAll`, `_confirm(int)`, `_tagged(int)`, `_diveLabel(Object number)`.

Background: the ARB files are feature blocks, not sorted; new keys are inserted after an anchor key present in every locale (`media_info_title` for the `media_species_*` keys, `marineLife_speciesManage_searchHint` for the rest), with `@` placeholder metadata directly after each key in `app_en.arb` only. `test/l10n/arb_parity_test.dart` enforces that every locale has every English key with matching placeholders.

- [ ] **Step 1: Write the failing strings test**

`test/l10n/species_photos_strings_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('species photo strings exist in English', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(l10n.marineLife_speciesPhotos_title(3), 'Photos (3)');
    expect(l10n.marineLife_speciesPhotos_tagPhotos, 'Tag photos');
    expect(l10n.marineLife_tagPicker_confirm(1), 'Tag 1 photo');
    expect(l10n.marineLife_tagPicker_confirm(4), 'Tag 4 photos');
    expect(l10n.marineLife_speciesPhotos_importAdded(2), '2 photos added');
    expect(l10n.media_species_sheetTitle, 'Species in this photo');
    expect(l10n.marineLife_tagPicker_diveLabel(101), 'Dive 101');
  });

  test('species photo strings are translated in German', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));

    expect(l10n.marineLife_speciesPhotos_tagPhotos, 'Fotos markieren');
    expect(l10n.marineLife_tagPicker_confirm(4), '4 Fotos markieren');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/l10n/species_photos_strings_test.dart`
Expected: compilation error, `marineLife_speciesPhotos_title` is not defined.

- [ ] **Step 3: Insert the keys with the script**

Save as `/private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/1a1e1ff7-4477-4b97-b07b-8de224f521ea/scratchpad/add_species_photo_keys.py` (throwaway, not committed) and run it from the worktree root with `python3`:

```python
import json, re, sys
from pathlib import Path

ROOT = Path('lib/l10n/arb')
ANCHORS = {
    'media_': 'media_info_title',
    'marineLife_': 'marineLife_speciesManage_searchHint',
}

KEYS = [
    ('media_species_actionTooltip', None),
    ('media_species_sheetTitle', None),
    ('media_species_sightedOnDive', None),
    ('media_species_otherSpecies', None),
    ('media_species_noDiveHint', None),
    ('media_species_chipsLabel', None),
    ('marineLife_speciesPhotos_title', {'count': 'Object'}),
    ('marineLife_speciesPhotos_empty', None),
    ('marineLife_speciesPhotos_tagPhotos', None),
    ('marineLife_speciesPhotos_addPhotos', None),
    ('marineLife_speciesPhotos_thumbnailLabel', None),
    ('marineLife_speciesPhotos_importAdded', {'count': 'int'}),
    ('marineLife_speciesPhotos_importSkipped', {'count': 'int'}),
    ('marineLife_speciesPhotos_importFailed', {'count': 'int'}),
    ('marineLife_tagPicker_title', None),
    ('marineLife_tagPicker_empty', None),
    ('marineLife_tagPicker_emptyHint', None),
    ('marineLife_tagPicker_selectAll', None),
    ('marineLife_tagPicker_confirm', {'count': 'int'}),
    ('marineLife_tagPicker_tagged', {'count': 'int'}),
    ('marineLife_tagPicker_diveLabel', {'number': 'Object'}),
]

VALUES = {
    'en': [
        'Species', 'Species in this photo', 'Sighted on this dive',
        'Other species...',
        'This photo is not linked to a dive. Search for a species to tag it.',
        'Species tags',
        'Photos ({count})', 'Photos tagged with this species appear here.',
        'Tag photos', 'Add photos', 'Species photo',
        '{count, plural, =1{1 photo added} other{{count} photos added}}',
        '{count, plural, =1{1 skipped} other{{count} skipped}}',
        '{count, plural, =1{1 failed} other{{count} failed}}',
        'Tag photos',
        'No untagged photos on dives where you logged this species.',
        'Use Add photos to import pictures from your camera roll.',
        'Select all',
        '{count, plural, =1{Tag 1 photo} other{Tag {count} photos}}',
        '{count, plural, =1{Tagged 1 photo} other{Tagged {count} photos}}',
        'Dive {number}',
    ],
    'de': [
        'Arten', 'Arten auf diesem Foto', 'Bei diesem Tauchgang gesichtet',
        'Andere Arten...',
        'Dieses Foto ist keinem Tauchgang zugeordnet. Suchen Sie eine Art, um es zu markieren.',
        'Artenmarkierungen',
        'Fotos ({count})',
        'Fotos, die mit dieser Art markiert sind, erscheinen hier.',
        'Fotos markieren', 'Fotos hinzufügen', 'Artenfoto',
        '{count, plural, =1{1 Foto hinzugefügt} other{{count} Fotos hinzugefügt}}',
        '{count, plural, =1{1 übersprungen} other{{count} übersprungen}}',
        '{count, plural, =1{1 fehlgeschlagen} other{{count} fehlgeschlagen}}',
        'Fotos markieren',
        'Keine unmarkierten Fotos bei Tauchgängen, bei denen Sie diese Art protokolliert haben.',
        'Verwenden Sie Fotos hinzufügen, um Bilder aus Ihren Aufnahmen zu importieren.',
        'Alle auswählen',
        '{count, plural, =1{1 Foto markieren} other{{count} Fotos markieren}}',
        '{count, plural, =1{1 Foto markiert} other{{count} Fotos markiert}}',
        'Tauchgang {number}',
    ],
    'es': [
        'Especies', 'Especies en esta foto', 'Avistadas en esta inmersión',
        'Otras especies...',
        'Esta foto no está vinculada a una inmersión. Busca una especie para etiquetarla.',
        'Etiquetas de especies',
        'Fotos ({count})',
        'Las fotos etiquetadas con esta especie aparecen aquí.',
        'Etiquetar fotos', 'Añadir fotos', 'Foto de la especie',
        '{count, plural, =1{1 foto añadida} other{{count} fotos añadidas}}',
        '{count, plural, =1{1 omitida} other{{count} omitidas}}',
        '{count, plural, =1{1 con error} other{{count} con error}}',
        'Etiquetar fotos',
        'No hay fotos sin etiquetar en las inmersiones donde registraste esta especie.',
        'Usa Añadir fotos para importar imágenes de tu carrete.',
        'Seleccionar todo',
        '{count, plural, =1{Etiquetar 1 foto} other{Etiquetar {count} fotos}}',
        '{count, plural, =1{1 foto etiquetada} other{{count} fotos etiquetadas}}',
        'Inmersión {number}',
    ],
    'fr': [
        'Espèces', 'Espèces sur cette photo', 'Observées lors de cette plongée',
        'Autres espèces...',
        "Cette photo n'est liée à aucune plongée. Recherchez une espèce pour l'étiqueter.",
        "Étiquettes d'espèces",
        'Photos ({count})',
        'Les photos étiquetées avec cette espèce apparaissent ici.',
        'Étiqueter des photos', 'Ajouter des photos', "Photo de l'espèce",
        '{count, plural, =1{1 photo ajoutée} other{{count} photos ajoutées}}',
        '{count, plural, =1{1 ignorée} other{{count} ignorées}}',
        '{count, plural, =1{1 en échec} other{{count} en échec}}',
        'Étiqueter des photos',
        'Aucune photo non étiquetée sur les plongées où vous avez consigné cette espèce.',
        'Utilisez Ajouter des photos pour importer des images depuis votre pellicule.',
        'Tout sélectionner',
        '{count, plural, =1{Étiqueter 1 photo} other{Étiqueter {count} photos}}',
        '{count, plural, =1{1 photo étiquetée} other{{count} photos étiquetées}}',
        'Plongée {number}',
    ],
    'it': [
        'Specie', 'Specie in questa foto', 'Avvistate in questa immersione',
        'Altre specie...',
        "Questa foto non è collegata a un'immersione. Cerca una specie per taggarla.",
        'Tag delle specie',
        'Foto ({count})', 'Le foto taggate con questa specie compaiono qui.',
        'Tagga foto', 'Aggiungi foto', 'Foto della specie',
        '{count, plural, =1{1 foto aggiunta} other{{count} foto aggiunte}}',
        '{count, plural, =1{1 saltata} other{{count} saltate}}',
        '{count, plural, =1{1 non riuscita} other{{count} non riuscite}}',
        'Tagga foto',
        'Nessuna foto senza tag nelle immersioni in cui hai registrato questa specie.',
        'Usa Aggiungi foto per importare immagini dal rullino.',
        'Seleziona tutto',
        '{count, plural, =1{Tagga 1 foto} other{Tagga {count} foto}}',
        '{count, plural, =1{1 foto taggata} other{{count} foto taggate}}',
        'Immersione {number}',
    ],
    'pt': [
        'Espécies', 'Espécies nesta foto', 'Avistadas neste mergulho',
        'Outras espécies...',
        'Esta foto não está vinculada a um mergulho. Pesquise uma espécie para marcá-la.',
        'Marcações de espécies',
        'Fotos ({count})', 'As fotos marcadas com esta espécie aparecem aqui.',
        'Marcar fotos', 'Adicionar fotos', 'Foto da espécie',
        '{count, plural, =1{1 foto adicionada} other{{count} fotos adicionadas}}',
        '{count, plural, =1{1 ignorada} other{{count} ignoradas}}',
        '{count, plural, =1{1 com falha} other{{count} com falha}}',
        'Marcar fotos',
        'Nenhuma foto sem marcação nos mergulhos em que você registrou esta espécie.',
        'Use Adicionar fotos para importar imagens do seu rolo da câmera.',
        'Selecionar tudo',
        '{count, plural, =1{Marcar 1 foto} other{Marcar {count} fotos}}',
        '{count, plural, =1{1 foto marcada} other{{count} fotos marcadas}}',
        'Mergulho {number}',
    ],
    'nl': [
        'Soorten', 'Soorten op deze foto', 'Gezien tijdens deze duik',
        'Andere soorten...',
        'Deze foto is niet aan een duik gekoppeld. Zoek een soort om de foto te taggen.',
        'Soorttags',
        "Foto's ({count})", "Foto's die met deze soort zijn getagd verschijnen hier.",
        "Foto's taggen", "Foto's toevoegen", 'Soortfoto',
        "{count, plural, =1{1 foto toegevoegd} other{{count} foto's toegevoegd}}",
        '{count, plural, =1{1 overgeslagen} other{{count} overgeslagen}}',
        '{count, plural, =1{1 mislukt} other{{count} mislukt}}',
        "Foto's taggen",
        'Geen ongetagde foto\'s bij duiken waar je deze soort hebt gelogd.',
        "Gebruik Foto's toevoegen om beelden uit je camerarol te importeren.",
        'Alles selecteren',
        "{count, plural, =1{1 foto taggen} other{{count} foto's taggen}}",
        "{count, plural, =1{1 foto getagd} other{{count} foto's getagd}}",
        'Duik {number}',
    ],
    'hu': [
        'Fajok', 'Fajok ezen a fotón', 'Ezen a merülésen észlelve',
        'Más fajok...',
        'Ez a fotó nincs merüléshez kapcsolva. Keress egy fajt a címkézéshez.',
        'Fajcímkék',
        'Fotók ({count})', 'Az ezzel a fajjal címkézett fotók itt jelennek meg.',
        'Fotók címkézése', 'Fotók hozzáadása', 'Fajfotó',
        '{count, plural, =1{1 fotó hozzáadva} other{{count} fotó hozzáadva}}',
        '{count, plural, =1{1 kihagyva} other{{count} kihagyva}}',
        '{count, plural, =1{1 sikertelen} other{{count} sikertelen}}',
        'Fotók címkézése',
        'Nincs címkézetlen fotó azokon a merüléseken, ahol ezt a fajt naplóztad.',
        'Használd a Fotók hozzáadása gombot képek importálásához a kameratekercsből.',
        'Összes kijelölése',
        '{count, plural, =1{1 fotó címkézése} other{{count} fotó címkézése}}',
        '{count, plural, =1{1 fotó címkézve} other{{count} fotó címkézve}}',
        '{number}. merülés',
    ],
    'zh': [
        '物种', '这张照片中的物种', '本次潜水目击', '其他物种...',
        '这张照片未关联到潜水记录。搜索物种以添加标签。', '物种标签',
        '照片 ({count})', '标记为该物种的照片会显示在这里。',
        '标记照片', '添加照片', '物种照片',
        '{count, plural, =1{已添加 1 张照片} other{已添加 {count} 张照片}}',
        '{count, plural, =1{跳过 1 张} other{跳过 {count} 张}}',
        '{count, plural, =1{1 张失败} other{{count} 张失败}}',
        '标记照片', '在记录过该物种的潜水中没有未标记的照片。',
        '使用“添加照片”从相册导入图片。', '全选',
        '{count, plural, =1{标记 1 张照片} other{标记 {count} 张照片}}',
        '{count, plural, =1{已标记 1 张照片} other{已标记 {count} 张照片}}',
        '第 {number} 次潜水',
    ],
    'ar': [
        'الأنواع', 'الأنواع في هذه الصورة', 'شوهدت في هذه الغوصة',
        'أنواع أخرى...',
        'هذه الصورة غير مرتبطة بغوصة. ابحث عن نوع لوسمها.', 'وسوم الأنواع',
        'الصور ({count})', 'الصور الموسومة بهذا النوع تظهر هنا.',
        'وسم الصور', 'إضافة صور', 'صورة النوع',
        '{count, plural, =1{تمت إضافة صورة واحدة} other{تمت إضافة {count} صور}}',
        '{count, plural, =1{تم تخطي صورة واحدة} other{تم تخطي {count}}}',
        '{count, plural, =1{فشلت صورة واحدة} other{فشل {count}}}',
        'وسم الصور',
        'لا توجد صور غير موسومة في الغوصات التي سجلت فيها هذا النوع.',
        'استخدم إضافة صور لاستيراد الصور من ألبوم الكاميرا.', 'تحديد الكل',
        '{count, plural, =1{وسم صورة واحدة} other{وسم {count} صور}}',
        '{count, plural, =1{تم وسم صورة واحدة} other{تم وسم {count} صور}}',
        'الغوصة {number}',
    ],
    'he': [
        'מינים', 'מינים בתמונה זו', 'נצפו בצלילה זו', 'מינים אחרים...',
        'התמונה אינה מקושרת לצלילה. חפשו מין כדי לתייג אותה.', 'תגיות מינים',
        'תמונות ({count})', 'תמונות שתויגו במין זה יופיעו כאן.',
        'תיוג תמונות', 'הוספת תמונות', 'תמונת מין',
        '{count, plural, =1{תמונה אחת נוספה} other{{count} תמונות נוספו}}',
        '{count, plural, =1{אחת דולגה} other{{count} דולגו}}',
        '{count, plural, =1{אחת נכשלה} other{{count} נכשלו}}',
        'תיוג תמונות', 'אין תמונות ללא תגית בצלילות שבהן תיעדתם מין זה.',
        'השתמשו בהוספת תמונות כדי לייבא תמונות מגלריית המצלמה.', 'בחירת הכול',
        '{count, plural, =1{תיוג תמונה אחת} other{תיוג {count} תמונות}}',
        '{count, plural, =1{תמונה אחת תויגה} other{{count} תמונות תויגו}}',
        'צלילה {number}',
    ],
}

def key_line(key, value):
    return '  ' + json.dumps(key) + ': ' + json.dumps(value, ensure_ascii=False) + ',\n'

def meta_lines(key, placeholders):
    out = ['  ' + json.dumps('@' + key) + ': {\n', '    "placeholders": {\n']
    items = list(placeholders.items())
    for i, (name, typ) in enumerate(items):
        comma = ',' if i < len(items) - 1 else ''
        out += ['      ' + json.dumps(name) + ': {\n',
                '        "type": ' + json.dumps(typ) + '\n',
                '      }' + comma + '\n']
    out += ['    }\n', '  },\n']
    return out

def find_anchor(lines, anchor):
    pattern = re.compile(r'^  "' + re.escape(anchor) + r'": ')
    hits = [i for i, l in enumerate(lines) if pattern.match(l)]
    if len(hits) != 1:
        sys.exit(f'anchor {anchor} found {len(hits)} times')
    return hits[0]

for locale, values in VALUES.items():
    if len(values) != len(KEYS):
        sys.exit(f'{locale}: {len(values)} values for {len(KEYS)} keys')
    path = ROOT / f'app_{locale}.arb'
    text = path.read_text(encoding='utf-8')
    for key, _ in KEYS:
        if f'"{key}"' in text:
            sys.exit(f'{locale}: {key} already present')
    lines = text.splitlines(keepends=True)
    blocks = {anchor: [] for anchor in ANCHORS.values()}
    for (key, placeholders), value in zip(KEYS, values):
        block = [key_line(key, value)]
        if locale == 'en' and placeholders:
            block += meta_lines(key, placeholders)
        prefix = next(p for p in ANCHORS if key.startswith(p))
        blocks[ANCHORS[prefix]].extend(block)
    for anchor, block in sorted(
        blocks.items(), key=lambda pair: find_anchor(lines, pair[0]), reverse=True
    ):
        at = find_anchor(lines, anchor) + 1
        lines[at:at] = block
    new_text = ''.join(lines)
    json.loads(new_text)
    path.write_text(new_text, encoding='utf-8')
    print(f'{locale}: added {len(KEYS)} keys')
```

Run:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
python3 /private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/1a1e1ff7-4477-4b97-b07b-8de224f521ea/scratchpad/add_species_photo_keys.py
flutter gen-l10n
```

Expected: eleven `added 21 keys` lines.

- [ ] **Step 4: Run the strings test and the parity test**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/l10n/species_photos_strings_test.dart test/l10n/arb_parity_test.dart`
Expected: `All tests passed!`, exit code 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
git add lib/l10n/arb test/l10n/species_photos_strings_test.dart
git commit -m "feat(l10n): add species photo, tag picker and viewer species strings"
```

---

### Task 8: `SpeciesPhotoViewerPage`

**Files:**
- Create: `lib/features/media/presentation/pages/species_photo_viewer_page.dart`
- Test: `test/features/media/presentation/pages/species_photo_viewer_page_test.dart`

**Interfaces:**
- Consumes: `mediaForSpeciesProvider` (Task 6); `MediaViewerPage({required List<MediaItem> mediaList, required String initialMediaId, bool showGoToDive = false})` from `lib/features/media/presentation/pages/media_viewer_page.dart`.
- Produces: `SpeciesPhotoViewerPage({required String speciesId, required String initialMediaId})`.

- [ ] **Step 1: Write the failing widget test**

`test/features/media/presentation/pages/species_photo_viewer_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/pages/species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';

import '../support/media_widget_harness.dart';

void main() {
  testWidgets('resolves the species gallery and hands off to the viewer', (
    tester,
  ) async {
    final items = [
      testMediaItem(id: 'p1', diveId: 'd1', takenAt: DateTime(2024, 1, 10)),
      testMediaItem(id: 'p2', diveId: 'd1', takenAt: DateTime(2024, 1, 11)),
    ];
    await tester.pumpWidget(
      await mediaTestApp(
        home: const SpeciesPhotoViewerPage(
          speciesId: 'sp_x',
          initialMediaId: 'p2',
        ),
        overrides: [
          mediaForSpeciesProvider('sp_x').overrideWith((ref) async => items),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    final viewer = tester.widget<MediaViewerPage>(find.byType(MediaViewerPage));
    expect(viewer.mediaList.map((m) => m.id).toList(), ['p1', 'p2']);
    expect(viewer.initialMediaId, 'p2');
    expect(viewer.showGoToDive, isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/presentation/pages/species_photo_viewer_page_test.dart`
Expected: compilation error, `species_photo_viewer_page.dart` not found.

- [ ] **Step 3: Write the page**

`lib/features/media/presentation/pages/species_photo_viewer_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';

/// Species-scoped wrapper around [MediaViewerPage]: resolves every photo
/// tagged with the species reactively, then hands off. The viewer internals
/// (zoom, video, overlays, share, dive context) live in MediaViewerPage;
/// this only loads the list, like the trip and dive wrappers.
class SpeciesPhotoViewerPage extends ConsumerWidget {
  const SpeciesPhotoViewerPage({
    super.key,
    required this.speciesId,
    required this.initialMediaId,
  });

  final String speciesId;

  /// The photo to open on.
  final String initialMediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaForSpeciesProvider(speciesId));
    return mediaAsync.when(
      data: (mediaList) => MediaViewerPage(
        mediaList: mediaList,
        initialMediaId: initialMediaId,
        // The gallery spans dives, so the viewer offers the jump to each.
        showGoToDive: true,
      ),
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('$error', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/presentation/pages/species_photo_viewer_page_test.dart`
Expected: `All tests passed!`, exit code 0. If `MediaViewerPage` needs providers the harness does not supply (the test will name the provider in its error), add the same overrides `test/features/media/presentation/pages/site_media_viewer_page_test.dart` uses for the viewer.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format lib/features/media/presentation/pages/species_photo_viewer_page.dart test/features/media/presentation/pages/species_photo_viewer_page_test.dart
git add lib/features/media/presentation/pages/species_photo_viewer_page.dart test/features/media/presentation/pages/species_photo_viewer_page_test.dart
git commit -m "feat(media): add the species photo viewer wrapper"
```

---

### Task 9: `SpeciesPhotosSection` on the species detail page

**Files:**
- Create: `lib/features/media/presentation/widgets/species_photos_section.dart`
- Modify: `lib/features/marine_life/presentation/pages/species_detail_page.dart` (the `Column` children in `build`, between `_buildStatisticsSection(context, ref),` and `SpeciesSightingsSection(speciesId: speciesId),`; imports)
- Test: `test/features/media/presentation/widgets/species_photos_section_test.dart`

**Interfaces:**
- Consumes: `mediaForSpeciesProvider` (Task 6); `MediaThumbnailTile({item, settings, isSelectionMode, isSelected, semanticsLabel})` and `MediaEmptyState({icon, message})` from `lib/features/media/presentation/widgets/media_grid.dart`; `settingsProvider`; `SpeciesPhotoViewerPage` (Task 8); Task 7 strings.
- Produces: `SpeciesPhotosSection({required String speciesId, VoidCallback? onTagPhotos, VoidCallback? onAddPhotos})`. Each action button renders only when its callback is non-null; Tasks 10 and 11 supply them.

- [ ] **Step 1: Write the failing widget test**

`test/features/media/presentation/widgets/species_photos_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/species_photos_section.dart';

import '../support/media_widget_harness.dart';

Future<void> _pump(
  WidgetTester tester,
  List<MediaItem> items, {
  VoidCallback? onTagPhotos,
  VoidCallback? onAddPhotos,
}) async {
  await tester.pumpWidget(
    await mediaTestApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SpeciesPhotosSection(
            speciesId: 'sp_x',
            onTagPhotos: onTagPhotos,
            onAddPhotos: onAddPhotos,
          ),
        ),
      ),
      overrides: [
        mediaForSpeciesProvider('sp_x').overrideWith((ref) async => items),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final items = [
    testMediaItem(id: 'p1', diveId: 'd1', takenAt: DateTime(2024, 1, 11)),
    testMediaItem(id: 'p2', diveId: 'd1', takenAt: DateTime(2024, 1, 10)),
  ];

  testWidgets('renders a titled grid of tagged photos', (tester) async {
    await _pump(tester, items);

    expect(find.text('Photos (2)'), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
    expect(find.byType(MediaEmptyState), findsNothing);
  });

  testWidgets('shows the empty state with the actions still available', (
    tester,
  ) async {
    await _pump(tester, const [], onTagPhotos: () {}, onAddPhotos: () {});

    expect(find.text('Photos (0)'), findsOneWidget);
    expect(find.byType(MediaEmptyState), findsOneWidget);
    expect(find.text('Tag photos'), findsOneWidget);
    expect(find.text('Add photos'), findsOneWidget);
  });

  testWidgets('hides an action whose callback is absent', (tester) async {
    await _pump(tester, items, onAddPhotos: () {});

    expect(find.text('Tag photos'), findsNothing);
    expect(find.text('Add photos'), findsOneWidget);
  });

  testWidgets('the actions call back', (tester) async {
    var tagged = false;
    var added = false;
    await _pump(
      tester,
      items,
      onTagPhotos: () => tagged = true,
      onAddPhotos: () => added = true,
    );

    await tester.tap(find.text('Tag photos'));
    await tester.tap(find.text('Add photos'));

    expect(tagged, isTrue);
    expect(added, isTrue);
  });

  testWidgets('tapping a thumbnail opens the species viewer on that photo', (
    tester,
  ) async {
    await _pump(tester, items);

    await tester.tap(find.byType(MediaThumbnailTile).last);
    await tester.pumpAndSettle();

    final viewer = tester.widget<SpeciesPhotoViewerPage>(
      find.byType(SpeciesPhotoViewerPage),
    );
    expect(viewer.speciesId, 'sp_x');
    expect(viewer.initialMediaId, 'p2');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/presentation/widgets/species_photos_section_test.dart`
Expected: compilation error, `species_photos_section.dart` not found.

- [ ] **Step 3: Write the section and mount it**

`lib/features/media/presentation/widgets/species_photos_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The photos tagged with one species, on the species detail page.
///
/// A titled three-column grid with two header actions. Either action is
/// hidden when its callback is null, so the section can be mounted before
/// the flows behind the buttons exist.
class SpeciesPhotosSection extends ConsumerWidget {
  final String speciesId;
  final VoidCallback? onTagPhotos;
  final VoidCallback? onAddPhotos;

  const SpeciesPhotosSection({
    super.key,
    required this.speciesId,
    this.onTagPhotos,
    this.onAddPhotos,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mediaAsync = ref.watch(mediaForSpeciesProvider(speciesId));
    final settings = ref.watch(settingsProvider);
    final items = mediaAsync.value ?? const <MediaItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.marineLife_speciesPhotos_title(items.length),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (onTagPhotos != null)
              TextButton.icon(
                key: const ValueKey('species_tag_photos'),
                onPressed: onTagPhotos,
                icon: const Icon(Icons.sell_outlined),
                label: Text(l10n.marineLife_speciesPhotos_tagPhotos),
              ),
            if (onAddPhotos != null)
              TextButton.icon(
                key: const ValueKey('species_add_photos'),
                onPressed: onAddPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(l10n.marineLife_speciesPhotos_addPhotos),
              ),
          ],
        ),
        const SizedBox(height: 8),
        mediaAsync.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(
            '$error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          data: (items) {
            if (items.isEmpty) {
              return MediaEmptyState(
                icon: Icons.photo_library_outlined,
                message: l10n.marineLife_speciesPhotos_empty,
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openViewer(context, item),
                  child: MediaThumbnailTile(
                    item: item,
                    settings: settings,
                    isSelectionMode: false,
                    isSelected: false,
                    semanticsLabel:
                        l10n.marineLife_speciesPhotos_thumbnailLabel,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _openViewer(BuildContext context, MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SpeciesPhotoViewerPage(
          speciesId: speciesId,
          initialMediaId: item.id,
        ),
      ),
    );
  }
}
```

In `species_detail_page.dart`, add the import
`import 'package:submersion/features/media/presentation/widgets/species_photos_section.dart';`
and, between `_buildStatisticsSection(context, ref),` and `SpeciesSightingsSection(speciesId: speciesId),`, insert:

```dart
                SpeciesPhotosSection(speciesId: speciesId),
```

(The two callbacks are added by Tasks 10 and 11.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/presentation/widgets/species_photos_section_test.dart`
Expected: `All tests passed!` (5 tests), exit code 0.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format lib/features/media/presentation/widgets/species_photos_section.dart lib/features/marine_life/presentation/pages/species_detail_page.dart test/features/media/presentation/widgets/species_photos_section_test.dart
git add lib/features/media/presentation/widgets/species_photos_section.dart lib/features/marine_life/presentation/pages/species_detail_page.dart test/features/media/presentation/widgets/species_photos_section_test.dart
git commit -m "feat(marine-life): show a species' tagged photos on its detail page"
```

---

### Task 10: `SpeciesTagPickerPage` and the "Tag photos" action

**Files:**
- Create: `lib/features/media/presentation/pages/species_tag_picker_page.dart`
- Modify: `lib/features/marine_life/presentation/pages/species_detail_page.dart` (pass `onTagPhotos` to `SpeciesPhotosSection`, convert the page's `build` to open the picker and show the result)
- Test: `test/features/media/presentation/pages/species_tag_picker_page_test.dart`

**Interfaces:**
- Consumes: `speciesTagCandidatesProvider` and `speciesTaggingServiceProvider` (Task 6); `SpeciesTagCandidateGroup` (Task 2); `TagPhotosResult` (Task 5); `SelectionController` (`lib/shared/selection/selection_controller.dart`: `toggle(id)`, `selectAll(ids)`, `deselectAll()`, `value.checkedIds`); `MediaThumbnailTile`; `UnitFormatter`; Task 7 strings.
- Produces: `SpeciesTagPickerPage({required String speciesId})`, pushed with `Navigator.push<TagPhotosResult>`; pops with the `TagPhotosResult` after tagging, or null when dismissed.

Background: the whole page is a picker, so every tile renders in selection mode and toggles on tap; there is no drag-select and no "exit selection" state, which keeps the per-group index bookkeeping of `DragSelectGridView` out of it. Selection is keyed by media id in a `SelectionController` so "Select all" and the confirm count span all groups.

- [ ] **Step 1: Write the failing widget test**

`test/features/media/presentation/pages/species_tag_picker_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/species_tag_candidate_group.dart';
import 'package:submersion/features/media/presentation/pages/species_tag_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';

import '../support/media_widget_harness.dart';

/// Records what the page asks to tag instead of touching a database.
class _RecordingTaggingService extends SpeciesTaggingService {
  _RecordingTaggingService()
    : super(
        tags: MediaSpeciesRepository(),
        media: MediaRepository(),
        species: SpeciesRepository(),
      );

  final List<String> taggedIds = [];
  String? taggedSpecies;

  @override
  Future<TagPhotosResult> tagPhotos({
    required List<String> mediaIds,
    required String speciesId,
  }) async {
    taggedIds.addAll(mediaIds);
    taggedSpecies = speciesId;
    return TagPhotosResult(tagged: mediaIds.length);
  }
}

List<SpeciesTagCandidateGroup> _groups() => [
  SpeciesTagCandidateGroup(
    diveId: 'd2',
    diveNumber: 102,
    diveDateTime: DateTime(2024, 3, 5),
    siteName: null,
    sightingId: 'sg2',
    items: [testMediaItem(id: 'p4', diveId: 'd2')],
  ),
  SpeciesTagCandidateGroup(
    diveId: 'd1',
    diveNumber: 101,
    diveDateTime: DateTime(2024, 1, 10),
    siteName: 'Blue Hole',
    sightingId: 'sg1',
    items: [
      testMediaItem(id: 'p2', diveId: 'd1'),
      testMediaItem(id: 'p3', diveId: 'd1'),
    ],
  ),
];

Future<TagPhotosResult?> Function() _pumpPicker(
  WidgetTester tester,
  List<SpeciesTagCandidateGroup> groups,
  _RecordingTaggingService service,
) {
  TagPhotosResult? popped;
  var pumped = false;
  Future<void> pump() async {
    await tester.pumpWidget(
      await mediaTestApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<TagPhotosResult>(
                    MaterialPageRoute(
                      builder: (_) =>
                          const SpeciesTagPickerPage(speciesId: 'sp_x'),
                    ),
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
        overrides: [
          speciesTagCandidatesProvider('sp_x').overrideWith(
            (ref) async => groups,
          ),
          speciesTaggingServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    pumped = true;
  }

  return () async {
    if (!pumped) await pump();
    return popped;
  };
}

void main() {
  testWidgets('groups candidates by dive with a header per dive', (
    tester,
  ) async {
    final service = _RecordingTaggingService();
    final read = _pumpPicker(tester, _groups(), service);
    await read();

    expect(find.byType(MediaThumbnailTile), findsNWidgets(3));
    expect(find.textContaining('Dive 102'), findsOneWidget);
    expect(find.textContaining('Blue Hole'), findsOneWidget);
    expect(find.textContaining('Unknown site'), findsOneWidget);
  });

  testWidgets('the confirm button counts the selection and tags it', (
    tester,
  ) async {
    final service = _RecordingTaggingService();
    final read = _pumpPicker(tester, _groups(), service);
    await read();

    expect(find.text('Tag 0 photos'), findsNothing);
    final confirm = find.byKey(const ValueKey('tag_picker_confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byType(MediaThumbnailTile).at(1));
    await tester.tap(find.byType(MediaThumbnailTile).at(2));
    await tester.pump();
    expect(find.text('Tag 2 photos'), findsOneWidget);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(service.taggedSpecies, 'sp_x');
    expect(service.taggedIds.toSet(), {'p2', 'p3'});
    final popped = await read();
    expect(popped?.tagged, 2);
  });

  testWidgets('Select all checks every candidate across groups', (
    tester,
  ) async {
    final service = _RecordingTaggingService();
    final read = _pumpPicker(tester, _groups(), service);
    await read();

    await tester.tap(find.byKey(const ValueKey('tag_picker_select_all')));
    await tester.pump();

    expect(find.text('Tag 3 photos'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing is left to tag', (
    tester,
  ) async {
    final service = _RecordingTaggingService();
    final read = _pumpPicker(tester, const [], service);
    await read();

    expect(
      find.text('No untagged photos on dives where you logged this species.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tag_picker_confirm')), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/presentation/pages/species_tag_picker_page_test.dart`
Expected: compilation error, `species_tag_picker_page.dart` not found.

- [ ] **Step 3: Write the page and wire the action**

`lib/features/media/presentation/pages/species_tag_picker_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/species_tag_candidate_group.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

/// Picks photos to tag with one species, from the dives where the diver
/// logged it. Pops with the [TagPhotosResult] after tagging, or null.
class SpeciesTagPickerPage extends ConsumerStatefulWidget {
  final String speciesId;

  const SpeciesTagPickerPage({super.key, required this.speciesId});

  @override
  ConsumerState<SpeciesTagPickerPage> createState() =>
      _SpeciesTagPickerPageState();
}

class _SpeciesTagPickerPageState extends ConsumerState<SpeciesTagPickerPage> {
  final SelectionController _selection = SelectionController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The whole page is a picker: selection mode from the first frame.
    _selection.enterExplicit();
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupsAsync = ref.watch(
      speciesTagCandidatesProvider(widget.speciesId),
    );
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final allIds = [
      for (final group in groupsAsync.value ?? const <SpeciesTagCandidateGroup>[])
        for (final item in group.items) item.id,
    ];

    return ValueListenableBuilder<SelectionState>(
      valueListenable: _selection,
      builder: (context, selection, _) {
        final checked = selection.checkedIds;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.marineLife_tagPicker_title),
            actions: [
              if (allIds.isNotEmpty)
                TextButton(
                  key: const ValueKey('tag_picker_select_all'),
                  onPressed: () => _selection.selectAll(allIds),
                  child: Text(l10n.marineLife_tagPicker_selectAll),
                ),
            ],
          ),
          body: groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('$error')),
            data: (groups) {
              if (groups.isEmpty) {
                return _EmptyState(l10n: l10n);
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final group in groups) ...[
                    _GroupHeader(group: group, units: units, l10n: l10n),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: group.items.length,
                      itemBuilder: (context, index) {
                        final item = group.items[index];
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _selection.toggle(item.id),
                          child: MediaThumbnailTile(
                            item: item,
                            settings: settings,
                            isSelectionMode: true,
                            isSelected: checked.contains(item.id),
                            semanticsLabel:
                                l10n.marineLife_speciesPhotos_thumbnailLabel,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              );
            },
          ),
          bottomNavigationBar: allIds.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      key: const ValueKey('tag_picker_confirm'),
                      onPressed: checked.isEmpty || _busy
                          ? null
                          : () => _confirm(checked.toList()),
                      child: Text(
                        l10n.marineLife_tagPicker_confirm(checked.length),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _confirm(List<String> mediaIds) async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(speciesTaggingServiceProvider)
          .tagPhotos(mediaIds: mediaIds, speciesId: widget.speciesId);
      if (mounted) Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _GroupHeader extends StatelessWidget {
  final SpeciesTagCandidateGroup group;
  final UnitFormatter units;
  final AppLocalizations l10n;

  const _GroupHeader({
    required this.group,
    required this.units,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final number = group.diveNumber;
    final parts = [
      if (number != null) l10n.marineLife_tagPicker_diveLabel(number),
      units.formatDate(group.diveDateTime),
      group.siteName ?? l10n.marineLife_speciesDetail_unknownSite,
    ];
    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.titleSmall,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: theme.colorScheme.onSurface.withAlpha(77),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.marineLife_tagPicker_empty,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.marineLife_tagPicker_emptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(128),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

If `SelectionState.checkedIds` or `SelectionController.enterExplicit` / `selectAll` / `toggle` differ in name, read `lib/shared/selection/selection_controller.dart` and `selection_state.dart` and use the declared names; the manage page (`species_manage_page.dart`) is a working consumer to compare against.

In `species_detail_page.dart`: `SpeciesDetailPage` is a `ConsumerWidget`, so add a private method and pass it:

```dart
                SpeciesPhotosSection(
                  speciesId: speciesId,
                  onTagPhotos: () => _openTagPicker(context),
                ),
```

and, at the end of the class:

```dart
  Future<void> _openTagPicker(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await Navigator.of(context).push<TagPhotosResult>(
      MaterialPageRoute<TagPhotosResult>(
        fullscreenDialog: true,
        builder: (_) => SpeciesTagPickerPage(speciesId: speciesId),
      ),
    );
    if (result == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.marineLife_tagPicker_tagged(result.tagged))),
    );
  }
```

with imports for `species_tag_picker_page.dart` and `species_tagging_service.dart` (for `TagPhotosResult`).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/presentation/pages/species_tag_picker_page_test.dart test/features/media/presentation/widgets/species_photos_section_test.dart`
Expected: `All tests passed!`, exit code 0.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format lib/features/media/presentation/pages/species_tag_picker_page.dart lib/features/marine_life/presentation/pages/species_detail_page.dart test/features/media/presentation/pages/species_tag_picker_page_test.dart
git add lib/features/media/presentation/pages/species_tag_picker_page.dart lib/features/marine_life/presentation/pages/species_detail_page.dart test/features/media/presentation/pages/species_tag_picker_page_test.dart
git commit -m "feat(media): add the species tag picker and the Tag photos action"
```

---

### Task 11: Import camera-roll photos into a species

**Files:**
- Modify: `lib/features/media/domain/entities/import_candidate.dart` (`ImportReviewResult` gains `importedIds`)
- Modify: `lib/features/media/presentation/pages/media_import_view.dart` (`importResolved` fills `importedIds`)
- Create: `lib/features/media/presentation/helpers/species_photo_import_helper.dart`
- Modify: `lib/features/marine_life/presentation/pages/species_detail_page.dart` (pass `onAddPhotos`)
- Test: `test/features/media/presentation/media_import_resolved_test.dart` (extend), `test/features/media/presentation/helpers/species_photo_import_helper_test.dart` (new)

**Interfaces:**
- Consumes: `MediaImportView.importResolved({service, diveRepository, assets, targets})` and `MediaImportView.libraryWindowStart`; `showPhotoPicker({context, diveStartTime, diveEndTime, buffer})` from `lib/features/media/presentation/pages/photo_picker_page.dart`; `AssetInfo` from `lib/features/media/data/services/photo_picker_service.dart`; `ImportCandidate`, `AssetImportPreview` (`lib/features/media/domain/value_objects/import_preview.dart`), `TripMediaScanner.toWallClockUtc` (`lib/features/media/data/services/trip_media_scanner.dart`); `MediaImportReviewPage({candidates, onConfirm})`; `mediaImportServiceProvider` (`lib/features/media/presentation/providers/photo_picker_providers.dart`); `diveRepositoryProvider`; `speciesTaggingServiceProvider` (Task 6).
- Produces: `ImportReviewResult.importedIds: List<String>`; `class SpeciesImportOutcome { added, skipped, failed }`; `SpeciesPhotoImportHelper.tagImported({review, service, speciesId}) -> Future<SpeciesImportOutcome>` (pure composition, tested) and `SpeciesPhotoImportHelper.importPhotosForSpecies(context, ref, {required speciesId, pick})` (the flow).

- [ ] **Step 1: Extend the existing importResolved test**

In `test/features/media/presentation/media_import_resolved_test.dart`, inside the first test (`'groups assets by dive and by site, one service call each'`) add after `expect(out.failures, isEmpty);`:

```dart
    // Species import tags what was created, so the ids must come back.
    expect(out.importedIds, ['row-a', 'row-b', 'row-c']);
```

- [ ] **Step 2: Write the failing helper test**

`test/features/media/presentation/helpers/species_photo_import_helper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/presentation/helpers/species_photo_import_helper.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';

void main() {
  late SpeciesTaggingService service;
  late MediaSpeciesRepository tags;

  setUp(() async {
    await setUpTestDatabase();
    tags = MediaSpeciesRepository();
    service = SpeciesTaggingService(
      tags: tags,
      media: MediaRepository(),
      species: SpeciesRepository(),
    );
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'sp_whale_shark', name: 'Whale Shark');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('tags every imported row and folds the counts into one outcome',
      () async {
    const review = ImportReviewResult(
      linked: 2,
      skipped: 1,
      failures: {'asset-x': 'no dive'},
      importedIds: ['p1', 'p2', 'gone'],
    );

    final outcome = await SpeciesPhotoImportHelper.tagImported(
      review: review,
      service: service,
      speciesId: 'sp_whale_shark',
    );

    expect(outcome.added, 2);
    expect(outcome.skipped, 1);
    // One import failure plus one tag failure (the row that does not exist).
    expect(outcome.failed, 2);
    expect(await tags.getTagsForMedia('p1'), hasLength(1));
    expect(await tags.getTagsForMedia('p2'), hasLength(1));
  });

  test('ImportReviewResult defaults to no imported ids', () {
    const review = ImportReviewResult(linked: 0, skipped: 0);
    expect(review.importedIds, isEmpty);
  });
}
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/presentation/media_import_resolved_test.dart test/features/media/presentation/helpers/species_photo_import_helper_test.dart`
Expected: compilation errors (`importedIds` is not defined; helper file not found).

- [ ] **Step 4: Implement**

In `lib/features/media/domain/entities/import_candidate.dart`, replace `ImportReviewResult` with:

```dart
/// What confirming did, for the result snackbar and for callers that need
/// the rows themselves (a species import tags what was created).
class ImportReviewResult {
  const ImportReviewResult({
    required this.linked,
    required this.skipped,
    this.failures = const {},
    this.importedIds = const [],
  });

  final int linked;
  final int skipped;
  final Map<String, String> failures;

  /// Ids of the media rows the import created, in import order.
  final List<String> importedIds;
}
```

In `media_import_view.dart` `importResolved`: declare `final importedIds = <String>[];` next to `var linked = 0;`, and after each `linked += result.imported.length;` (the dive loop and the site loop) add `importedIds.addAll(result.imported.map((m) => m.id));`. Return `ImportReviewResult(linked: linked, skipped: assets.length - targets.length, failures: failures, importedIds: importedIds)`.

Create `lib/features/media/presentation/helpers/species_photo_import_helper.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/value_objects/import_preview.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What an import into a species did, for its snackbar.
class SpeciesImportOutcome {
  final int added;
  final int skipped;
  final int failed;

  const SpeciesImportOutcome({
    required this.added,
    required this.skipped,
    required this.failed,
  });
}

/// "Add photos" on a species: the library's reviewed import (every photo
/// resolves to a dive or a site before any row exists), followed by a tag
/// on each row it created. The species is applied after the attach, never
/// instead of it, so the attached-or-absent rule is untouched.
class SpeciesPhotoImportHelper {
  const SpeciesPhotoImportHelper._();

  /// Tags the rows a review created and folds both failure maps together.
  static Future<SpeciesImportOutcome> tagImported({
    required ImportReviewResult review,
    required SpeciesTaggingService service,
    required String speciesId,
  }) async {
    final tagged = await service.tagPhotos(
      mediaIds: review.importedIds,
      speciesId: speciesId,
    );
    return SpeciesImportOutcome(
      added: tagged.tagged,
      skipped: review.skipped,
      failed: review.failures.length + tagged.failures.length,
    );
  }

  /// Runs the picker, the review page and the tagging, then reports.
  ///
  /// [pick] is a test seam that replaces the platform photo picker.
  static Future<void> importPhotosForSpecies(
    BuildContext context,
    WidgetRef ref, {
    required String speciesId,
    Future<List<AssetInfo>?> Function(BuildContext context)? pick,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final assets =
        await (pick?.call(context) ??
            showPhotoPicker(
              context: context,
              diveStartTime: MediaImportView.libraryWindowStart,
              diveEndTime: DateTime.now().add(const Duration(days: 1)),
              buffer: Duration.zero,
            )) ??
        const <AssetInfo>[];
    if (assets.isEmpty || !context.mounted) return;

    final candidates = [
      for (final a in assets)
        ImportCandidate(
          key: a.id,
          title: a.filename ?? a.id,
          takenAt: TripMediaScanner.toWallClockUtc(a.createDateTime),
          preview: AssetImportPreview(a.id),
        ),
    ];

    SpeciesImportOutcome? outcome;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaImportReviewPage(
          candidates: candidates,
          onConfirm: (targets) async {
            final review = await MediaImportView.importResolved(
              service: ref.read(mediaImportServiceProvider),
              diveRepository: ref.read(diveRepositoryProvider),
              assets: assets,
              targets: targets,
            );
            outcome = await tagImported(
              review: review,
              service: ref.read(speciesTaggingServiceProvider),
              speciesId: speciesId,
            );
            return review;
          },
        ),
      ),
    );

    final done = outcome;
    if (done == null) return;
    final parts = [
      l10n.marineLife_speciesPhotos_importAdded(done.added),
      if (done.skipped > 0)
        l10n.marineLife_speciesPhotos_importSkipped(done.skipped),
      if (done.failed > 0)
        l10n.marineLife_speciesPhotos_importFailed(done.failed),
    ];
    messenger.showSnackBar(SnackBar(content: Text(parts.join(' · '))));
  }
}
```

In `species_detail_page.dart`, pass the second callback:

```dart
                SpeciesPhotosSection(
                  speciesId: speciesId,
                  onTagPhotos: () => _openTagPicker(context),
                  onAddPhotos: () => SpeciesPhotoImportHelper.importPhotosForSpecies(
                    context,
                    ref,
                    speciesId: speciesId,
                  ),
                ),
```

with the import `import 'package:submersion/features/media/presentation/helpers/species_photo_import_helper.dart';`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/presentation/media_import_resolved_test.dart test/features/media/presentation/helpers/species_photo_import_helper_test.dart test/features/media/presentation/`
Expected: `All tests passed!`, exit code 0 (the whole media presentation directory, since `ImportReviewResult` changed shape).

- [ ] **Step 6: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format lib/features/media lib/features/marine_life/presentation/pages/species_detail_page.dart test/features/media
git add lib/features/media/domain/entities/import_candidate.dart lib/features/media/presentation/pages/media_import_view.dart lib/features/media/presentation/helpers/species_photo_import_helper.dart lib/features/marine_life/presentation/pages/species_detail_page.dart test/features/media/presentation/media_import_resolved_test.dart test/features/media/presentation/helpers/species_photo_import_helper_test.dart
git commit -m "feat(media): import camera-roll photos into a species through the reviewed importer"
```

---

### Task 12: Photo viewer: Species action, sheet, and tag chips

**Files:**
- Create: `lib/features/media/presentation/widgets/media_species_sheet.dart`
- Create: `lib/features/media/presentation/widgets/media_species_chips_row.dart`
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (`_TopOverlay` gets an `onTagSpecies` callback and a button beside Info; `_BottomMetadataOverlay` mounts the chips row)
- Test: `test/features/media/presentation/widgets/media_species_sheet_test.dart`, `test/features/media/presentation/widgets/media_species_chips_row_test.dart`

**Interfaces:**
- Consumes: `mediaTagChipsProvider(mediaId)` and `speciesTaggingServiceProvider` (Task 6); `diveSightingsProvider(diveId)` from `lib/features/marine_life/presentation/providers/species_providers.dart` (returns `List<Sighting>` with `speciesId`, `speciesName`, `speciesCategory`); `SpeciesPickerSheet({required ScrollController scrollController, required void Function(Species species, int count, String notes) onSpeciesSelected})` from `lib/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart`; `localizedSpeciesName(l10n, id, storedName)` and `iconForSpeciesCategory` / `colorForSpeciesCategory`; Task 7 strings.
- Produces: `Future<void> showMediaSpeciesSheet(BuildContext context, MediaItem item)`; `MediaSpeciesSheet({required MediaItem item, ScrollController? scrollController})`; `MediaSpeciesChipsRow({required String mediaId})`.

- [ ] **Step 1: Write the failing widget tests**

`test/features/media/presentation/widgets/media_species_chips_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_chips_row.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('renders one chip per tag with the localized name', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/viewer',
      routes: [
        GoRoute(
          path: '/viewer',
          builder: (_, _) => const Scaffold(
            body: MediaSpeciesChipsRow(mediaId: 'p1'),
          ),
        ),
        GoRoute(
          path: '/species/:id',
          builder: (_, state) =>
              Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('de'),
        overrides: [
          ...overrides,
          mediaTagChipsProvider('p1').overrideWith(
            (ref) async => const [
              SpeciesTagChip(
                speciesId: 'sp_whale_shark',
                storedName: 'Whale Shark',
                category: SpeciesCategory.shark,
                isBuiltIn: true,
              ),
              SpeciesTagChip(
                speciesId: 'c1',
                storedName: 'My Nudibranch',
                category: SpeciesCategory.invertebrate,
                isBuiltIn: false,
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Walhai'), findsOneWidget);
    expect(find.text('My Nudibranch'), findsOneWidget);

    await tester.tap(find.text('Walhai'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL sp_whale_shark'), findsOneWidget);
  });

  testWidgets('renders nothing without tags', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          mediaTagChipsProvider('p1').overrideWith((ref) async => const []),
        ],
        child: const MediaSpeciesChipsRow(mediaId: 'p1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActionChip), findsNothing);
  });
}
```

`test/features/media/presentation/widgets/media_species_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_sheet.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _RecordingTaggingService extends SpeciesTaggingService {
  _RecordingTaggingService()
    : super(
        tags: MediaSpeciesRepository(),
        media: MediaRepository(),
        species: SpeciesRepository(),
      );

  final List<(String mediaId, String speciesId)> tagged = [];
  final List<(String mediaId, String speciesId)> untagged = [];

  @override
  Future<MediaSpeciesTag> tagPhoto({
    required String mediaId,
    required String speciesId,
  }) async {
    tagged.add((mediaId, speciesId));
    return MediaSpeciesTag(
      id: 't',
      mediaId: mediaId,
      speciesId: speciesId,
      createdAt: DateTime(2024),
    );
  }

  @override
  Future<void> untagPhoto({
    required String mediaId,
    required String speciesId,
  }) async {
    untagged.add((mediaId, speciesId));
  }
}

MediaItem _photo({String? diveId}) => MediaItem(
  id: 'p1',
  diveId: diveId,
  siteId: diveId == null ? 's1' : null,
  mediaType: MediaType.photo,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

const _sightings = [
  Sighting(
    id: 'sg1',
    diveId: 'd1',
    speciesId: 'sp_whale_shark',
    speciesName: 'Whale Shark',
    speciesCategory: SpeciesCategory.shark,
  ),
  Sighting(
    id: 'sg2',
    diveId: 'd1',
    speciesId: 'c1',
    speciesName: 'My Nudibranch',
    speciesCategory: SpeciesCategory.invertebrate,
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required MediaItem item,
  required _RecordingTaggingService service,
  List<SpeciesTagChip> chips = const [],
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...overrides,
        speciesTaggingServiceProvider.overrideWithValue(service),
        mediaTagChipsProvider('p1').overrideWith((ref) async => chips),
        diveSightingsProvider('d1').overrideWith((ref) async => _sightings),
      ],
      child: MediaSpeciesSheet(item: item),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the dive\'s sightings as chips, checked when tagged', (
    tester,
  ) async {
    final service = _RecordingTaggingService();
    await _pump(
      tester,
      item: _photo(diveId: 'd1'),
      service: service,
      chips: const [
        SpeciesTagChip(
          speciesId: 'sp_whale_shark',
          storedName: 'Whale Shark',
          category: SpeciesCategory.shark,
          isBuiltIn: true,
        ),
      ],
    );

    expect(find.text('Species in this photo'), findsOneWidget);
    expect(find.text('Sighted on this dive'), findsOneWidget);
    final whale = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Whale Shark'),
    );
    final nudi = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'My Nudibranch'),
    );
    expect(whale.selected, isTrue);
    expect(nudi.selected, isFalse);
  });

  testWidgets('toggling a chip tags or untags the photo', (tester) async {
    final service = _RecordingTaggingService();
    await _pump(
      tester,
      item: _photo(diveId: 'd1'),
      service: service,
      chips: const [
        SpeciesTagChip(
          speciesId: 'sp_whale_shark',
          storedName: 'Whale Shark',
          category: SpeciesCategory.shark,
          isBuiltIn: true,
        ),
      ],
    );

    await tester.tap(find.widgetWithText(FilterChip, 'My Nudibranch'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Whale Shark'));
    await tester.pump();

    expect(service.tagged, [('p1', 'c1')]);
    expect(service.untagged, [('p1', 'sp_whale_shark')]);
  });

  testWidgets('a site-only photo offers only the search', (tester) async {
    final service = _RecordingTaggingService();
    await _pump(tester, item: _photo(), service: service);

    expect(find.text('Sighted on this dive'), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(
      find.text(
        'This photo is not linked to a dive. Search for a species to tag it.',
      ),
      findsOneWidget,
    );
    expect(find.text('Other species...'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/presentation/widgets/media_species_chips_row_test.dart test/features/media/presentation/widgets/media_species_sheet_test.dart`
Expected: compilation errors, both widget files missing.

- [ ] **Step 3: Write the widgets and wire the viewer**

`lib/features/media/presentation/widgets/media_species_chips_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The species tagged on a photo, as a wrapping row of chips over the
/// viewer's dark overlay. Tapping a chip opens the species. Renders nothing
/// when the photo has no tags.
class MediaSpeciesChipsRow extends ConsumerWidget {
  final String mediaId;

  const MediaSpeciesChipsRow({super.key, required this.mediaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chips = ref.watch(mediaTagChipsProvider(mediaId)).value ?? const [];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: l10n.media_species_chipsLabel,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final chip in chips)
              ActionChip(
                avatar: ExcludeSemantics(
                  child: Icon(iconForSpeciesCategory(chip.category), size: 16),
                ),
                label: Text(
                  localizedSpeciesName(l10n, chip.speciesId, chip.storedName),
                ),
                onPressed: () => context.push('/species/${chip.speciesId}'),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
```

`lib/features/media/presentation/widgets/media_species_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the species sheet for [item], the same modal shape as the info
/// sheet: every transient panel in the app is a bottom sheet at every width.
Future<void> showMediaSpeciesSheet(BuildContext context, MediaItem item) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) =>
            MediaSpeciesSheet(item: item, scrollController: controller),
      ),
    );

/// Tag a photo with species. The dive's sightings are one tap away as
/// chips; anything else goes through the species picker, which also logs
/// the sighting on the dive (a photo is evidence).
class MediaSpeciesSheet extends ConsumerWidget {
  final MediaItem item;
  final ScrollController? scrollController;

  const MediaSpeciesSheet({super.key, required this.item, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diveId = item.diveId;
    final tagged = {
      for (final chip
          in ref.watch(mediaTagChipsProvider(item.id)).value ?? const [])
        chip.speciesId,
    };
    final sightings = diveId == null
        ? null
        : ref.watch(diveSightingsProvider(diveId)).value ?? const [];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.media_species_sheetTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (sightings == null)
          Text(l10n.media_species_noDiveHint)
        else ...[
          Text(
            l10n.media_species_sightedOnDive,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final sighting in sightings)
                FilterChip(
                  avatar: ExcludeSemantics(
                    child: Icon(
                      iconForSpeciesCategory(
                        sighting.speciesCategory ?? SpeciesCategory.other,
                      ),
                      size: 16,
                    ),
                  ),
                  label: Text(
                    localizedSpeciesName(
                      l10n,
                      sighting.speciesId,
                      sighting.speciesName,
                    ),
                  ),
                  selected: tagged.contains(sighting.speciesId),
                  onSelected: (selected) => _toggle(
                    ref,
                    speciesId: sighting.speciesId,
                    selected: selected,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const ValueKey('media_species_other'),
          icon: const Icon(Icons.search),
          label: Text(l10n.media_species_otherSpecies),
          onPressed: () => _pickOther(context, ref),
        ),
      ],
    );
  }

  Future<void> _toggle(
    WidgetRef ref, {
    required String speciesId,
    required bool selected,
  }) async {
    final service = ref.read(speciesTaggingServiceProvider);
    if (selected) {
      await service.tagPhoto(mediaId: item.id, speciesId: speciesId);
    } else {
      await service.untagPhoto(mediaId: item.id, speciesId: speciesId);
    }
  }

  Future<void> _pickOther(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SpeciesPickerSheet(
          scrollController: controller,
          onSpeciesSelected: (species, count, notes) {
            Navigator.of(sheetContext).pop();
            ref
                .read(speciesTaggingServiceProvider)
                .tagPhoto(mediaId: item.id, speciesId: species.id);
          },
        ),
      ),
    );
  }
}
```

Add `import 'package:submersion/core/constants/enums.dart';` to the sheet for `SpeciesCategory`.

In `media_viewer_page.dart`:

1. `_TopOverlay`: add a field `final VoidCallback onTagSpecies;` and the constructor parameter `required this.onTagSpecies,` (after `onWriteMetadata`); in its action row, directly before the Info `IconButton`, add:
```dart
                IconButton(
                  key: const ValueKey('viewer_species'),
                  icon: const Icon(Icons.sell_outlined, color: Colors.white),
                  tooltip: context.l10n.media_species_actionTooltip,
                  onPressed: onTagSpecies,
                ),
```
2. Where `_TopOverlay(` is instantiated, add `onTagSpecies: () => showMediaSpeciesSheet(context, currentItem),` after the `onWriteMetadata:` argument, and import `media_species_sheet.dart`.
3. In `_BottomMetadataOverlay.build`, inside the `Column` children directly before the `// Metadata row` comment, add `MediaSpeciesChipsRow(mediaId: item.id),` and import `media_species_chips_row.dart`.

- [ ] **Step 4: Run the tests**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos && flutter test test/features/media/presentation/widgets/media_species_chips_row_test.dart test/features/media/presentation/widgets/media_species_sheet_test.dart test/features/media/presentation/pages/`
Expected: `All tests passed!`, exit code 0. Existing viewer tests construct `_TopOverlay` only through `MediaViewerPage`, so the new required parameter needs no test edits; if a viewer test now reaches `mediaTagChipsProvider` against a database, override it with an empty list in that test's `ProviderScope`.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format lib/features/media/presentation test/features/media/presentation
git add lib/features/media/presentation/widgets/media_species_sheet.dart lib/features/media/presentation/widgets/media_species_chips_row.dart lib/features/media/presentation/pages/media_viewer_page.dart test/features/media/presentation/widgets/media_species_chips_row_test.dart test/features/media/presentation/widgets/media_species_sheet_test.dart
git commit -m "feat(media): tag species from the photo viewer and show tag chips"
```

---

### Task 13: Docs, formatting, analysis, full test run

**Files:**
- Modify: `docs/features/marine-life.md`

- [ ] **Step 1: Update the feature doc**

In `docs/features/marine-life.md`, replace the `## Photo Integration` section (from its heading through the `<div class="tip">...Coming Soon...</div>` block) with:

```markdown
## Photo Integration

### Species Photos

Tag the photos on your dives with the species in them, and see every photo of
a species in one place.

- On a species page, the **Photos** section shows every photo tagged with it.
  **Tag photos** offers the untagged photos from the dives where you logged
  the species; **Add photos** imports pictures from your camera roll, matches
  each one to a dive as the media importer does, and tags it.
- In the photo viewer, the **Species** action lists the dive's sightings as
  chips you can toggle, plus a search for any other species. Tagging a species
  that is not yet logged on that dive adds the sighting for you.
- Tagged species appear as chips under the photo; tap one to open the species.

A species with tagged photos cannot be deleted from the catalog until the
tags are removed, the same rule as for sightings.
```

- [ ] **Step 2: Format the whole project and confirm only intended files changed**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
dart format .
git status --short
```

Expected: only `docs/features/marine-life.md` modified (plus the untracked spec files that were copied into this worktree before the plan started; leave those alone).

- [ ] **Step 3: Analyze the whole project**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
flutter analyze --fatal-infos
```

Expected: first line `Analyzing species-photos...`, result `No issues found!`.

- [ ] **Step 4: Run the full test suite once**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
flutter test
```

Detach it to a log with the exit code appended, read the summary line yourself, and check `ps -axo command | grep flutter_tester | grep -o "packages=[^ ]*"` first: another session's suite running at the same time fakes failures in both. Expected: `All tests passed!` with an exit code of 0 and a summary line present. A run that ends with `Bad state: Cannot close sink while adding stream` and no summary line was killed; rerun it.

- [ ] **Step 5: Commit the docs**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photos
git add docs/features/marine-life.md
git commit -m "docs: describe species photo tagging"
```

Do not push. Report the branch state and stop.

---

## Self-review notes

- Spec coverage (phase A): 3.1 to 3.3 data and repository (Tasks 1, 2); 3.4 sync (Task 3); 4 tagging service (Task 5); 5 import (Task 11); 6.1 Photos section (Task 9), 6.2 viewer wrapper (Task 8), 6.3 picker (Task 10), 6.4 viewer action, sheet and chips (Task 12); 8 integrity rules (Task 4); 9 l10n (Task 7); 10 tests are spread across tasks; docs (Task 13). Section 7 (phase B) is intentionally absent.
- Deviations from the spec, both deliberate: the picker uses a plain grid with tap-to-toggle instead of `DragSelectGridView`, so one `SelectionController` can span groups without per-grid index bookkeeping; the sheet's "Other species" reuses `SpeciesPickerSheet`, whose confirm dialog asks for a count and notes that the tag path ignores (the sighting the service creates has count 1), which is acceptable for phase A and noted for phase B polish.
- Type consistency: `TagPhotosResult` is defined in Task 5 and consumed in Tasks 10 and 11; `SpeciesTagCandidateGroup.sightingId` is a `String` (Task 2) while `MediaSpeciesTag.sightingId` is `String?`; `ImportReviewResult.importedIds` is added in Task 11 before `tagImported` reads it; `mediaTagChipsProvider` is keyed by media id and `mediaForSpeciesProvider` / `speciesTagCandidatesProvider` by species id, matching every override in the widget tests.
