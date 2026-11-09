import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

import '../../../helpers/test_database.dart';
import 'repositories/species_photo_fixtures.dart';

/// The library's two cleanup facets (issue #4148): items with no one tagged,
/// and dive items the profile chart would not place. Each is the exact
/// opposite of a tile marker (issue #4218), so an item shows under the filter
/// precisely when its tile lacks that marker.
void main() {
  final repo = MediaLibraryRepository();
  final people = MediaPeopleRepository();
  final diveStart = DateTime.utc(2024, 3, 1, 9);

  Future<void> enrich(
    String mediaId, {
    required String diveId,
    int? elapsedSeconds = 600,
    String confidence = 'exact',
  }) async {
    final db = DatabaseService.instance.database;
    await db
        .into(db.mediaEnrichment)
        .insert(
          MediaEnrichmentCompanion(
            id: Value('me-$mediaId-$diveId'),
            mediaId: Value(mediaId),
            diveId: Value(diveId),
            elapsedSeconds: Value(elapsedSeconds),
            depthMeters: const Value(12),
            matchConfidence: Value(confidence),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  Future<List<MediaLibraryEntry>> entries(MediaLibraryFilter filter) async =>
      (await repo.getPage(diverId: 'A', filter: filter)).entries;

  Future<Set<String>> ids(MediaLibraryFilter filter) async => {
    for (final e in await entries(filter)) e.item.id,
  };

  setUp(() async {
    await setUpTestDatabase();
    await insertTestDiver('A');
    await insertTestBuddy(id: 'alex', name: 'Alex', diverId: 'A');
    await insertTestDive(id: 'd1', at: diveStart, diverId: 'A');
    await DatabaseService.instance.database.customStatement(
      'UPDATE dives SET runtime = 3000 WHERE id = ?',
      ['d1'],
    );
    DateTime at(int minutes) => diveStart.add(Duration(minutes: minutes));
    // Dive items.
    await insertTestMedia(id: 'buddy', diveId: 'd1', takenAt: at(1));
    await insertTestMedia(id: 'me', diveId: 'd1', takenAt: at(2));
    await insertTestMedia(id: 'placed', diveId: 'd1', takenAt: at(3));
    await insertTestMedia(id: 'no-profile', diveId: 'd1', takenAt: at(4));
    await insertTestMedia(
      id: 'clip',
      diveId: 'd1',
      takenAt: at(5),
      fileType: 'video',
    );
    await insertTestMedia(id: 'bare', diveId: 'd1', takenAt: at(6));
    // An item on no dive at all.
    await insertTestMedia(id: 'boat', takenAt: at(-60));

    await people.addTag(mediaId: 'buddy', buddyId: 'alex');
    await people.addTag(mediaId: 'me', diverId: 'A');
    await enrich('buddy', diveId: 'd1');
    await enrich('me', diveId: 'd1');
    await enrich('placed', diveId: 'd1');
    await enrich('no-profile', diveId: 'd1', confidence: 'noProfile');
  });
  tearDown(tearDownTestDatabase);

  group('no one tagged', () {
    const filter = MediaLibraryFilter(noPeople: true);

    test('keeps only items with no buddy and no Me tag', () async {
      expect(await ids(filter), {
        'placed',
        'no-profile',
        'clip',
        'bare',
        'boat',
      });
    });

    test('is exactly the items whose tile has no people marker', () async {
      final all = await entries(MediaLibraryFilter.none);
      expect(await ids(filter), {
        for (final e in all)
          if (!e.hasPeople) e.item.id,
      });
    });

    test('combines with the type facet', () async {
      expect(await ids(filter.copyWith(mediaType: MediaType.video)), {'clip'});
    });

    test('the count agrees with the page', () async {
      expect(await repo.countInScope(diverId: 'A', filter: filter), 5);
    });
  });

  group('not placed in the dive', () {
    const filter = MediaLibraryFilter(notPlacedInDive: true);

    test('keeps dive items the profile chart would not place', () async {
      expect(await ids(filter), {'no-profile', 'clip', 'bare'});
    });

    test('leaves out items linked to no dive', () async {
      expect(await ids(filter), isNot(contains('boat')));
    });

    test('is exactly the dive items whose tile has no time marker', () async {
      final all = await entries(MediaLibraryFilter.none);
      expect(await ids(filter), {
        for (final e in all)
          if (e.item.diveId != null && !e.hasTimeInDive) e.item.id,
      });
    });

    test('combines with no one tagged', () async {
      expect(await ids(filter.copyWith(noPeople: true)), {
        'no-profile',
        'clip',
        'bare',
      });
      await people.addTag(mediaId: 'bare', buddyId: 'alex');
      expect(await ids(filter.copyWith(noPeople: true)), {
        'no-profile',
        'clip',
      });
    });

    test('an item drops out once its time is set', () async {
      await enrich('bare', diveId: 'd1', confidence: 'manual');
      expect(await ids(filter), isNot(contains('bare')));
    });
  });

  group('on the map', () {
    setUp(() async {
      // Every row gets its own fix, so each one is a map point.
      await DatabaseService.instance.database.customStatement(
        'UPDATE media SET latitude = 10, longitude = 20',
      );
    });

    Future<Set<String>> mapIds(MediaLibraryFilter filter) async => {
      for (final p in await repo.getMapPoints(diverId: 'A', filter: filter))
        p.item.id,
    };

    test('each facet narrows the points like the grid', () async {
      for (final filter in const [
        MediaLibraryFilter(noPeople: true),
        MediaLibraryFilter(notPlacedInDive: true),
        MediaLibraryFilter(noPeople: true, notPlacedInDive: true),
      ]) {
        expect(await mapIds(filter), await ids(filter));
      }
    });

    test('watchMapChanges ticks when a time in the dive is set', () async {
      final ticks = <void>[];
      final sub = repo.watchMapChanges().listen(ticks.add);
      addTearDown(sub.cancel);
      await enrich('bare', diveId: 'd1', confidence: 'manual');
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(ticks, isNotEmpty);
    });
  });
}
