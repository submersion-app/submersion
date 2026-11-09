import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

import '../../../helpers/test_database.dart';
import 'repositories/species_photo_fixtures.dart';

/// The per-tile markers the library grid draws (issue #4218): whether a
/// person or a species is tagged on the item, and whether it has a time in
/// its dive that the profile chart would draw.
void main() {
  final repo = MediaLibraryRepository();
  final people = MediaPeopleRepository();
  final diveStart = DateTime.utc(2024, 3, 1, 9);

  Future<void> setRuntime(String diveId, int? seconds) =>
      DatabaseService.instance.database.customStatement(
        'UPDATE dives SET runtime = ? WHERE id = ?',
        [seconds, diveId],
      );

  Future<void> tagSpecies(String mediaId, String speciesId) async {
    final db = DatabaseService.instance.database;
    await db
        .into(db.mediaSpecies)
        .insert(
          MediaSpeciesCompanion(
            id: Value('ms-$mediaId-$speciesId'),
            mediaId: Value(mediaId),
            speciesId: Value(speciesId),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  Future<void> enrich(
    String mediaId, {
    required String diveId,
    int? elapsedSeconds,
    double? depthMeters = 12,
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
            depthMeters: Value(depthMeters),
            matchConfidence: Value(confidence),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  Future<MediaLibraryEntry> entryFor(String mediaId) async {
    final page = await repo.getPage(diverId: 'A');
    return page.entries.singleWhere((e) => e.item.id == mediaId);
  }

  setUp(() async {
    await setUpTestDatabase();
    await insertTestDiver('A');
    await insertTestBuddy(id: 'alex', name: 'Alex', diverId: 'A');
    await insertTestSpecies(id: 'clown', name: 'Clownfish');
    await insertTestDive(id: 'd1', at: diveStart, diverId: 'A');
    await insertTestDive(
      id: 'd2',
      at: diveStart.add(const Duration(days: 1)),
      diverId: 'A',
    );
    await setRuntime('d1', 3000);
    await insertTestMedia(id: 'plain', diveId: 'd1', takenAt: diveStart);
  });
  tearDown(tearDownTestDatabase);

  test('an untagged, unplaced item carries no markers', () async {
    final entry = await entryFor('plain');
    expect(entry.hasPeople, isFalse);
    expect(entry.hasSpecies, isFalse);
    expect(entry.hasTimeInDive, isFalse);
  });

  test('a buddy tag marks people', () async {
    await people.addTag(mediaId: 'plain', buddyId: 'alex');
    expect((await entryFor('plain')).hasPeople, isTrue);
  });

  test('a Me tag marks people too', () async {
    await people.addTag(mediaId: 'plain', diverId: 'A');
    expect((await entryFor('plain')).hasPeople, isTrue);
  });

  test('a species tag marks species', () async {
    await tagSpecies('plain', 'clown');
    final entry = await entryFor('plain');
    expect(entry.hasSpecies, isTrue);
    expect(entry.hasPeople, isFalse);
  });

  test('several tags still give one entry per item', () async {
    await people.addTag(mediaId: 'plain', buddyId: 'alex');
    await people.addTag(mediaId: 'plain', diverId: 'A');
    await tagSpecies('plain', 'clown');
    final page = await repo.getPage(diverId: 'A');
    expect(page.entries.where((e) => e.item.id == 'plain'), hasLength(1));
  });

  group('time in dive', () {
    test('an exact match inside the dive is marked', () async {
      await enrich('plain', diveId: 'd1', elapsedSeconds: 600);
      expect((await entryFor('plain')).hasTimeInDive, isTrue);
    });

    test('a row with no profile match is not', () async {
      await enrich(
        'plain',
        diveId: 'd1',
        elapsedSeconds: 600,
        confidence: 'noProfile',
      );
      expect((await entryFor('plain')).hasTimeInDive, isFalse);
    });

    test('a row with no depth is not, as the chart skips it', () async {
      await enrich(
        'plain',
        diveId: 'd1',
        elapsedSeconds: 600,
        depthMeters: null,
      );
      expect((await entryFor('plain')).hasTimeInDive, isFalse);
    });

    test('a row with no elapsed time is not', () async {
      await enrich('plain', diveId: 'd1');
      expect((await entryFor('plain')).hasTimeInDive, isFalse);
    });

    test('a capture far after the dive is not', () async {
      // Runtime 3000 s plus the hour of slack the chart allows.
      await enrich('plain', diveId: 'd1', elapsedSeconds: 3000 + 3601);
      expect((await entryFor('plain')).hasTimeInDive, isFalse);
    });

    test('a capture just inside the slack after the dive is', () async {
      await enrich('plain', diveId: 'd1', elapsedSeconds: 3000 + 3600);
      expect((await entryFor('plain')).hasTimeInDive, isTrue);
    });

    test('a capture well before the descent is not', () async {
      await enrich('plain', diveId: 'd1', elapsedSeconds: -1801);
      expect((await entryFor('plain')).hasTimeInDive, isFalse);
    });

    test('a pinned time is marked wherever it sits', () async {
      await enrich(
        'plain',
        diveId: 'd1',
        elapsedSeconds: 99999,
        confidence: 'manual',
      );
      expect((await entryFor('plain')).hasTimeInDive, isTrue);
    });

    test('a dive with no runtime checks only the lower bound', () async {
      await setRuntime('d1', null);
      await enrich('plain', diveId: 'd1', elapsedSeconds: 20000);
      expect((await entryFor('plain')).hasTimeInDive, isTrue);
    });

    test('a stale row for another dive is not', () async {
      // Left behind by a re-link: the enricher keys rows by dive.
      await enrich('plain', diveId: 'd2', elapsedSeconds: 600);
      expect((await entryFor('plain')).hasTimeInDive, isFalse);
    });

    test('an item with no dive is not', () async {
      await insertTestMedia(id: 'loose', takenAt: diveStart);
      await enrich('loose', diveId: 'd1', elapsedSeconds: 600);
      expect((await entryFor('loose')).hasTimeInDive, isFalse);
    });
  });

  test('watchLibraryChanges ticks on an enrichment write', () async {
    final ticks = <void>[];
    final sub = repo.watchLibraryChanges().listen(ticks.add);
    addTearDown(sub.cancel);
    await enrich('plain', diveId: 'd1', elapsedSeconds: 600);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(ticks, isNotEmpty);
  });
}
