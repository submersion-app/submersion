import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveMergeService service;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    service = DiveMergeService(diveRepo);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Seeds a dive with one tank, a 3-sample profile, and link rows in the
  /// tables createDive does not cover (buddy, sighting, event, gas switch,
  /// tank pressure, data source, media).
  Future<void> seedDive(
    String id, {
    required DateTime entry,
    int runtimeMin = 30,
    double depth = 10,
  }) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: Duration(minutes: runtimeMin),
        maxDepth: depth,
        tanks: [domain.DiveTank(id: 'tank-$id', volume: 11.1)],
        profile: [
          const domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: runtimeMin * 30, depth: depth),
          domain.DiveProfilePoint(timestamp: runtimeMin * 60, depth: 0),
        ],
      ),
    );
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: 'buddy-$id',
            diveId: id,
            buddyId: 'buddy-cat-1',
            createdAt: 0,
          ),
        );
    await db
        .into(db.sightings)
        .insert(
          SightingsCompanion.insert(
            id: 'sight-$id',
            diveId: id,
            speciesId: 'turtle',
          ),
        );
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion.insert(
            id: 'event-$id',
            diveId: id,
            timestamp: 60,
            eventType: 'gaschange',
            createdAt: 0,
          ),
        );
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion.insert(
            id: 'switch-$id',
            diveId: id,
            timestamp: 60,
            tankId: 'tank-$id',
            createdAt: 0,
          ),
        );
    await db
        .into(db.tankPressureProfiles)
        .insert(
          TankPressureProfilesCompanion.insert(
            id: 'tp-$id',
            diveId: id,
            tankId: 'tank-$id',
            timestamp: 60,
            pressure: 180,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$id',
            diveId: id,
            importedAt: DateTime.utc(2026, 7, 1),
            createdAt: DateTime.utc(2026, 7, 1),
          ).copyWith(isPrimary: const Value(true)),
        );
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: 'media-$id',
            filePath: '/photos/$id.jpg',
            createdAt: 0,
            updatedAt: 0,
          ).copyWith(diveId: Value(id)),
        );
  }

  group('captureSnapshot', () {
    test('captures every child table and media pointers', () async {
      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9));
      await seedDive('b', entry: DateTime.utc(2026, 7, 1, 10));

      final snap = await service.captureSnapshot(['a', 'b'], 'merged-1');

      expect(snap.mergedDiveId, 'merged-1');
      expect(snap.diveRows, hasLength(2));
      expect(snap.profileRows, hasLength(6));
      expect(snap.tankRows, hasLength(2));
      expect(snap.buddyRows, hasLength(2));
      expect(snap.sightingRows, hasLength(2));
      expect(snap.eventRows, hasLength(2));
      expect(snap.gasSwitchRows, hasLength(2));
      expect(snap.tankPressureRows, hasLength(2));
      expect(snap.dataSourceRows, hasLength(2));
      expect(snap.mediaDiveIds, {'media-a': 'a', 'media-b': 'b'});
    });
  });
}
