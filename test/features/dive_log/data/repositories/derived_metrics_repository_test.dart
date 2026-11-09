import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_worker.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show DiveProfilePoint;
import 'package:submersion/features/dive_log/domain/services/gas_use_window.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  var runs = 0;

  DerivedMetricsRepository repo({DiveDerivedMetrics? result}) {
    runs = 0;
    return DerivedMetricsRepository(
      runner: (input) async {
        runs++;
        return result ??
            DiveDerivedMetrics(
              diveId: input.diveId,
              engineVersion: DerivedMetricsService.version,
              sourceUpdatedAt: input.sourceUpdatedAt,
              computedAt: input.computedAtMs,
              finalStopKind: FinalStopKind.safety,
              finalStopDurationSeconds: 180,
              finalStopMaxExcursionMeters: 1.4,
              sacMeanBarPerMin: 0.6,
              sacSlopeBarPerMinPerMin: 0.05,
              sacChangePercent: 25,
              sacBuckets: const [
                SacBucket(index: 0, sacBarPerMin: 0.5),
                SacBucket(index: 1, sacBarPerMin: 0.7),
              ],
            );
      },
    );
  }

  Future<void> insertDive(String id, {int? updatedAt}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(updatedAt ?? now),
        ),
      );

  test('ensureCurrent computes, stores and returns the metrics', () async {
    await insertDive('d1');
    final r = repo();
    final metrics = await r.ensureCurrent('d1');
    expect(metrics, isNotNull);
    expect(runs, 1);
    expect(metrics!.finalStopKind, FinalStopKind.safety);

    final stored = await r.getMetrics('d1');
    expect(stored!.sacMeanBarPerMin, 0.6);
    expect(stored.sacChangePercent, 25);
    expect(stored.sacTrend, SacTrend.rising);
    expect(stored.finalStopState, FinalStopState.unstable);
    expect(stored.finalStopDurationSeconds, 180);
    expect(stored.unsupportedReason, isNull);
    // Buckets are the engine's working, never stored.
    expect(stored.sacBuckets, isEmpty);
  });

  test('the query columns hold the names the dive fields list', () async {
    await insertDive('d1');
    await repo().ensureCurrent('d1');
    final row = await db.select(db.diveDerivedMetricsRows).getSingle();
    expect(row.sacTrend, 'rising');
    expect(row.finalStopState, 'unstable');
    expect(row.sacChangePct, 25);
  });

  test(
    'an unsupported reason round-trips and leaves the fields empty',
    () async {
      await insertDive('d1');
      final r = repo(
        result: DiveDerivedMetrics(
          diveId: 'd1',
          engineVersion: DerivedMetricsService.version,
          sourceUpdatedAt: now,
          computedAt: now,
          unsupportedReason: UnsupportedReason.gaugeMode,
        ),
      );
      await r.ensureCurrent('d1');
      final stored = await r.getMetrics('d1');
      expect(stored!.unsupportedReason, UnsupportedReason.gaugeMode);
      expect(stored.finalStopKind, FinalStopKind.none);
      final row = await db.select(db.diveDerivedMetricsRows).getSingle();
      expect(row.sacTrend, isNull);
      expect(row.finalStopState, isNull);
    },
  );

  group('gas-use window (issue #2930)', () {
    // 30 minutes at 18 m, then 10 logged at the surface.
    final tail = [
      for (var t = 0; t <= 40 * 60; t += 10)
        DiveProfilePoint(
          timestamp: t,
          depth: t == 0
              ? 0
              : t < 30 * 60
              ? 18
              : 0.3,
        ),
    ];

    DerivedMetricsRepository withMerged(List<DiveProfilePoint> merged) =>
        DerivedMetricsRepository(
          runner: (input) async => DiveDerivedMetrics(
            diveId: input.diveId,
            engineVersion: DerivedMetricsService.version,
            sourceUpdatedAt: input.sourceUpdatedAt,
            computedAt: input.computedAtMs,
            unsupportedReason: UnsupportedReason.gaugeMode,
          ),
          mergedProfile: (_) async => merged,
        );

    test('comes from the merged profile, whatever the engine saw', () async {
      await insertDive('d1');
      final r = withMerged(tail);
      final metrics = await r.ensureCurrent('d1');
      final window = gasUseWindowOf(
        tail,
        time: (p) => p.timestamp,
        depth: (p) => p.depth,
      )!;
      expect(metrics!.gasUseSeconds, window.seconds);
      final stored = await r.getMetrics('d1');
      expect(stored!.gasUseSeconds, window.seconds);
      expect(stored.gasUseAvgDepthMeters, window.avgDepth);
      // The engine's own fields are kept.
      expect(stored.unsupportedReason, UnsupportedReason.gaugeMode);
    });

    test('is cleared when the rebuilt dive has no surface tail', () async {
      await insertDive('d1');
      await withMerged(tail).ensureCurrent('d1');
      final noTail = [
        for (final p in tail)
          if (p.timestamp <= 30 * 60) p,
      ];
      await withMerged(noTail).ensureCurrent('d1', force: true);
      final stored = await repo().getMetrics('d1');
      expect(stored!.gasUseSeconds, isNull);
      expect(stored.gasUseAvgDepthMeters, isNull);
    });

    test('a repository bound to its own database must name its reader', () {
      expect(
        () => DerivedMetricsRepository(database: db),
        throwsA(isA<AssertionError>()),
      );
      expect(
        DerivedMetricsRepository(
          database: db,
          mergedProfile: (_) async => const [],
        ),
        isNotNull,
      );
    });

    test('is none for a dive with no profile', () async {
      await insertDive('d1');
      final metrics = await withMerged(const []).ensureCurrent('d1');
      expect(metrics!.gasUseSeconds, isNull);
    });
  });

  test('a second call reads the stored row without recomputing', () async {
    await insertDive('d1');
    final r = repo();
    await r.ensureCurrent('d1');
    await r.ensureCurrent('d1');
    expect(runs, 1);
  });

  test('force recomputes even when the row is current', () async {
    await insertDive('d1');
    final r = repo();
    await r.ensureCurrent('d1');
    await r.ensureCurrent('d1', force: true);
    expect(runs, 2);
  });

  group('the environment handed to the worker (issue #3958)', () {
    Future<DiveEnvironment> environmentOf(String diveId) async {
      late DiveEnvironment seen;
      await DerivedMetricsRepository(
        runner: (input) async {
          seen = input.environment;
          return DiveDerivedMetrics(
            diveId: input.diveId,
            engineVersion: DerivedMetricsService.version,
            sourceUpdatedAt: input.sourceUpdatedAt,
            computedAt: input.computedAtMs,
          );
        },
      ).ensureCurrent(diveId);
      return seen;
    }

    Future<void> insertConditions(
      String id, {
      double? altitude,
      String? waterType,
      String? siteId,
    }) => db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            altitude: Value(altitude),
            waterType: Value(waterType),
            siteId: Value(siteId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    Future<void> insertFreshSite(String id) => db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value(id),
            name: const Value('Lake'),
            waterType: const Value('fresh'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    test('reads the dive\'s own conditions', () async {
      await insertConditions('d1', altitude: 3000, waterType: 'fresh');

      expect(
        await environmentOf('d1'),
        DiveEnvironment.forConditions(
          altitudeMeters: 3000,
          waterType: WaterType.fresh,
        ),
      );
    });

    test('falls back to the site water type', () async {
      await insertFreshSite('s1');
      await insertConditions('d1', siteId: 's1');

      expect(
        (await environmentOf('d1')).waterDensityKgM3,
        DiveEnvironment.freshWaterDensity,
      );
    });

    Future<void> setSiteWater(String id, String waterType) =>
        (db.update(db.diveSites)..where((t) => t.id.equals(id))).write(
          DiveSitesCompanion(waterType: Value(waterType)),
        );

    test('a site water edit makes the dives taking it stale', () async {
      await insertFreshSite('s1');
      await insertConditions('d1', siteId: 's1');
      final r = repo();
      await r.ensureCurrent('d1');
      expect(await r.staleDiveIds(), isEmpty);

      await setSiteWater('s1', 'salt');

      expect(await r.staleDiveIds(), ['d1']);
      await r.ensureCurrent('d1');
      expect(runs, 2);
      expect(await r.staleDiveIds(), isEmpty);
    });

    test('a site water edit leaves a dive with its own water alone', () async {
      await insertFreshSite('s1');
      await insertConditions('d1', waterType: 'brackish', siteId: 's1');
      final r = repo();
      await r.ensureCurrent('d1');

      await setSiteWater('s1', 'salt');

      expect(await r.staleDiveIds(), isEmpty);
    });

    test('a blank water type on the dive takes its site\'s', () async {
      await insertFreshSite('s1');
      await insertConditions('d1', waterType: '', siteId: 's1');

      expect(
        (await environmentOf('d1')).waterDensityKgM3,
        DiveEnvironment.freshWaterDensity,
      );
    });

    test('a blank water type on both reads the standard water', () async {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion(
              id: const Value('s1'),
              name: const Value('Lake'),
              waterType: const Value(''),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await insertConditions('d1', waterType: '', siteId: 's1');

      expect(await environmentOf('d1'), DiveEnvironment.standard);
    });

    test('the dive\'s water type wins over its site\'s', () async {
      await insertFreshSite('s1');
      await insertConditions('d1', waterType: 'salt', siteId: 's1');

      expect(
        (await environmentOf('d1')).waterDensityKgM3,
        DiveEnvironment.saltWaterDensity,
      );
    });
  });

  test('a dive that does not exist yields null and no work', () async {
    final r = repo();
    expect(await r.ensureCurrent('missing'), isNull);
    expect(runs, 0);
  });

  group('staleDiveIds', () {
    test('lists a dive with no row', () async {
      await insertDive('d1');
      expect(await repo().staleDiveIds(), ['d1']);
    });

    test('lists a dive whose engine version is older', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      await db.customStatement(
        'UPDATE dive_derived_metrics SET engine_version = 0',
      );
      expect(await r.staleDiveIds(), ['d1']);
    });

    test('lists a dive whose source stamp drifted', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
        DivesCompanion(updatedAt: Value(now + 1)),
      );
      expect(await r.staleDiveIds(), ['d1']);
    });

    test('omits a dive that is current', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      expect(await r.staleDiveIds(), isEmpty);
    });

    test('returns the newest dive first', () async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('new'),
              diveDateTime: Value(now + 1000),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await insertDive('old');
      // The dives a diver searches most are the recent ones.
      expect(await repo().staleDiveIds(), ['new', 'old']);
    });

    test('a diver filter narrows the work list', () async {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: const Value('diver1'),
              name: const Value('Ada'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('mine'),
              diverId: const Value('diver1'),
              diveDateTime: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await insertDive('theirs');
      expect(await repo().staleDiveIds(diverId: 'diver1'), ['mine']);
    });
  });

  test('the change tick fires on a metrics write', () async {
    await insertDive('d1');
    final r = repo();
    final ticks = <void>[];
    final sub = r.watchChanges().listen(ticks.add);
    await r.ensureCurrent('d1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(ticks, isNotEmpty);
  });

  test(
    'each tank sends its richest pressure series, with its volume',
    () async {
      await insertDive('d1');
      Future<void> tank(String id, {double? volume}) => db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: id,
              diveId: 'd1',
              volume: Value(volume),
            ),
          );
      Future<void> series(String id, String tankId, int count, int marker) => db
          .into(db.tankPressureSeries)
          .insert(
            TankPressureSeriesCompanion.insert(
              id: id,
              diveId: 'd1',
              tankId: tankId,
              sampleCount: count,
              startTimestamp: 0,
              endTimestamp: 600,
              codecVersion: 1,
              samples: Uint8List.fromList([marker]),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await tank('t1', volume: 12);
      await tank('t2');
      // Two computers logged t1: the longer series wins; on a tie, the lower
      // id. t2 has no series and sends nothing.
      await series('s-b', 't1', 20, 2);
      await series('s-a', 't1', 20, 1);
      await series('s-short', 't1', 5, 3);

      DerivedMetricsWorkInput? seen;
      await DerivedMetricsRepository(
        runner: (input) async {
          seen = input;
          return DiveDerivedMetrics(
            diveId: input.diveId,
            engineVersion: DerivedMetricsService.version,
            sourceUpdatedAt: input.sourceUpdatedAt,
            computedAt: input.computedAtMs,
          );
        },
      ).ensureCurrent('d1');

      expect(seen!.tankBlobs, hasLength(1));
      final blob = seen!.tankBlobs.single;
      expect(blob.tankId, 't1');
      expect(blob.volumeLiters, 12);
      expect(blob.samples, [1]);
    },
  );

  test('the default runner computes on a worker isolate', () async {
    await insertDive('d1');
    // No profile: the real engine, run through compute(), says so.
    final metrics = await DerivedMetricsRepository().ensureCurrent('d1');
    expect(metrics!.unsupportedReason, UnsupportedReason.noProfile);
  });

  test(
    'a stored name this build does not know reads as the safe default',
    () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      await db.customStatement(
        "UPDATE dive_derived_metrics SET final_stop_kind = 'future', "
        "unsupported_reason = 'future'",
      );
      final stored = await r.getMetrics('d1');
      expect(stored!.finalStopKind, FinalStopKind.none);
      expect(stored.unsupportedReason, UnsupportedReason.noProfile);
    },
  );

  test(
    'a synced series change makes the row stale without the dive changing',
    () async {
      // A synced child row never re-stamps its dive (#1769), so the dive's
      // updated_at alone would call these metrics current forever.
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      expect(await r.staleDiveIds(), isEmpty);

      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 't1', diveId: 'd1'));
      await db
          .into(db.tankPressureSeries)
          .insert(
            TankPressureSeriesCompanion.insert(
              id: 's1',
              diveId: 'd1',
              tankId: 't1',
              sampleCount: 2,
              startTimestamp: 0,
              endTimestamp: 600,
              codecVersion: 1,
              samples: Uint8List.fromList([1]),
              createdAt: now + 5,
              updatedAt: now + 5,
            ),
          );
      expect(await r.staleDiveIds(), ['d1']);
      await r.ensureCurrent('d1');
      expect(runs, 2);
      expect(await r.staleDiveIds(), isEmpty);
    },
  );

  test(
    'a synced series older than the dive still makes the row stale',
    () async {
      // The profile rewritten on one device, the dive edited later on
      // another, then a sync: the series' updated_at is older than the
      // dive's, and the stamp must still move.
      await insertDive('d1', updatedAt: now);
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 't1', diveId: 'd1'));
      await db
          .into(db.tankPressureSeries)
          .insert(
            TankPressureSeriesCompanion.insert(
              id: 's1',
              diveId: 'd1',
              tankId: 't1',
              sampleCount: 2,
              startTimestamp: 0,
              endTimestamp: 600,
              codecVersion: 1,
              samples: Uint8List.fromList([1]),
              createdAt: now - 100,
              updatedAt: now - 100,
            ),
          );
      final r = repo();
      await r.ensureCurrent('d1');
      expect(await r.staleDiveIds(), isEmpty);

      await (db.update(db.tankPressureSeries)..where((t) => t.id.equals('s1')))
          .write(TankPressureSeriesCompanion(updatedAt: Value(now - 50)));
      expect(await r.staleDiveIds(), ['d1']);
      final rebuilt = await r.ensureCurrent('d1');
      expect(runs, 2);
      expect(rebuilt!.sourceUpdatedAt, now + (now - 50));
    },
  );

  test('a gas switch added later makes the row stale (#2930)', () async {
    // A switch logged on the surface stretches the gas-use window, and a
    // synced switch never re-stamps its dive.
    await insertDive('d1', updatedAt: now);
    final r = repo();
    await r.ensureCurrent('d1');
    expect(await r.staleDiveIds(), isEmpty);

    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 't1', diveId: 'd1'));
    await r.ensureCurrent('d1');
    expect(await r.staleDiveIds(), isEmpty);
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion.insert(
            id: 'sw',
            diveId: 'd1',
            timestamp: 2100,
            tankId: 't1',
            createdAt: now,
          ),
        );
    expect(await r.staleDiveIds(), ['d1']);
  });

  test('a new primary computer makes the row stale (#2930)', () async {
    // The pressure series that say a cylinder was breathed on the surface
    // are the primary computer's, and a synced source flag never re-stamps
    // its dive.
    await insertDive('d1', updatedAt: now);
    for (final (id, primary) in [('a', true), ('b', false)]) {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: id,
              diveId: 'd1',
              importedAt: DateTime(2026, 6, 1),
              createdAt: DateTime(2026, 6, 1),
            ).copyWith(isPrimary: Value(primary)),
          );
    }
    final r = repo();
    await r.ensureCurrent('d1');
    expect(await r.staleDiveIds(), isEmpty);

    for (final (id, primary) in [('a', false), ('b', true)]) {
      await (db.update(db.diveDataSources)..where((s) => s.id.equals(id)))
          .write(DiveDataSourcesCompanion(isPrimary: Value(primary)));
    }
    expect(await r.staleDiveIds(), ['d1']);
  });

  test('a synced tank row change makes the row stale', () async {
    // A tank's volume and identity live on dive_tanks, whose own clock is
    // the only thing a synced copy of it moves.
    await insertDive('d1', updatedAt: now);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: 't1', diveId: 'd1').copyWith(
            volume: const Value(11.1),
            hlc: const Value('000000000005000:000000:peer'),
          ),
        );
    final r = repo();
    await r.ensureCurrent('d1');
    expect(await r.staleDiveIds(), isEmpty);

    await (db.update(db.diveTanks)..where((t) => t.id.equals('t1'))).write(
      const DiveTanksCompanion(
        volume: Value(12.0),
        hlc: Value('000000000006000:000000:peer'),
      ),
    );
    expect(await r.staleDiveIds(), ['d1']);
    expect((await r.ensureCurrent('d1'))!.sourceUpdatedAt, now + 6000);
  });

  test('a suit inflation bottle never feeds the SAC drift (#4243)', () async {
    await insertDive('d1');
    for (final (id, role) in [
      ('suit', TankRole.suitInflation),
      ('back', TankRole.backGas),
    ]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: id,
              diveId: 'd1',
              tankRole: Value(role.name),
            ),
          );
      await db
          .into(db.tankPressureSeries)
          .insert(
            TankPressureSeriesCompanion.insert(
              id: 's-$id',
              diveId: 'd1',
              tankId: id,
              sampleCount: 2,
              startTimestamp: 0,
              endTimestamp: 600,
              codecVersion: 1,
              samples: Uint8List.fromList([1]),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    List<String>? tankIds;
    final r = DerivedMetricsRepository(
      runner: (input) async {
        tankIds = [for (final blob in input.tankBlobs) blob.tankId];
        return DiveDerivedMetrics(
          diveId: input.diveId,
          engineVersion: DerivedMetricsService.version,
          sourceUpdatedAt: input.sourceUpdatedAt,
          computedAt: input.computedAtMs,
        );
      },
    );

    await r.ensureCurrent('d1');

    expect(tankIds, ['back']);
  });
}
