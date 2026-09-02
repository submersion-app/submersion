import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Registers `diveProfileSeries` and `tankPressureSeries` in the sync
/// serializer and service (plan 2d, task 1). Before this, the series tables
/// were invisible to sync: a device that migrated its `dive_profiles` /
/// `tank_pressure_profiles` rows into packed series never pushed them, and a
/// peer never received them.
///
/// Uses two genuinely separate in-memory [AppDatabase] instances, swapped
/// into [DatabaseService] between "device" phases, matching
/// consolidation_sync_roundtrip_test.dart.
void main() {
  late AppDatabase dbA;
  AppDatabase? dbB;
  late FakeCloudStorageProvider cloud;

  setUp(() {
    dbB = null;
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
    await dbA.close();
    final b = dbB;
    if (b != null) {
      await b.close();
    }
  });

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  /// Makes [db] the active database for every repository/service in this
  /// test and drops the process-wide HLC clock so it re-seeds from [db]'s
  /// own sync metadata and row HLCs, rather than carrying over whichever
  /// device was previously active.
  void switchTo(AppDatabase db) {
    DatabaseService.instance.setTestDatabase(db);
    SyncClock.instance.reset();
  }

  Future<void> seedFkPrereqs(AppDatabase db) async {
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver1'),
            name: Value('diver1'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    for (final computerId in ['comp-t', 'comp-s']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: computerId,
              name: computerId,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 'tag1',
            name: 'tag1',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  }

  Future<void> seedBareDive(AppDatabase db, String id) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  }

  test(
    'a series pushed by A arrives on B byte for byte and reads back',
    () async {
      dbB = await setUpTestDatabase();
      dbA = await setUpTestDatabase();
      switchTo(dbA);
      await seedFkPrereqs(dbA);
      await DiveRepository().createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 1, 1, 10),
          profile: const [
            domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
            domain.DiveProfilePoint(
              timestamp: 60,
              depth: 18.5,
              decoType: 2,
              ceiling: 3.0,
            ),
          ],
        ),
      );
      final rowOnA = (await ProfileSeriesRepository().getRowsForDives([
        'd1',
      ])).single;
      expect((await buildService().performSync()).isSuccess, isTrue);

      switchTo(dbB!);
      await seedFkPrereqs(dbB!);
      expect((await buildService().performSync()).isSuccess, isTrue);
      final rowOnB = (await ProfileSeriesRepository().getRowsForDives([
        'd1',
      ])).single;
      expect(rowOnB.id, rowOnA.id);
      expect(rowOnB.samples, rowOnA.samples);
      expect(rowOnB.hasDecoStop, isTrue);
      expect(
        (await DiveRepository().getDiveProfile('d1')).map((p) => p.depth),
        [0.0, 18.5],
      );
    },
  );

  test('a series deleted on A is tombstoned and removed on B', () async {
    dbB = await setUpTestDatabase();
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await DiveRepository().createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 1, 1, 10),
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
          domain.DiveProfilePoint(timestamp: 60, depth: 18.5),
        ],
      ),
    );
    expect((await buildService().performSync()).isSuccess, isTrue);

    switchTo(dbB!);
    await seedFkPrereqs(dbB!);
    expect((await buildService().performSync()).isSuccess, isTrue);
    expect(await ProfileSeriesRepository().getSeriesForDive('d1'), isNotEmpty);

    switchTo(dbA);
    await ProfileSeriesRepository().deleteForDive('d1');
    expect((await buildService().performSync()).isSuccess, isTrue);

    switchTo(dbB!);
    expect((await buildService().performSync()).isSuccess, isTrue);
    expect(await ProfileSeriesRepository().getSeriesForDive('d1'), isEmpty);
  });

  test(
    'a tank pressure series deleted on A is tombstoned and removed on B',
    () async {
      dbB = await setUpTestDatabase();
      dbA = await setUpTestDatabase();
      switchTo(dbA);
      await seedFkPrereqs(dbA);
      await seedBareDive(dbA, 'd1');
      await dbA
          .into(dbA.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'tank1', diveId: 'd1'));
      await TankPressureSeriesRepository().insertSeries(
        diveId: 'd1',
        tankId: 'tank1',
        samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
        now: 1000,
      );
      expect((await buildService().performSync()).isSuccess, isTrue);

      switchTo(dbB!);
      await seedFkPrereqs(dbB!);
      expect((await buildService().performSync()).isSuccess, isTrue);
      expect(
        await TankPressureSeriesRepository().getSeriesForDive('d1'),
        isNotEmpty,
      );

      switchTo(dbA);
      await TankPressureSeriesRepository().deleteForDive('d1');
      expect((await buildService().performSync()).isSuccess, isTrue);

      switchTo(dbB!);
      expect((await buildService().performSync()).isSuccess, isTrue);
      expect(
        await TankPressureSeriesRepository().getSeriesForDive('d1'),
        isEmpty,
      );
    },
  );

  test(
    'fetchRecord carries samples as base64 and upsertRecord round-trips it',
    () async {
      dbA = await setUpTestDatabase();
      switchTo(dbA);
      await seedFkPrereqs(dbA);
      await seedBareDive(dbA, 'd1');
      final id = await ProfileSeriesRepository().insertSeries(
        diveId: 'd1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      final json = await SyncDataSerializer().fetchRecord(
        'diveProfileSeries',
        id,
      );
      expect(json!['samples'], isA<String>());
      await ProfileSeriesRepository().deleteForDive('d1');
      await SyncDataSerializer().upsertRecord('diveProfileSeries', json);
      expect(
        (await ProfileSeriesRepository().getSeriesForDive(
          'd1',
        )).single.samples.single.depth,
        1.0,
      );
    },
  );

  test('millivolts survive the sync export/import round trip', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await seedBareDive(dbA, 'd1');
    final id = await ProfileSeriesRepository().insertSeries(
      diveId: 'd1',
      samples: const [
        ProfileSample(
          timestamp: 0,
          depth: 1.0,
          o2SensorMv1: 550,
          o2SensorMv2: 560,
          o2SensorMv3: 570,
        ),
      ],
      now: 1000,
    );
    final json = await SyncDataSerializer().fetchRecord(
      'diveProfileSeries',
      id,
    );
    await ProfileSeriesRepository().deleteForDive('d1');
    await SyncDataSerializer().upsertRecord('diveProfileSeries', json!);
    final restored = (await ProfileSeriesRepository().getSeriesForDive(
      'd1',
    )).single.samples.single;
    expect(restored.o2SensorMv1, 550);
    expect(restored.o2SensorMv2, 560);
    expect(restored.o2SensorMv3, 570);
  });

  test('a corrupt peer blob is skipped, never written', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await seedBareDive(dbA, 'd1');
    final id = await ProfileSeriesRepository().insertSeries(
      diveId: 'd1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final json = await SyncDataSerializer().fetchRecord(
      'diveProfileSeries',
      id,
    );
    await ProfileSeriesRepository().deleteForDive('d1');
    final corrupted = {
      ...json!,
      'samples': base64Encode(const [1, 2, 3]),
    };
    await SyncDataSerializer().upsertRecord('diveProfileSeries', corrupted);
    expect(await ProfileSeriesRepository().getSeriesForDive('d1'), isEmpty);
  });

  test(
    'a malformed single record is skipped and a sound sibling applies',
    () async {
      dbA = await setUpTestDatabase();
      switchTo(dbA);
      await seedFkPrereqs(dbA);
      await seedBareDive(dbA, 'd1');
      await seedBareDive(dbA, 'd2');
      final goodId = await ProfileSeriesRepository().insertSeries(
        diveId: 'd1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      final good = await SyncDataSerializer().fetchRecord(
        'diveProfileSeries',
        goodId,
      );
      final malformedId = await ProfileSeriesRepository().insertSeries(
        diveId: 'd2',
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: 1000,
      );
      final malformedSource = await SyncDataSerializer().fetchRecord(
        'diveProfileSeries',
        malformedId,
      );
      // Not valid base64, so DiveProfileSeriesRow.fromJson itself throws
      // before the soundness filter ever runs. resolveConflict and the
      // adopt/restore loop call upsertRecord with no per-record catch, so an
      // unguarded parse here aborts the whole restore.
      final malformed = {...malformedSource!, 'samples': 'not base64!'};
      await ProfileSeriesRepository().deleteForDive('d1');
      await ProfileSeriesRepository().deleteForDive('d2');

      await SyncDataSerializer().upsertRecord('diveProfileSeries', malformed);
      await SyncDataSerializer().upsertRecord('diveProfileSeries', good!);

      final remaining = await ProfileSeriesRepository().getRowsForDives([
        'd1',
        'd2',
      ]);
      expect(remaining.map((r) => r.id), [goodId]);
    },
  );

  test('a malformed single tank record is skipped and a sound sibling '
      'applies', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await seedBareDive(dbA, 'd1');
    await dbA
        .into(dbA.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank1', diveId: 'd1'));
    final goodId = await TankPressureSeriesRepository().insertSeries(
      diveId: 'd1',
      tankId: 'tank1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final good = await SyncDataSerializer().fetchRecord(
      'tankPressureSeries',
      goodId,
    );
    await TankPressureSeriesRepository().deleteForDive('d1');
    final malformed = {...good!, 'id': 'tps-malformed', 'samples': 'not b64!'};

    await SyncDataSerializer().upsertRecord('tankPressureSeries', malformed);
    await SyncDataSerializer().upsertRecord('tankPressureSeries', good);

    final remaining = await TankPressureSeriesRepository().getSeriesForDive(
      'd1',
    );
    expect(remaining, hasLength(1));
  });

  test(
    'a peer blob whose sample count disagrees with the header is skipped',
    () async {
      dbA = await setUpTestDatabase();
      switchTo(dbA);
      await seedFkPrereqs(dbA);
      await seedBareDive(dbA, 'd1');
      final id = await ProfileSeriesRepository().insertSeries(
        diveId: 'd1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      final json = await SyncDataSerializer().fetchRecord(
        'diveProfileSeries',
        id,
      );
      await ProfileSeriesRepository().deleteForDive('d1');
      final tampered = {...json!, 'sampleCount': 99};
      await SyncDataSerializer().upsertRecord('diveProfileSeries', tampered);
      expect(await ProfileSeriesRepository().getSeriesForDive('d1'), isEmpty);
    },
  );

  test('a peer blob whose hasDecoStop disagrees with the decoded samples is '
      'skipped', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await seedBareDive(dbA, 'd1');
    final id = await ProfileSeriesRepository().insertSeries(
      diveId: 'd1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final json = await SyncDataSerializer().fetchRecord(
      'diveProfileSeries',
      id,
    );
    await ProfileSeriesRepository().deleteForDive('d1');
    // No sample in the encoded blob carries a decoType, so the decoded
    // summary's hasDecoStop is false; flipping the header must be caught
    // even though the sample count still matches.
    final tampered = {...json!, 'hasDecoStop': true};
    await SyncDataSerializer().upsertRecord('diveProfileSeries', tampered);
    expect(await ProfileSeriesRepository().getSeriesForDive('d1'), isEmpty);
  });

  test('a peer blob whose maxDepth disagrees with the decoded samples is '
      'skipped', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await seedBareDive(dbA, 'd1');
    final id = await ProfileSeriesRepository().insertSeries(
      diveId: 'd1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final json = await SyncDataSerializer().fetchRecord(
      'diveProfileSeries',
      id,
    );
    await ProfileSeriesRepository().deleteForDive('d1');
    final tampered = {...json!, 'maxDepth': 2.0};
    await SyncDataSerializer().upsertRecord('diveProfileSeries', tampered);
    expect(await ProfileSeriesRepository().getSeriesForDive('d1'), isEmpty);
  });

  test('a tank peer blob whose endTimestamp disagrees with the decoded samples '
      'is skipped', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await seedBareDive(dbA, 'd1');
    await dbA
        .into(dbA.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank1', diveId: 'd1'));
    final id = await TankPressureSeriesRepository().insertSeries(
      diveId: 'd1',
      tankId: 'tank1',
      samples: const [
        TankPressureSample(timestamp: 0, pressure: 200.0),
        TankPressureSample(timestamp: 60, pressure: 180.0),
      ],
      now: 1000,
    );
    final json = await SyncDataSerializer().fetchRecord(
      'tankPressureSeries',
      id,
    );
    await TankPressureSeriesRepository().deleteForDive('d1');
    final tampered = {...json!, 'endTimestamp': 61};
    await SyncDataSerializer().upsertRecord('tankPressureSeries', tampered);
    expect(
      await TankPressureSeriesRepository().getSeriesForDive('d1'),
      isEmpty,
    );
  });

  test('a corrupt tank peer blob is skipped, never written', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await seedBareDive(dbA, 'd1');
    await dbA
        .into(dbA.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank1', diveId: 'd1'));
    final id = await TankPressureSeriesRepository().insertSeries(
      diveId: 'd1',
      tankId: 'tank1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final json = await SyncDataSerializer().fetchRecord(
      'tankPressureSeries',
      id,
    );
    await TankPressureSeriesRepository().deleteForDive('d1');
    final corrupted = {
      ...json!,
      'samples': base64Encode(const [1, 2, 3]),
    };
    await SyncDataSerializer().upsertRecord('tankPressureSeries', corrupted);
    expect(
      await TankPressureSeriesRepository().getSeriesForDive('d1'),
      isEmpty,
    );
  });

  test('a batch of tank series with one corrupt blob writes only the sound '
      'rows', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await seedBareDive(dbA, 'd1');
    await seedBareDive(dbA, 'd2');
    await seedBareDive(dbA, 'd3');
    for (final entry in {'tank1': 'd1', 'tank2': 'd2', 'tank3': 'd3'}.entries) {
      await dbA
          .into(dbA.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: entry.key, diveId: entry.value),
          );
    }
    final goodId = await TankPressureSeriesRepository().insertSeries(
      diveId: 'd1',
      tankId: 'tank1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final good = await SyncDataSerializer().fetchRecord(
      'tankPressureSeries',
      goodId,
    );
    final corruptId = await TankPressureSeriesRepository().insertSeries(
      diveId: 'd2',
      tankId: 'tank2',
      samples: const [TankPressureSample(timestamp: 0, pressure: 190.0)],
      now: 1000,
    );
    final corruptSource = await SyncDataSerializer().fetchRecord(
      'tankPressureSeries',
      corruptId,
    );
    // Valid base64 that decodes to bytes the codec rejects, mirroring the
    // diveProfileSeries batch test above.
    final corrupt = {
      ...corruptSource!,
      'samples': base64Encode(const [1, 2, 3]),
    };
    final malformedId = await TankPressureSeriesRepository().insertSeries(
      diveId: 'd3',
      tankId: 'tank3',
      samples: const [TankPressureSample(timestamp: 0, pressure: 180.0)],
      now: 1000,
    );
    final malformedSource = await SyncDataSerializer().fetchRecord(
      'tankPressureSeries',
      malformedId,
    );
    // Not valid base64 at all: throws inside TankPressureSeriesRow.fromJson
    // itself, before soundness is ever checked.
    final malformed = {...malformedSource!, 'samples': 'not base64!'};
    await TankPressureSeriesRepository().deleteForDive('d1');
    await TankPressureSeriesRepository().deleteForDive('d2');
    await TankPressureSeriesRepository().deleteForDive('d3');

    await SyncDataSerializer().upsertRecords('tankPressureSeries', [
      good!,
      corrupt,
      malformed,
    ]);

    final remaining = await TankPressureSeriesRepository().getRowsForDives([
      'd1',
      'd2',
      'd3',
    ]);
    expect(remaining.map((r) => r.id), [goodId]);
  });

  test(
    'a tank pressure series pushed by A arrives on B byte for byte',
    () async {
      dbB = await setUpTestDatabase();
      dbA = await setUpTestDatabase();
      switchTo(dbA);
      await seedFkPrereqs(dbA);
      await seedBareDive(dbA, 'd1');
      await dbA
          .into(dbA.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'tank1', diveId: 'd1'));
      await TankPressureSeriesRepository().insertSeries(
        diveId: 'd1',
        tankId: 'tank1',
        samples: const [
          TankPressureSample(timestamp: 0, pressure: 200.0),
          TankPressureSample(timestamp: 60, pressure: 180.0),
        ],
        now: 1000,
      );
      final rowOnA = (await TankPressureSeriesRepository().getRowsForDives([
        'd1',
      ])).single;
      expect((await buildService().performSync()).isSuccess, isTrue);

      switchTo(dbB!);
      await seedFkPrereqs(dbB!);
      expect((await buildService().performSync()).isSuccess, isTrue);
      final rowOnB = (await TankPressureSeriesRepository().getRowsForDives([
        'd1',
      ])).single;
      expect(rowOnB.id, rowOnA.id);
      expect(rowOnB.samples, rowOnA.samples);
      expect(rowOnB.tankId, 'tank1');
    },
  );

  test('fetchRecords batches diveProfileSeries and tankPressureSeries, '
      'keyed by id with samples as base64', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await seedBareDive(dbA, 'd1');
    await seedBareDive(dbA, 'd2');
    final profileId1 = await ProfileSeriesRepository().insertSeries(
      diveId: 'd1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final profileId2 = await ProfileSeriesRepository().insertSeries(
      diveId: 'd2',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    await dbA
        .into(dbA.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank1', diveId: 'd1'));
    final tankId = await TankPressureSeriesRepository().insertSeries(
      diveId: 'd1',
      tankId: 'tank1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );

    final profileRows = await SyncDataSerializer().fetchRecords(
      'diveProfileSeries',
      [profileId1, profileId2],
    );
    expect(profileRows.keys.toSet(), {profileId1, profileId2});
    expect(profileRows[profileId1]!['samples'], isA<String>());
    expect(profileRows[profileId2]!['samples'], isA<String>());

    final tankRows = await SyncDataSerializer().fetchRecords(
      'tankPressureSeries',
      [tankId],
    );
    expect(tankRows.keys.toSet(), {tankId});
    expect(tankRows[tankId]!['samples'], isA<String>());
  });

  test('a batch with one corrupt blob writes only the sound rows', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await seedBareDive(dbA, 'd1');
    await seedBareDive(dbA, 'd2');
    await seedBareDive(dbA, 'd3');
    final goodId = await ProfileSeriesRepository().insertSeries(
      diveId: 'd1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final good = await SyncDataSerializer().fetchRecord(
      'diveProfileSeries',
      goodId,
    );
    final corruptId = await ProfileSeriesRepository().insertSeries(
      diveId: 'd2',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    final corruptSource = await SyncDataSerializer().fetchRecord(
      'diveProfileSeries',
      corruptId,
    );
    final corrupt = {
      ...corruptSource!,
      'samples': base64Encode(const [1, 2, 3]),
    };
    final malformedId = await ProfileSeriesRepository().insertSeries(
      diveId: 'd3',
      samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
      now: 1000,
    );
    final malformedSource = await SyncDataSerializer().fetchRecord(
      'diveProfileSeries',
      malformedId,
    );
    // Not valid base64 at all, unlike `corrupt` above (which is valid
    // base64 that decodes to bytes the codec rejects): this throws inside
    // DiveProfileSeriesRow.fromJson itself, before soundness is ever
    // checked, which is what the per-record try must also survive.
    final malformed = {...malformedSource!, 'samples': 'not base64!'};
    await ProfileSeriesRepository().deleteForDive('d1');
    await ProfileSeriesRepository().deleteForDive('d2');
    await ProfileSeriesRepository().deleteForDive('d3');

    await SyncDataSerializer().upsertRecords('diveProfileSeries', [
      good!,
      corrupt,
      malformed,
    ]);

    final remaining = await ProfileSeriesRepository().getRowsForDives([
      'd1',
      'd2',
      'd3',
    ]);
    expect(remaining.map((r) => r.id), [goodId]);
  });

  test('fetchRecord carries tank pressure samples as base64 and '
      'upsertRecord round-trips it', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await seedBareDive(dbA, 'd1');
    await dbA
        .into(dbA.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank1', diveId: 'd1'));
    final id = await TankPressureSeriesRepository().insertSeries(
      diveId: 'd1',
      tankId: 'tank1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final json = await SyncDataSerializer().fetchRecord(
      'tankPressureSeries',
      id,
    );
    expect(json!['samples'], isA<String>());
    await TankPressureSeriesRepository().deleteForDive('d1');
    await SyncDataSerializer().upsertRecord('tankPressureSeries', json);
    expect(
      (await TankPressureSeriesRepository().getSeriesForDive(
        'd1',
      )).single.samples.single.pressure,
      200.0,
    );
  });
}
