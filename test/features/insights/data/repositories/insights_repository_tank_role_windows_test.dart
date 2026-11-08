import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// SAC by tank role over each cylinder's own breathing time (issue #4315).
/// A dive's gas switches say when each cylinder was breathed, and the role
/// rates must use those windows, as the dive's Cylinders card does, rather
/// than spreading every cylinder's gas over the whole dive.
void main() {
  late AppDatabase db;

  Future<void> insertDive(
    String id, {
    int runtime = 60 * 60,
    double avgDepth = 6,
    int day = 1,
    String? diverId,
  }) async {
    final at = DateTime.utc(2026, 10, day).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(at),
            diveMode: const Value('oc'),
            runtime: Value(runtime),
            avgDepth: Value(avgDepth),
            maxDepth: Value(avgDepth),
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
    double end = 120,
    double? volume = 12,
    double o2 = 21,
    int order = 0,
    int? usageSeconds,
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
          usageDuration: Value(usageSeconds),
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

  /// Samples every 10 seconds to [end], at [depthAt] each timestamp.
  Future<void> insertProfile(
    String diveId, {
    int end = 60 * 60,
    double Function(int t)? depthAt,
  }) => ProfileSeriesRepository().insertSeries(
    diveId: diveId,
    samples: [
      for (var t = 0; t <= end; t += 10)
        ProfileSample(timestamp: t, depth: depthAt?.call(t) ?? 6),
    ],
    now: 0,
  );

  /// The issue's fixture: a 60 minute dive at a flat 6 m, back gas (12 L
  /// air) for the first half and a stage (12 L EAN50) for the second, each
  /// falling from 200 to 120 bar. Each gave 960 L in 30 minutes at 1.6 bar:
  /// 20 L/min, or 5/3 bar/min.
  Future<void> insertSwitchedDive(
    String id, {
    int day = 1,
    String? diverId,
  }) async {
    await insertDive(id, day: day, diverId: diverId);
    await insertTank(id, '$id-back', 'backGas');
    await insertTank(id, '$id-stage', 'stage', o2: 50, order: 1);
    await insertSwitch(id, '$id-back', 0);
    await insertSwitch(id, '$id-stage', 1800);
    await insertProfile(id);
  }

  /// The dive's Cylinders card figures for [diveId], from the same rows.
  Future<List<CylinderSac>> cylinderCard(String diveId, GasModel model) async {
    final dives = DiveRepository();
    final dive = (await dives.getDiveById(diveId))!;
    return GasAnalysisService(gasModel: model).calculateCylinderSac(
      dive: dive,
      profile: dive.profile,
      gasSwitches: await dives.getGasSwitchesForDive(diveId),
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('a dive with recorded gas switches', () {
    test('rates each cylinder over its own half of the dive', () async {
      await insertSwitchedDive('switched');
      final repository = InsightsRepository(gasModel: GasModel.ideal);

      final volume = await repository.getSacVolumeByTankRole();
      final pressure = await repository.getSacPressureByTankRole();

      expect(volume['backGas'], closeTo(20, 1e-9));
      expect(volume['stage'], closeTo(20, 1e-9));
      expect(pressure['backGas'], closeTo(5 / 3, 1e-9));
      expect(pressure['stage'], closeTo(5 / 3, 1e-9));
    });

    test('agrees with the Cylinders card under either gas model', () async {
      // A deep first half on back gas and a shallow second half on the
      // stage, so each cylinder's own depth matters as well as its time.
      await insertDive('deep', avgDepth: 18);
      await insertTank('deep', 'deep-back', 'backGas', end: 60);
      await insertTank('deep', 'deep-stage', 'stage', o2: 50, order: 1);
      await insertSwitch('deep', 'deep-back', 0);
      await insertSwitch('deep', 'deep-stage', 1800);
      await insertProfile('deep', depthAt: (t) => t < 1800 ? 30 : 6);

      for (final model in GasModel.values) {
        final cylinders = await cylinderCard('deep', model);
        final volume = await InsightsRepository(
          gasModel: model,
        ).getSacVolumeByTankRole();
        final pressure = await InsightsRepository(
          gasModel: model,
        ).getSacPressureByTankRole();

        expect(cylinders, hasLength(2));
        for (final cylinder in cylinders) {
          final role = cylinder.role.name;
          expect(volume[role], closeTo(cylinder.rmv!, 1e-9), reason: role);
          // The pressure lane is the raw drop per minute; only under the
          // ideal model is that the card's own bar/min figure.
          if (model == GasModel.ideal) {
            expect(
              pressure[role],
              closeTo(cylinder.sacRate!, 1e-9),
              reason: role,
            );
          }
        }
      }
      // The stage was breathed at 6 m, the back gas at 30 m: the depths
      // must differ for this test to say anything about depth.
      final cylinders = await cylinderCard('deep', GasModel.ideal);
      expect(cylinders.first.avgDepthDuringUse, greaterThan(25));
      expect(cylinders.last.avgDepthDuringUse, lessThan(8));
    });

    test('a cylinder the switches never name is left out', () async {
      await insertSwitchedDive('switched');
      await insertTank('switched', 'switched-deco', 'deco', o2: 100, order: 2);

      final volume = await InsightsRepository(
        gasModel: GasModel.ideal,
      ).getSacVolumeByTankRole();

      expect(volume.keys, unorderedEquals(['backGas', 'stage']));
    });

    test('a returning cylinder counts both of its stints', () async {
      await insertDive('back-again');
      await insertTank('back-again', 'ba-back', 'backGas', end: 40);
      await insertTank('back-again', 'ba-stage', 'stage', o2: 50, order: 1);
      await insertSwitch('back-again', 'ba-back', 0);
      await insertSwitch('back-again', 'ba-stage', 1200);
      await insertSwitch('back-again', 'ba-back', 2400);
      await insertProfile('back-again');

      final volume = await InsightsRepository(
        gasModel: GasModel.ideal,
      ).getSacVolumeByTankRole();

      // Back gas: 1920 L over 40 minutes; stage: 960 L over 20 minutes.
      expect(volume['backGas'], closeTo(1920 / 40 / 1.6, 1e-9));
      expect(volume['stage'], closeTo(960 / 20 / 1.6, 1e-9));
    });

    test('a profileless dive falls back to its average depth', () async {
      await insertDive('no-profile');
      await insertTank('no-profile', 'np-back', 'backGas');
      await insertTank('no-profile', 'np-stage', 'stage', o2: 50, order: 1);
      await insertSwitch('no-profile', 'np-back', 0);
      await insertSwitch('no-profile', 'np-stage', 1800);

      final volume = await InsightsRepository(
        gasModel: GasModel.ideal,
      ).getSacVolumeByTankRole();

      expect(volume['backGas'], closeTo(20, 1e-9));
      expect(volume['stage'], closeTo(20, 1e-9));
    });

    test('a dive with no stored average depth reads its profile', () async {
      await insertSwitchedDive('no-avg');
      await db.customStatement(
        "UPDATE dives SET avg_depth = NULL WHERE id = 'no-avg'",
      );
      // A single-cylinder switched dive with no average has no depth.
      await insertDive('single-no-avg', day: 2);
      await insertTank('single-no-avg', 'sna-back', 'backGas', end: 40);
      await insertSwitch('single-no-avg', 'sna-back', 0);
      await db.customStatement(
        "UPDATE dives SET avg_depth = NULL WHERE id = 'single-no-avg'",
      );

      final volume = await InsightsRepository(
        gasModel: GasModel.ideal,
      ).getSacVolumeByTankRole();

      expect(volume['backGas'], closeTo(20, 1e-9));
      expect(volume['stage'], closeTo(20, 1e-9));
    });

    test('dives across a chunk boundary are all counted', () async {
      addTearDown(
        () => InsightsRepository.seriesDiveChunkSize =
            InsightsRepository.defaultSeriesDiveChunkSize,
      );
      InsightsRepository.seriesDiveChunkSize = 1;
      await insertSwitchedDive('a', day: 1);
      await insertSwitchedDive('b', day: 2);
      await insertSwitchedDive('c', day: 3);

      final volume = await InsightsRepository(
        gasModel: GasModel.ideal,
      ).getSacVolumeByTankRole();

      expect(volume['backGas'], closeTo(20, 1e-9));
      expect(volume['stage'], closeTo(20, 1e-9));
    });

    test('the view filter still applies', () async {
      await insertSwitchedDive('early', day: 1);
      // A later dive at 10 L/min, which would pull the average down.
      await insertDive('late', day: 20);
      await insertTank('late', 'late-back', 'backGas');

      final volume = await InsightsRepository(gasModel: GasModel.ideal)
          .getSacVolumeByTankRole(
            filter: DiveFilterState(endDate: DateTime(2026, 10, 10)),
          );

      expect(volume['backGas'], closeTo(20, 1e-9));
      expect(volume['stage'], closeTo(20, 1e-9));
    });

    test('roles fold together through roleKey', () async {
      await insertSwitchedDive('switched');

      final volume = await InsightsRepository(
        gasModel: GasModel.ideal,
      ).getSacVolumeByTankRole(roleKey: (_) => 'all');

      expect(volume, {'all': closeTo(20, 1e-9)});
    });

    test('a switch after the dive ended says nothing', () async {
      await insertDive('late-switch');
      await insertTank('late-switch', 'ls-back', 'backGas');
      await insertTank('late-switch', 'ls-stage', 'stage', o2: 50, order: 1);
      await insertSwitch('late-switch', 'ls-stage', 4000);
      await insertProfile('late-switch');

      final volume = await InsightsRepository(
        gasModel: GasModel.ideal,
      ).getSacVolumeByTankRole();

      // Unchanged from before: with no usable switch each is spread over
      // the whole dive.
      expect(volume['backGas'], closeTo(10, 1e-9));
      expect(volume['stage'], closeTo(10, 1e-9));
    });
  });

  group('a dive without switches', () {
    test('a single cylinder is rated over the whole dive', () async {
      await insertDive('single');
      await insertTank('single', 'single-back', 'backGas', end: 40);
      await insertSwitch('single', 'single-back', 0);
      await insertProfile('single');

      final volume = await InsightsRepository(
        gasModel: GasModel.ideal,
      ).getSacVolumeByTankRole();

      expect(volume['backGas'], closeTo(20, 1e-9));
    });

    test('a recorded per-cylinder duration is its breathing time', () async {
      // An import that says how long each cylinder was breathed but not
      // when (issue #1496): the Cylinders card divides by that duration.
      await insertDive('recorded');
      await insertTank('recorded', 'r-back', 'backGas', usageSeconds: 1800);
      await insertTank(
        'recorded',
        'r-stage',
        'stage',
        o2: 50,
        order: 1,
        usageSeconds: 1800,
      );
      await insertProfile('recorded');

      final repository = InsightsRepository(gasModel: GasModel.ideal);
      final volume = await repository.getSacVolumeByTankRole();
      final pressure = await repository.getSacPressureByTankRole();

      expect(volume['backGas'], closeTo(20, 1e-9));
      expect(volume['stage'], closeTo(20, 1e-9));
      expect(pressure['stage'], closeTo(5 / 3, 1e-9));
    });

    test('a recorded duration counts on a dive with no runtime', () async {
      // An import with per-cylinder durations but no runtime or profile:
      // the Cylinders card still rates the cylinder over its own duration.
      await insertDive('no-runtime');
      await db.customStatement(
        "UPDATE dives SET runtime = NULL WHERE id = 'no-runtime'",
      );
      await insertTank('no-runtime', 'nr-back', 'backGas', usageSeconds: 1800);
      // Nothing says how long this one was breathed.
      await insertTank('no-runtime', 'nr-stage', 'stage', o2: 50, order: 1);

      final volume = await InsightsRepository(
        gasModel: GasModel.ideal,
      ).getSacVolumeByTankRole();

      expect(volume, {'backGas': closeTo(20, 1e-9)});
      final card = await cylinderCard('no-runtime', GasModel.ideal);
      expect(card.single.rmv, closeTo(20, 1e-9));
    });

    test('switches win over a recorded duration', () async {
      await insertSwitchedDive('both');
      // A recorded duration that disagrees with the switches.
      await db.customStatement(
        "UPDATE dive_tanks SET usage_duration = 600 WHERE dive_id = 'both'",
      );

      final volume = await InsightsRepository(
        gasModel: GasModel.ideal,
      ).getSacVolumeByTankRole();

      expect(volume['backGas'], closeTo(20, 1e-9));
      expect(volume['stage'], closeTo(20, 1e-9));
    });

    test('an unswitched stage keeps its whole-dive figure', () async {
      await insertDive('unswitched');
      await insertTank('unswitched', 'u-back', 'backGas');
      await insertTank('unswitched', 'u-stage', 'stage', o2: 50, order: 1);
      await insertProfile('unswitched');

      final volume = await InsightsRepository(
        gasModel: GasModel.ideal,
      ).getSacVolumeByTankRole();

      expect(volume['backGas'], closeTo(10, 1e-9));
      expect(volume['stage'], closeTo(10, 1e-9));
    });
  });
}
