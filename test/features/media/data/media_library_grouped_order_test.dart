import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_library_grouping.dart';
import 'package:submersion/features/media/domain/entities/media_library_sort.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';

import '../../../helpers/test_database.dart';

/// Issue #4268: the grouped views group the rows they have loaded, so a
/// page order that scatters a dive's (or a day's) rows showed that group with
/// only the rows on the pages read so far. A grouped page orders by the
/// group first, so every group arrives whole and in one run.
void main() {
  late AppDatabase db;
  late MediaRepository mediaRepo;
  late MediaLibraryRepository repo;

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> insertMedia(
    String id,
    DateTime takenAt, {
    String? name,
    String? diveId,
    String? siteId,
    String? equipmentId,
  }) => mediaRepo.createMedia(
    MediaItem(
      id: id,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      filePath: p.join(Directory.systemTemp.path, id),
      localPath: p.join(Directory.systemTemp.path, id),
      originalFilename: name ?? '$id.jpg',
      diveId: diveId,
      siteId: siteId,
      equipmentId: equipmentId,
      takenAt: TripMediaScanner.toWallClockUtc(takenAt),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  );

  Future<void> insertDive(String id, int number, DateTime at) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: const Value('d1'),
          diveNumber: Value(number),
          diveDateTime: Value(
            TripMediaScanner.toWallClockUtc(at).millisecondsSinceEpoch,
          ),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertSite(String id, String name) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(name),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    mediaRepo = MediaRepository();
    repo = MediaLibraryRepository();
  });
  tearDown(tearDownTestDatabase);

  SortState<MediaSortField> sortBy(
    MediaSortField field,
    SortDirection direction,
  ) => SortState(field: field, direction: direction);

  /// Walks every page and returns the ids in order. A small [limit] puts a
  /// page boundary inside every group, which is where a cursor that ignores
  /// the group keys skips or repeats rows.
  Future<List<String>> pageThrough(
    SortState<MediaSortField> sort,
    MediaLibraryGrouping grouping, {
    required int limit,
  }) async {
    final ids = <String>[];
    MediaLibraryCursor? cursor;
    var guard = 0;
    while (true) {
      final page = await repo.getPage(
        diverId: 'd1',
        sort: sort,
        grouping: grouping,
        after: cursor,
        limit: limit,
      );
      ids.addAll(page.entries.map((e) => e.item.id));
      cursor = page.nextCursor;
      if (cursor == null) break;
      if (++guard > 40) fail('pagination did not terminate');
    }
    return ids;
  }

  group('by dive', () {
    setUp(() async {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: const Value('d1'),
              name: const Value('d1'),
              createdAt: Value(epoch),
              updatedAt: Value(epoch),
            ),
          );
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion(
              id: const Value('eq'),
              name: const Value('Light'),
              type: const Value('light'),
              createdAt: Value(epoch),
              updatedAt: Value(epoch),
            ),
          );
      await insertDive('dA', 2, DateTime(2026, 6, 10));
      await insertDive('dB', 1, DateTime(2026, 6, 1));
      await insertSite('reef', 'Reef');
      await insertSite('arch', 'Arch');

      // Newest first, the flat order is u1 s1 a1 b1 a2 q1 s2 b2 a3: dive A's
      // rows are split by dive B's b1 (a camera clock off by a week) and by
      // the rows attached to no dive.
      await insertMedia('u1', DateTime(2026, 6, 12), name: 'k.jpg');
      await insertMedia(
        's1',
        DateTime(2026, 6, 11),
        name: 'j.jpg',
        siteId: 'reef',
      );
      await insertMedia(
        'a1',
        DateTime(2026, 6, 10, 10),
        name: 'z.jpg',
        diveId: 'dA',
      );
      await insertMedia(
        'b1',
        DateTime(2026, 6, 9),
        name: 'y.jpg',
        diveId: 'dB',
      );
      await insertMedia(
        'a2',
        DateTime(2026, 6, 8),
        name: 'm.jpg',
        diveId: 'dA',
        // A dive photo with a site link of its own still belongs to the
        // dive; a group name read from the site would split dive A here.
        siteId: 'arch',
      );
      await insertMedia(
        'q1',
        DateTime(2026, 6, 5),
        name: 'h.jpg',
        equipmentId: 'eq',
      );
      await insertMedia(
        's2',
        DateTime(2026, 6, 4),
        name: 'g.jpg',
        siteId: 'arch',
      );
      await insertMedia(
        'b2',
        DateTime(2026, 6, 1, 9),
        name: 'b.jpg',
        diveId: 'dB',
      );
      await insertMedia(
        'a3',
        DateTime(2026, 6, 1, 8),
        name: 'c.jpg',
        diveId: 'dA',
      );
    });

    test('without grouping the page order is unchanged', () async {
      expect(
        await pageThrough(
          kDefaultMediaSort,
          MediaLibraryGrouping.none,
          limit: 2,
        ),
        ['u1', 's1', 'a1', 'b1', 'a2', 'q1', 's2', 'b2', 'a3'],
      );
    });

    // Dives newest first, each dive's rows newest first; then the site groups
    // by name (Arch before Reef), the equipment group, and Unlinked last.
    const dateDescending = [
      'a1',
      'a2',
      'a3',
      'b1',
      'b2',
      's2',
      's1',
      'q1',
      'u1',
    ];

    for (final limit in [1, 2, 3, 60]) {
      test('date descending keeps every dive whole (page of $limit)', () async {
        expect(
          await pageThrough(
            kDefaultMediaSort,
            MediaLibraryGrouping.dive,
            limit: limit,
          ),
          dateDescending,
        );
      });
    }

    test('date ascending lists the oldest dive first', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.dateTaken, SortDirection.ascending),
          MediaLibraryGrouping.dive,
          limit: 2,
        ),
        ['b2', 'b1', 'a3', 'a2', 'a1', 's2', 's1', 'q1', 'u1'],
      );
    });

    test('a name sort orders within each dive, dives newest first', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileName, SortDirection.ascending),
          MediaLibraryGrouping.dive,
          limit: 2,
        ),
        ['a3', 'a2', 'a1', 'b2', 'b1', 's2', 's1', 'q1', 'u1'],
      );
    });

    test('a cursor from another grouping is refused', () async {
      final ungrouped = await repo.getPage(diverId: 'd1', limit: 2);
      expect(ungrouped.nextCursor?.groupKeys, isEmpty);
      await expectLater(
        repo.getPage(
          diverId: 'd1',
          grouping: MediaLibraryGrouping.dive,
          after: ungrouped.nextCursor,
          limit: 2,
        ),
        throwsArgumentError,
      );
    });

    test('the cursor carries the group of the last row', () async {
      final page = await repo.getPage(
        diverId: 'd1',
        grouping: MediaLibraryGrouping.dive,
        limit: 2,
      );
      expect(page.entries.map((e) => e.item.id), ['a1', 'a2']);
      expect(page.nextCursor?.id, 'a2');
      expect(page.nextCursor?.groupKeys, isNotEmpty);
    });
  });

  group('by day', () {
    setUp(() async {
      // By name the flat order is t2 t1 t3 t4, which splits 1 June (t2, t4)
      // around 2 June.
      await insertMedia('t1', DateTime(2026, 6, 2, 10), name: 'b.jpg');
      await insertMedia('t2', DateTime(2026, 6, 1, 10), name: 'a.jpg');
      await insertMedia('t3', DateTime(2026, 6, 2, 8), name: 'c.jpg');
      await insertMedia('t4', DateTime(2026, 6, 1, 9), name: 'd.jpg');
    });

    test('a name sort orders within each day, days newest first', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileName, SortDirection.ascending),
          MediaLibraryGrouping.day,
          limit: 1,
        ),
        ['t1', 't3', 't2', 't4'],
      );
    });

    test('date ascending lists the oldest day first', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.dateTaken, SortDirection.ascending),
          MediaLibraryGrouping.day,
          limit: 1,
        ),
        ['t4', 't2', 't3', 't1'],
      );
    });

    test('days before 1970 keep apart', () async {
      // Either side of the epoch, where truncating division would give both
      // days the key 0 and the name sort would interleave them.
      await db.delete(db.media).go();
      await insertMedia('n31', DateTime(1969, 12, 31, 12), name: 'a.jpg');
      await insertMedia('j01', DateTime(1970, 1, 1, 12), name: 'b.jpg');
      await insertMedia('n31b', DateTime(1969, 12, 31, 13), name: 'c.jpg');
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileName, SortDirection.ascending),
          MediaLibraryGrouping.day,
          limit: 1,
        ),
        ['j01', 'n31', 'n31b'],
      );
    });

    test('an undated row shows under the day it sorts by', () async {
      // taken_at NULL: the date key falls back to created_at, so the row
      // must hydrate and group on that day too, or Timeline files it under
      // some other header than its page neighbours'.
      Future<void> undated(String id, DateTime createdWallClock) =>
          db.customStatement(
            'INSERT INTO media (id, file_path, file_type, created_at, '
            'updated_at) VALUES (?, ?, ?, ?, ?)',
            [
              id,
              p.join(Directory.systemTemp.path, id),
              'photo',
              createdWallClock.millisecondsSinceEpoch,
              epoch,
            ],
          );
      await undated('u1', DateTime.utc(2026, 6, 2, 12));
      await undated('u2', DateTime.utc(2026, 5, 20, 12));

      final entries = <MediaLibraryEntry>[];
      MediaLibraryCursor? cursor;
      do {
        final page = await repo.getPage(
          diverId: 'd1',
          grouping: MediaLibraryGrouping.day,
          after: cursor,
          limit: 1,
        );
        entries.addAll(page.entries);
        cursor = page.nextCursor;
      } while (cursor != null);

      expect(entries.map((e) => e.item.id), [
        'u1',
        't1',
        't3',
        't2',
        't4',
        'u2',
      ]);
      expect(entries.first.item.takenAt, DateTime.utc(2026, 6, 2, 12));
      final groups = groupByTimeline(entries);
      expect(groups.map((g) => (g.header as DateGroupHeader).dayStart), [
        DateTime(2026, 6, 2),
        DateTime(2026, 6, 1),
        DateTime(2026, 5, 20),
      ]);
      expect([
        for (final g in groups) ...g.entries.map((e) => e.item.id),
      ], entries.map((e) => e.item.id));
    });

    test('a photo just before midnight stays on its own day', () async {
      await insertMedia('late', DateTime(2026, 6, 1, 23, 59), name: 'e.jpg');
      await insertMedia('early', DateTime(2026, 6, 2, 0, 1), name: 'f.jpg');
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileName, SortDirection.ascending),
          MediaLibraryGrouping.day,
          limit: 2,
        ),
        ['t1', 't3', 'early', 't2', 't4', 'late'],
      );
    });
  });
}
