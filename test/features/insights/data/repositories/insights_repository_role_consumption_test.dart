import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/role_consumption.dart';
import 'package:submersion/features/insights/domain/role_consumption_trend.dart';

import '../../../../helpers/test_database.dart';

/// Consumption by cylinder role per dive (issue #771), read from the
/// database and checked against the dive detail's own per-cylinder SAC.
void main() {
  late InsightsRepository repository;
  late AppDatabase db;

  Future<void> insertDive(
    String id, {
    String diveMode = 'oc',
    int day = 1,
    bool excludedFromGasStats = false,
    String? diverId,
    int? runtime = 60 * 60,
    double? avgDepth = 20.0,
    String? siteId,
  }) async {
    final at = DateTime.utc(2026, 1, day).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(at),
            diveMode: Value(diveMode),
            diverId: Value(diverId),
            runtime: Value(runtime),
            avgDepth: Value(avgDepth),
            siteId: Value(siteId),
            maxDepth: const Value(25.0),
            excludedFromGasStats: Value(excludedFromGasStats),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
  }

  Future<void> insertTank(
    String diveId,
    String id,
    String role, {
    double start = 200,
    double end = 80,
    double volume = 12,
    double o2 = 21,
    int order = 0,
    String? computerId,
    int? surfaceBreathingSeconds,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value(id),
          diveId: Value(diveId),
          startPressure: Value(start),
          endPressure: Value(end),
          volume: Value(volume),
          tankRole: Value(role),
          o2Percent: Value(o2),
          hePercent: const Value(0.0),
          tankOrder: Value(order),
          computerId: Value(computerId),
          surfaceBreathingDuration: Value(surfaceBreathingSeconds),
        ),
      );

  Future<void> insertSwitch(String diveId, String tankId, int timestamp) => db
      .into(db.gasSwitches)
      .insert(
        GasSwitchesCompanion(
          id: Value('$tankId-$timestamp'),
          diveId: Value(diveId),
          tankId: Value(tankId),
          timestamp: Value(timestamp),
          createdAt: const Value(0),
        ),
      );

  /// One sample every [step] seconds: [bottom] m (with a small wobble), an
  /// ascent at 9 m/min that reaches [shallow] m at [switchAt], then [shallow]
  /// m to [end].
  Future<void> insertProfile(
    String diveId, {
    int end = 60 * 60,
    int switchAt = 50 * 60,
    double bottom = 25,
    double shallow = 6,
    int step = 10,
  }) {
    final ascentStart = switchAt - ((bottom - shallow) / 9 * 60).round();
    double depthAt(int t) {
      if (t >= switchAt) return shallow;
      if (t >= ascentStart) return bottom - (t - ascentStart) * 9 / 60;
      return bottom + (t % 120) / 60;
    }

    return ProfileSeriesRepository().insertSeries(
      diveId: diveId,
      samples: [
        for (var t = 0; t <= end; t += step)
          ProfileSample(timestamp: t, depth: depthAt(t)),
      ],
      now: 0,
    );
  }

  /// Back gas, then deco from 50 minutes.
  Future<void> insertTechDive(String id, {int day = 1}) async {
    await insertDive(id, day: day);
    await insertTank(id, '$id-back', 'backGas');
    await insertTank(
      id,
      '$id-deco',
      'deco',
      volume: 7,
      o2: 50,
      end: 140,
      order: 1,
    );
    await insertSwitch(id, '$id-deco', 50 * 60);
    await insertProfile(id);
  }

  Future<List<CylinderSacRowsForTest>> detailRows(String diveId) async {
    final dives = DiveRepository();
    final dive = (await dives.getDiveById(diveId))!;
    final rows = const GasAnalysisService(gasModel: GasModel.real)
        .calculateCylinderSac(
          dive: dive,
          profile: dive.profile,
          gasSwitches: await dives.getGasSwitchesForDive(diveId),
        );
    return [
      for (final row in rows)
        (tankId: row.tankId, rmv: row.rmv, sacRate: row.sacRate),
    ];
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository(gasModel: GasModel.real);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('one dive reads the same as the dive detail', () async {
    await insertTechDive('tech');
    final rows = await detailRows('tech');
    final deco = rows.singleWhere((r) => r.tankId == 'tech-deco');
    final back = rows.singleWhere((r) => r.tankId == 'tech-back');

    final trend = await repository.getRoleConsumptionPerDive();

    expect(
      trend.rmv[ConsumptionRoleGroup.deco]!.single.value,
      closeTo(deco.rmv!, deco.rmv! * 0.02),
    );
    expect(
      trend.rmv[ConsumptionRoleGroup.bottomGas]!.single.value,
      closeTo(back.rmv!, back.rmv! * 0.02),
    );
    expect(
      trend.sac[ConsumptionRoleGroup.deco]!.single.value,
      closeTo(deco.sacRate!, deco.sacRate! * 0.02),
    );
    expect(trend.rmv[ConsumptionRoleGroup.deco]!.single.diveId, 'tech');
  });

  test('entered surface minutes reach a one-cylinder group (#2930)', () async {
    // No profile: an hour at 20 m, plus ten minutes of the back gas breathed
    // on the boat after the computer stopped.
    await insertDive('boat');
    await insertTank(
      'boat',
      'boat-back',
      'backGas',
      surfaceBreathingSeconds: 600,
    );
    final back = (await detailRows('boat')).single;

    final trend = await repository.getRoleConsumptionPerDive();

    final value = trend.rmv[ConsumptionRoleGroup.bottomGas]!.single.value;
    expect(value, closeTo(back.rmv!, 1e-9));
  });

  test('a surface tail is left out of the last cylinder (#2930)', () async {
    // Back gas then a stage from 30 minutes, at 6 m until the hour. The
    // second dive's computer then logs ten more minutes at the surface.
    Future<void> insertStageDive(
      String id, {
      required int day,
      int? tail,
    }) async {
      final end = 60 * 60 + (tail ?? 0);
      await insertDive(id, day: day, runtime: end, avgDepth: 6);
      await insertTank(id, '$id-back', 'backGas', end: 150);
      await insertTank(id, '$id-stage', 'stage', end: 120, order: 1);
      await insertSwitch(id, '$id-back', 0);
      await insertSwitch(id, '$id-stage', 30 * 60);
      await ProfileSeriesRepository().insertSeries(
        diveId: id,
        samples: [
          for (var t = 0; t <= end; t += 10)
            ProfileSample(timestamp: t, depth: t <= 60 * 60 ? 6.0 : 0.3),
        ],
        now: 0,
      );
    }

    await insertStageDive('plain', day: 1);
    await insertStageDive('tail', day: 2, tail: 10 * 60);
    final detail = (await detailRows(
      'tail',
    )).singleWhere((r) => r.tankId == 'tail-stage');

    final trend = await repository.getRoleConsumptionPerDive();
    double stageRmv(String id) => trend.rmv[ConsumptionRoleGroup.stage]!
        .singleWhere((p) => p.diveId == id)
        .value;

    // Divided by its 30 underwater minutes, not 40.
    expect(
      stageRmv('tail'),
      closeTo(stageRmv('plain'), stageRmv('plain') * 0.02),
    );
    expect(stageRmv('tail'), closeTo(detail.rmv!, detail.rmv! * 0.02));
  });

  test(
    'the 120-point summary stays within 2% of full samples on a deco dive',
    () async {
      await insertDive('deep', runtime: 70 * 60);
      await insertTank('deep', 'deep-back', 'backGas', end: 60);
      await insertTank(
        'deep',
        'deep-deco',
        'deco',
        volume: 7,
        o2: 50,
        end: 150,
        order: 1,
      );
      await insertSwitch('deep', 'deep-deco', 65 * 60);
      await insertProfile(
        'deep',
        end: 70 * 60,
        switchAt: 65 * 60,
        bottom: 40,
        shallow: 6,
        step: 1,
      );
      final rows = await detailRows('deep');
      final deco = rows.singleWhere((r) => r.tankId == 'deep-deco');

      final trend = await repository.getRoleConsumptionPerDive();

      expect(
        trend.rmv[ConsumptionRoleGroup.deco]!.single.value,
        closeTo(deco.rmv!, deco.rmv! * 0.02),
      );
    },
  );

  test(
    'a short deco window on a long dive stays within 2% of full samples',
    () async {
      // Four hours: 120 evenly spaced points would be two minutes apart, so a
      // three-minute deco stint would rest on one or two of them.
      await insertDive('cave', runtime: 240 * 60);
      await insertTank('cave', 'cave-back', 'backGas', end: 40);
      await insertTank(
        'cave',
        'cave-deco',
        'deco',
        volume: 7,
        o2: 50,
        end: 170,
        order: 1,
      );
      // Deco from 21 m at 222 minutes, a minute and a half at each 3 m stop up
      // to 6 m, then back gas for the last stretch.
      await insertSwitch('cave', 'cave-deco', 222 * 60);
      await insertSwitch('cave', 'cave-back', 231 * 60);
      double depthAt(int t) {
        const decoStart = 222 * 60;
        if (t < decoStart - 240) return 50 + (t % 120) / 60;
        if (t < decoStart) return 50 - (t - (decoStart - 240)) * 29 / 240;
        final stop = (t - decoStart) ~/ 90;
        return stop >= 6 ? 6 : 21 - stop * 3.0;
      }

      await ProfileSeriesRepository().insertSeries(
        diveId: 'cave',
        samples: [
          for (var t = 0; t <= 240 * 60; t++)
            ProfileSample(timestamp: t, depth: depthAt(t)),
        ],
        now: 0,
      );
      final rows = await detailRows('cave');
      final deco = rows.singleWhere((r) => r.tankId == 'cave-deco');

      final trend = await repository.getRoleConsumptionPerDive();

      expect(
        trend.rmv[ConsumptionRoleGroup.deco]!.single.value,
        closeTo(deco.rmv!, deco.rmv! * 0.02),
      );
    },
  );

  group('a second read', () {
    double bottomGas(RoleConsumptionTrend trend) =>
        trend.rmv[ConsumptionRoleGroup.bottomGas]!.single.value;

    test('reuses a dive whose stamp did not move', () async {
      await insertDive('plain');
      await insertTank('plain', 'plain-back', 'backGas');
      final first = bottomGas(await repository.getRoleConsumptionPerDive());

      // A write that moves no stamp: nothing says the dive changed.
      await db.customStatement(
        "UPDATE dive_tanks SET end_pressure = 20 WHERE id = 'plain-back'",
      );

      expect(
        bottomGas(await repository.getRoleConsumptionPerDive()),
        closeTo(first, 1e-9),
      );
    });

    test('reads a tank change that moves its clock', () async {
      await insertDive('plain');
      await insertTank('plain', 'plain-back', 'backGas');
      final first = bottomGas(await repository.getRoleConsumptionPerDive());

      await db.customStatement(
        "UPDATE dive_tanks SET end_pressure = 20, "
        "hlc = '000000000000002:000001:node' WHERE id = 'plain-back'",
      );

      expect(
        bottomGas(await repository.getRoleConsumptionPerDive()),
        greaterThan(first),
      );
    });

    test('reads a gas switch that arrived alone', () async {
      await insertDive('hand');
      await insertTank('hand', 'hand-back', 'backGas');
      await insertTank(
        'hand',
        'hand-deco',
        'deco',
        volume: 7,
        o2: 50,
        end: 140,
        order: 1,
      );
      expect((await repository.getRoleConsumptionPerDive()).leftOutDives, 1);

      await insertSwitch('hand', 'hand-deco', 50 * 60);
      final trend = await repository.getRoleConsumptionPerDive();

      expect(trend.leftOutDives, 0);
      expect(trend.rmv[ConsumptionRoleGroup.deco], hasLength(1));
    });

    test(
      'reads a site water change, which never re-stamps its dives',
      () async {
        await db
            .into(db.diveSites)
            .insert(
              const DiveSitesCompanion(
                id: Value('reef'),
                name: Value('Reef'),
                waterType: Value('salt'),
                createdAt: Value(0),
                updatedAt: Value(0),
              ),
            );
        await insertDive('plain', siteId: 'reef');
        await insertTank('plain', 'plain-back', 'backGas');
        final salt = bottomGas(await repository.getRoleConsumptionPerDive());

        await db.customStatement(
          "UPDATE dive_sites SET water_type = 'fresh' WHERE id = 'reef'",
        );

        // Fresh water weighs less, so the same depth is a lower ambient
        // pressure and the same gas a higher surface rate.
        expect(
          bottomGas(await repository.getRoleConsumptionPerDive()),
          greaterThan(salt),
        );
      },
    );

    test('reads switches that moved by amounts that cancel out', () async {
      await insertDive('tech');
      await insertTank('tech', 'tech-back', 'backGas');
      await insertTank(
        'tech',
        'tech-deco',
        'deco',
        volume: 7,
        o2: 50,
        end: 140,
        order: 1,
      );
      await insertSwitch('tech', 'tech-deco', 40 * 60);
      await insertSwitch('tech', 'tech-back', 50 * 60);
      await insertProfile('tech', switchAt: 40 * 60);
      double deco(RoleConsumptionTrend trend) =>
          trend.rmv[ConsumptionRoleGroup.deco]!.single.value;
      final before = deco(await repository.getRoleConsumptionPerDive());

      // A sync pull writes switches without re-stamping the dive. The count,
      // the sum of the times and the cylinders named all stay the same.
      await db.customStatement(
        "UPDATE gas_switches SET timestamp = timestamp + 60 "
        "WHERE id = 'tech-deco-${40 * 60}'",
      );
      await db.customStatement(
        "UPDATE gas_switches SET timestamp = timestamp - 60 "
        "WHERE id = 'tech-back-${50 * 60}'",
      );

      // Eight minutes on deco instead of ten.
      expect(
        deco(await repository.getRoleConsumptionPerDive()),
        greaterThan(before * 1.2),
      );
    });

    test('two reads at once agree with one read alone', () async {
      await insertTechDive('one', day: 1);
      await insertTechDive('two', day: 2);

      final (a, b) = await (
        repository.getRoleConsumptionPerDive(),
        repository.getRoleConsumptionPerDive(),
      ).wait;
      final alone = await InsightsRepository(
        gasModel: GasModel.real,
      ).getRoleConsumptionPerDive();

      for (final trend in [a, b]) {
        for (final group in alone.rmv.keys) {
          expect(
            trend.rmv[group]!.map((p) => p.value),
            alone.rmv[group]!.map((p) => p.value),
          );
        }
        expect(trend.rmv.keys, alone.rmv.keys);
      }
    });

    test('retries a dive whose profile failed to read beside one that read '
        'fine', () async {
      await insertTechDive('bad', day: 1);
      await insertTechDive('good', day: 2);
      final series = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.diveId.equals('bad'))).getSingle();
      Future<void> writeSamples(Uint8List bytes) =>
          (db.update(db.diveProfileSeries)
                ..where((t) => t.id.equals(series.id)))
              .write(DiveProfileSeriesCompanion(samples: Value(bytes)));

      // Bytes the codec cannot decode: the batch read leaves this dive out
      // and still returns the other one. The stamp does not move.
      await writeSamples(Uint8List.fromList(const [1, 2, 3, 4]));
      await repository.getRoleConsumptionPerDive();
      await writeSamples(series.samples);

      final retried = await repository.getRoleConsumptionPerDive();
      final alone = await InsightsRepository(
        gasModel: GasModel.real,
      ).getRoleConsumptionPerDive();
      for (final group in alone.rmv.keys) {
        expect(
          retried.rmv[group]!.map((p) => p.value),
          alone.rmv[group]!.map((p) => p.value),
        );
      }
    });

    test('drops a deleted dive', () async {
      await insertDive('gone');
      await insertTank('gone', 'gone-back', 'backGas');
      await repository.getRoleConsumptionPerDive();

      await db.customStatement("DELETE FROM dives WHERE id = 'gone'");

      expect((await repository.getRoleConsumptionPerDive()).rmv, isEmpty);
    });
  });

  test('a profileless back gas dive uses the stored average depth', () async {
    await insertDive('plain');
    await insertTank('plain', 'plain-back', 'backGas');
    final rows = await detailRows('plain');

    final trend = await repository.getRoleConsumptionPerDive();

    expect(
      trend.rmv[ConsumptionRoleGroup.bottomGas]!.single.value,
      closeTo(rows.single.rmv!, 1e-9),
    );
  });

  test('a profileless dive stored at 0 m adds no point', () async {
    // The SAC trend leaves it out too: dividing at the surface would read
    // about three times a 20 m rate.
    await insertDive('flat', avgDepth: 0);
    await insertTank('flat', 'flat-back', 'backGas');

    final trend = await repository.getRoleConsumptionPerDive();

    expect(trend.rmv, isEmpty);
    expect(trend.sac, isEmpty);
    expect(await repository.getSacVolumePerDive(), isEmpty);
  });

  test('a dive with no runtime and no profile adds no point', () async {
    await insertDive('blank', runtime: null);
    await insertTank('blank', 'blank-back', 'backGas');

    final trend = await repository.getRoleConsumptionPerDive();

    expect(trend.rmv, isEmpty);
    expect(trend.sac, isEmpty);
    expect(trend.leftOutDives, 0);
  });

  test('CCR, SCR and gauge dives add nothing to open-circuit groups', () async {
    for (final (id, mode, day) in [
      ('oc', 'oc', 1),
      ('ccr', 'ccr', 2),
      ('scr', 'scr', 3),
      ('gauge', 'gauge', 4),
    ]) {
      await insertDive(id, diveMode: mode, day: day);
      await insertTank(id, '$id-back', 'backGas');
    }

    final trend = await repository.getRoleConsumptionPerDive();

    expect(trend.rmv.keys, [ConsumptionRoleGroup.bottomGas]);
    expect(trend.rmv[ConsumptionRoleGroup.bottomGas]!.map((p) => p.diveId), [
      'oc',
    ]);
  });

  test('a CCR dive with a recorded bailout adds a bailout point', () async {
    await insertDive('ccr', diveMode: 'ccr');
    await insertTank('ccr', 'ccr-dil', 'diluent', volume: 3, end: 150);
    await insertTank(
      'ccr',
      'ccr-bail',
      'bailout',
      volume: 11,
      end: 150,
      order: 1,
    );
    await insertSwitch('ccr', 'ccr-bail', 40 * 60);

    final trend = await repository.getRoleConsumptionPerDive();

    expect(trend.rmv.keys, [ConsumptionRoleGroup.bailout]);
    expect(trend.rmv[ConsumptionRoleGroup.bailout]!.single.diveId, 'ccr');
  });

  test('Exclude from gas statistics leaves a dive out of every group, bailout '
      'included', () async {
    await insertDive('oc', excludedFromGasStats: true);
    await insertTank('oc', 'oc-back', 'backGas');
    await insertDive(
      'ccr',
      diveMode: 'ccr',
      day: 2,
      excludedFromGasStats: true,
    );
    await insertTank('ccr', 'ccr-dil', 'diluent', volume: 3, end: 150);
    await insertTank(
      'ccr',
      'ccr-bail',
      'bailout',
      volume: 11,
      end: 150,
      order: 1,
    );
    await insertSwitch('ccr', 'ccr-bail', 40 * 60);

    final trend = await repository.getRoleConsumptionPerDive();

    expect(trend.rmv, isEmpty);
    expect(trend.sac, isEmpty);
  });

  test("another diver's dives are left out", () async {
    for (final id in ['me', 'them']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(id),
              name: Value(id),
              medicalNotes: const Value(''),
              notes: const Value(''),
              isDefault: const Value(false),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    await insertDive('mine', diverId: 'me');
    await insertTank('mine', 'mine-back', 'backGas');
    await insertDive('theirs', diverId: 'them', day: 2);
    await insertTank('theirs', 'theirs-back', 'backGas');

    final trend = await repository.getRoleConsumptionPerDive(diverId: 'me');

    expect(trend.rmv[ConsumptionRoleGroup.bottomGas]!.map((p) => p.diveId), [
      'mine',
    ]);
  });

  test('a deco dive without switches counts in leftOutDives', () async {
    await insertDive('hand');
    await insertTank('hand', 'hand-back', 'backGas');
    await insertTank(
      'hand',
      'hand-deco',
      'deco',
      volume: 7,
      o2: 50,
      end: 140,
      order: 1,
    );

    final trend = await repository.getRoleConsumptionPerDive();

    expect(trend.leftOutDives, 1);
    expect(trend.rmv, isEmpty);
  });

  test('points come back in date order across both queries', () async {
    await insertDive('ccr', diveMode: 'ccr', day: 1);
    await insertTank('ccr', 'ccr-dil', 'diluent', volume: 3, end: 150);
    await insertTank(
      'ccr',
      'ccr-bail',
      'bailout',
      volume: 11,
      end: 150,
      order: 1,
    );
    await insertSwitch('ccr', 'ccr-bail', 40 * 60);
    await insertDive('oc', day: 2);
    await insertTank('oc', 'oc-bail', 'bailout', volume: 11, end: 150);

    final trend = await repository.getRoleConsumptionPerDive();

    expect(trend.rmv[ConsumptionRoleGroup.bailout]!.map((p) => p.diveId), [
      'ccr',
      'oc',
    ]);
  });

  test(
    'a consolidated dive counts only the primary source cylinders',
    () async {
      await insertDive('two');
      for (final (computer, primary) in [('c1', true), ('c2', false)]) {
        await db
            .into(db.diveComputers)
            .insert(
              DiveComputersCompanion(
                id: Value(computer),
                name: Value(computer),
                createdAt: const Value(0),
                updatedAt: const Value(0),
              ),
            );
        await db
            .into(db.diveDataSources)
            .insert(
              DiveDataSourcesCompanion(
                id: Value('src-$computer'),
                diveId: const Value('two'),
                computerId: Value(computer),
                isPrimary: Value(primary),
                importedAt: Value(DateTime.utc(2024)),
                createdAt: Value(DateTime.utc(2024)),
              ),
            );
      }
      await insertTank('two', 'back-c1', 'backGas', computerId: 'c1');
      await insertTank(
        'two',
        'back-c2',
        'backGas',
        end: 20,
        order: 1,
        computerId: 'c2',
      );
      final rows = await detailRows('two');
      final primary = rows.singleWhere((r) => r.tankId == 'back-c1');

      final trend = await repository.getRoleConsumptionPerDive();

      expect(
        trend.rmv[ConsumptionRoleGroup.bottomGas]!.single.value,
        closeTo(primary.rmv!, 1e-9),
      );
    },
  );
}

typedef CylinderSacRowsForTest = ({
  String tankId,
  double? rmv,
  double? sacRate,
});
