import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_field_table.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DiveSensorSummaryRepository repo;
  var runs = 0;

  setUp(() async {
    db = await setUpTestDatabase();
    runs = 0;
    // Run the worker on this isolate so the test can count invocations;
    // the default runner goes through compute and is covered separately.
    repo = DiveSensorSummaryRepository(
      db: db,
      runner: (input) async {
        runs++;
        return computeSensorSummaryFromBlobs(input);
      },
    );
  });

  tearDown(tearDownTestDatabase);

  Future<void> insertDive(
    String id, {
    int dateMs = 1000,
    int updatedAt = 1000,
    String mode = 'ccr',
    int? runtime = 3000,
    String? diverId,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: dateMs,
          createdAt: dateMs,
          updatedAt: updatedAt,
        ).copyWith(
          runtime: Value(runtime),
          diveMode: Value(mode),
          diverId: Value(diverId),
        ),
      );

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(id: id, name: id, createdAt: 1, updatedAt: 1),
      );

  Future<void> insertProfile(String diveId, List<ProfileSample> samples) =>
      ProfileSeriesRepository(
        database: db,
      ).insertSeries(diveId: diveId, samples: samples, now: 1000);

  test('a dive without a row is computed and stored', () async {
    await insertDive('d1');
    await insertProfile('d1', const [
      ProfileSample(timestamp: 0, depth: 0, temperature: 10),
      ProfileSample(timestamp: 60, depth: 22, temperature: 4),
    ]);

    final summary = await repo.ensureCurrent('d1');
    expect(runs, 1);
    expect(summary, isNotNull);
    expect(summary!.maxDepth, 22);
    expect(summary.minTemperature, 4);
    // The dive's stamp plus its one profile series'.
    expect(summary.sourceUpdatedAt, 2000);
    expect(summary.engineVersion, DiveSensorSummaryService.version);
    expect(summary.scrubberConsumedMinutes, 50);

    final stored = await repo.getSummary('d1');
    expect(stored, summary);
  });

  test('a current row is returned without recomputing', () async {
    await insertDive('d1');
    await repo.ensureCurrent('d1');
    await repo.ensureCurrent('d1');
    expect(runs, 1);
  });

  test('a current row is served from the stamp and the row alone', () async {
    // The stamp is read before anything the row is built from, so a write
    // landing mid-build leaves the row stale rather than current. The
    // current path therefore never reads the dive: two statements, the
    // stamp and the stored row.
    await tearDownTestDatabase();
    db = AppDatabase(NativeDatabase.memory(logStatements: true));
    DatabaseService.instance.setTestDatabase(db);
    repo = DiveSensorSummaryRepository(
      db: db,
      runner: (input) async => computeSensorSummaryFromBlobs(input),
    );
    await insertDive('d1');
    await repo.ensureCurrent('d1');

    final logged = <String>[];
    await runZoned(
      () => repo.ensureCurrent('d1'),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    final statements = logged.where((l) => l.startsWith('Drift: Sent'));
    expect(statements, hasLength(2));
    expect(statements.where((l) => l.contains('FROM "dives"')), isEmpty);
  });

  test('a row whose source_updated_at differs is recomputed', () async {
    await insertDive('d1', updatedAt: 1000);
    await repo.ensureCurrent('d1');
    await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
      const DivesCompanion(updatedAt: Value(2000), maxDepth: Value(30)),
    );
    final summary = await repo.ensureCurrent('d1');
    expect(runs, 2);
    expect(summary!.sourceUpdatedAt, 2000);
  });

  test('a row from an older engine version is recomputed', () async {
    await insertDive('d1');
    await repo.ensureCurrent('d1');
    await (db.update(db.diveSensorSummaries)
          ..where((t) => t.diveId.equals('d1')))
        .write(const DiveSensorSummariesCompanion(engineVersion: Value(0)));
    await repo.ensureCurrent('d1');
    expect(runs, 2);
  });

  test('force recomputes a current row', () async {
    await insertDive('d1');
    await repo.ensureCurrent('d1');
    await repo.ensureCurrent('d1', force: true);
    expect(runs, 2);
  });

  test('a missing dive yields null and writes nothing', () async {
    expect(await repo.ensureCurrent('nope'), isNull);
    expect(runs, 0);
    expect(await repo.getSummary('nope'), isNull);
  });

  test('tank series reach the worker with the tank identity', () async {
    await insertDive('d1');
    await insertProfile('d1', const [
      ProfileSample(timestamp: 0, depth: 0),
      ProfileSample(timestamp: 100, depth: 10),
    ]);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't1',
            diveId: 'd1',
          ).copyWith(transmitterSerial: const Value('180777')),
        );
    await TankPressureSeriesRepository(database: db).insertSeries(
      diveId: 'd1',
      tankId: 't1',
      samples: const [
        TankPressureSample(timestamp: 0, pressure: 200),
        TankPressureSample(timestamp: 10, pressure: 199),
        TankPressureSample(timestamp: 20, pressure: 198),
        TankPressureSample(timestamp: 100, pressure: 190),
      ],
      now: 1000,
    );

    final summary = await repo.ensureCurrent('d1');
    final gap = summary!.transmitterGaps.single;
    expect(gap.tankId, 't1');
    expect(gap.transmitterSerial, '180777');
    expect(gap.gapCount, 1);
  });

  test('cell metrics and gaps round-trip through the row', () async {
    await insertDive('d1');
    await insertProfile('d1', const [
      ProfileSample(timestamp: 0, depth: 10, o2Sensor1: 1.0, o2Sensor2: 1.0),
      ProfileSample(timestamp: 10, depth: 10, o2Sensor1: 1.0, o2Sensor2: 1.0),
    ]);
    final computed = await repo.ensureCurrent('d1');
    expect(computed!.cellMetrics.map((m) => m.slot), [1, 2]);
    final stored = await repo.getSummary('d1');
    expect(stored!.cellMetrics, computed.cellMetrics);
  });

  test('deleting the dive removes the row', () async {
    await insertDive('d1');
    await repo.ensureCurrent('d1');
    await (db.delete(db.dives)..where((t) => t.id.equals('d1'))).go();
    expect(await repo.getSummary('d1'), isNull);
  });

  test(
    'a dive with a forward-version blob stores nothing and stays stale',
    () async {
      // The samples are readable by a newer build, so persisting a summary
      // computed without them would mark the dive done for its updated_at
      // and it would never be recomputed after upgrading back.
      await insertDive('future');
      await db
          .into(db.diveProfileSeries)
          .insert(
            DiveProfileSeriesCompanion.insert(
              id: 'ps1',
              diveId: 'future',
              startTimestamp: 0,
              endTimestamp: 60,
              sampleCount: 2,
              maxDepth: 9.0,
              firstDepth: 1.0,
              lastDepth: 9.0,
              codecVersion: 3,
              createdAt: 1000,
              updatedAt: 1000,
              samples:
                  const ProfileSeriesCodec(
                    fieldTables: {3: kProfileFieldTableV1},
                  ).encode(const [
                    ProfileSample(timestamp: 0, depth: 1.0),
                    ProfileSample(timestamp: 60, depth: 9.0),
                  ], version: 3).bytes,
            ).copyWith(isPrimary: const Value(true)),
          );

      await expectLater(
        repo.ensureCurrent('future'),
        throwsA(isA<UnknownSeriesVersionException>()),
      );
      expect(await repo.getSummary('future'), isNull);
      expect(await repo.staleDiveIds(), contains('future'));
    },
  );

  group('staleDiveIds', () {
    test(
      'lists missing, stale-source and old-engine rows, oldest first',
      () async {
        await insertDive('missing', dateMs: 3000);
        await insertDive('current', dateMs: 1000);
        await insertDive('stale', dateMs: 2000);
        await insertDive('old', dateMs: 4000);
        await repo.ensureCurrent('current');
        await repo.ensureCurrent('stale');
        await repo.ensureCurrent('old');
        await (db.update(db.dives)..where((t) => t.id.equals('stale'))).write(
          const DivesCompanion(updatedAt: Value(9999)),
        );
        await (db.update(db.diveSensorSummaries)
              ..where((t) => t.diveId.equals('old')))
            .write(const DiveSensorSummariesCompanion(engineVersion: Value(0)));

        expect(await repo.staleDiveIds(), ['stale', 'missing', 'old']);
        expect(await repo.countStale(), 3);
      },
    );

    test('a synced profile series change makes the row stale', () async {
      // Series are synced child rows that never re-stamp their dive
      // (#1769): a new profile arriving by sync leaves dives.updated_at
      // alone, and the summary must still read as stale.
      await insertDive('d1', updatedAt: 1000);
      await insertProfile('d1', const [
        ProfileSample(timestamp: 0, depth: 0),
        ProfileSample(timestamp: 60, depth: 12),
      ]);
      await repo.ensureCurrent('d1');
      expect(await repo.staleDiveIds(), isEmpty);

      await (db.delete(
        db.diveProfileSeries,
      )..where((t) => t.diveId.equals('d1'))).go();
      await ProfileSeriesRepository(database: db).insertSeries(
        diveId: 'd1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0),
          ProfileSample(timestamp: 60, depth: 30),
        ],
        now: 5000,
      );

      expect(await repo.staleDiveIds(), ['d1']);
      final rebuilt = await repo.ensureCurrent('d1');
      expect(runs, 2);
      expect(rebuilt!.maxDepth, 30);
      expect(rebuilt.sourceUpdatedAt, 1000 + 5000);
      expect(await repo.staleDiveIds(), isEmpty);
      await repo.ensureCurrent('d1');
      expect(runs, 2);
    });

    test('a synced tank pressure series makes the row stale', () async {
      await insertDive('d1', updatedAt: 1000);
      await repo.ensureCurrent('d1');
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 't1', diveId: 'd1'));
      await TankPressureSeriesRepository(database: db).insertSeries(
        diveId: 'd1',
        tankId: 't1',
        samples: const [
          TankPressureSample(timestamp: 0, pressure: 200),
          TankPressureSample(timestamp: 600, pressure: 150),
        ],
        now: 5000,
      );

      expect(await repo.staleDiveIds(), ['d1']);
      expect(await repo.countStale(), 1);
      expect((await repo.ensureCurrent('d1'))!.sourceUpdatedAt, 1000 + 5000);
      expect(runs, 2);
    });

    test('removing a series older than the dive makes the row stale', () async {
      // The dive was edited after its profile was written; the latest
      // stamp would not move when the profile goes, the sum does.
      await insertDive('d1', updatedAt: 1000);
      await ProfileSeriesRepository(database: db).insertSeries(
        diveId: 'd1',
        samples: const [ProfileSample(timestamp: 0, depth: 9)],
        now: 500,
      );
      await repo.ensureCurrent('d1');
      expect(await repo.staleDiveIds(), isEmpty);

      await (db.delete(
        db.diveProfileSeries,
      )..where((t) => t.diveId.equals('d1'))).go();
      expect(await repo.staleDiveIds(), ['d1']);
    });

    test('a synced series older than the dive makes the row stale', () async {
      // Device B rewrites the profile at 800, device A edits the dive's
      // buddy at 1000 and builds its summary, then B's series arrives: its
      // updated_at is older than the dive's, and the row must still read
      // as stale.
      await insertDive('d1', updatedAt: 1000);
      await ProfileSeriesRepository(database: db).insertSeries(
        diveId: 'd1',
        samples: const [ProfileSample(timestamp: 0, depth: 12)],
        now: 500,
      );
      await repo.ensureCurrent('d1');
      await (db.update(db.diveProfileSeries)
            ..where((t) => t.diveId.equals('d1')))
          .write(const DiveProfileSeriesCompanion(updatedAt: Value(800)));

      expect(await repo.staleDiveIds(), ['d1']);
      expect((await repo.ensureCurrent('d1'))!.sourceUpdatedAt, 1000 + 800);
      expect(await repo.staleDiveIds(), isEmpty);
    });

    test('a synced tank row change makes the row stale', () async {
      // dive_tanks has no updated_at, only its clock, and a synced tank
      // row never re-stamps its dive (#1769). The transmitter serial the
      // gaps are attributed by lives on it, so its clock is in the stamp.
      await insertDive('d1', updatedAt: 1000);
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: 't1', diveId: 'd1').copyWith(
              transmitterSerial: const Value('111'),
              hlc: const Value('000000000002000:000003:peer'),
            ),
          );
      final built = await repo.ensureCurrent('d1');
      // The dive's stamp plus the tank clock's physical time and counter.
      expect(built!.sourceUpdatedAt, 1000 + 2000 + 3);
      expect(await repo.staleDiveIds(), isEmpty);

      // A peer's newer copy of the tank arrives: new serial, newer clock.
      await (db.update(db.diveTanks)..where((t) => t.id.equals('t1'))).write(
        const DiveTanksCompanion(
          transmitterSerial: Value('222'),
          hlc: Value('000000000002000:000004:peer'),
        ),
      );
      expect(await repo.staleDiveIds(), ['d1']);
      expect((await repo.ensureCurrent('d1'))!.sourceUpdatedAt, 1000 + 2004);
    });

    test('a tank row applied by sync moves the stamp', () async {
      // The peer side, through the real apply: the merge writes the remote
      // row's clock onto the local tank, and that is the only term a
      // tank-only change moves.
      await insertDive('d1', updatedAt: 1000);
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: 't1', diveId: 'd1').copyWith(
              transmitterSerial: const Value('111'),
              hlc: const Value('000000000002000:000000:peer'),
            ),
          );
      await repo.ensureCurrent('d1');
      final remote =
          (await SyncDataSerializer().fetchRecord('diveTanks', 't1'))!
            ..['transmitterSerial'] = '222'
            ..['hlc'] = '000000000003000:000001:peer';

      await SyncDataSerializer().upsertRecord('diveTanks', remote);

      expect(await repo.staleDiveIds(), ['d1']);
      expect((await repo.ensureCurrent('d1'))!.sourceUpdatedAt, 1000 + 3001);
    });

    test('a tank without a clock adds nothing to the stamp', () async {
      await insertDive('d1', updatedAt: 1000);
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 't1', diveId: 'd1'));
      expect((await repo.ensureCurrent('d1'))!.sourceUpdatedAt, 1000);
    });

    test('scopes to a diver when asked', () async {
      await insertDiver('a');
      await insertDiver('b');
      await insertDive('da', diverId: 'a');
      await insertDive('db', diverId: 'b');
      expect(await repo.staleDiveIds(diverId: 'a'), ['da']);
      expect(await repo.staleDiveIds(), ['da', 'db']);
    });
  });

  test('the default runner computes through compute', () async {
    await insertDive('d1');
    await insertProfile('d1', const [ProfileSample(timestamp: 0, depth: 9)]);
    final viaCompute = DiveSensorSummaryRepository(db: db);
    final summary = await viaCompute.ensureCurrent('d1');
    expect(summary!.maxDepth, 9);
  });

  test('saveSummary upserts by dive id', () async {
    await insertDive('d1');
    final first = DiveSensorSummary(
      diveId: 'd1',
      engineVersion: 1,
      sourceUpdatedAt: 1,
      computedAt: DateTime.utc(2026),
      maxDepth: 1,
    );
    await repo.saveSummary(first);
    await repo.saveSummary(
      DiveSensorSummary(
        diveId: 'd1',
        engineVersion: 1,
        sourceUpdatedAt: 2,
        computedAt: DateTime.utc(2026),
        maxDepth: 2,
      ),
    );
    final stored = await repo.getSummary('d1');
    expect(stored!.maxDepth, 2);
    expect(stored.sourceUpdatedAt, 2);
  });
}
