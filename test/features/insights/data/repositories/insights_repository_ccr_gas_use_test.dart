import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/ccr_gas_use_trend.dart';

import '../../../../helpers/test_database.dart';

/// O2 and diluent rates per CCR dive (issue #4082). Plain litres per minute of
/// loop time, drawn from the same calculation as the Cylinders card.
void main() {
  late InsightsRepository repository;
  late AppDatabase db;

  Future<void> insertDive(
    String id, {
    String diveMode = 'ccr',
    int day = 1,
    bool excludedFromGasStats = false,
    String? diverId,
    int? runtime = 42 * 60,
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
            avgDepth: const Value(20.0),
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
    double? start = 200,
    double? end = 74,
    double volume = 3,
    double o2 = 21,
    int order = 0,
    String? computerId,
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

  /// A diluent and an O2 supply, each losing 126 bar from 3 L: 378 L over 42
  /// minutes, so 9 L/min.
  Future<void> insertCcrDive(String id, {int day = 1}) async {
    await insertDive(id, day: day);
    await insertTank(id, '$id-dil', 'diluent');
    await insertTank(id, '$id-o2', 'oxygenSupply', o2: 100, order: 1);
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository(gasModel: GasModel.ideal);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('getCcrGasUsePerDive', () {
    test('a CCR dive gives one O2 and one diluent point', () async {
      await insertCcrDive('ccr');

      final trend = await repository.getCcrGasUsePerDive();

      expect(trend.o2.single.diveId, 'ccr');
      expect(trend.o2.single.value, closeTo(9, 1e-9));
      expect(trend.diluent.single.diveId, 'ccr');
      expect(trend.diluent.single.value, closeTo(9, 1e-9));
    });

    test('points run in date order', () async {
      await insertCcrDive('later', day: 5);
      await insertCcrDive('earlier', day: 2);

      final trend = await repository.getCcrGasUsePerDive();

      expect(trend.o2.map((p) => p.diveId), ['earlier', 'later']);
      expect(trend.o2.first.date, DateTime.utc(2026, 1, 2));
    });

    test('a Sidemount cylinder lands in Diluent', () async {
      await insertDive('ccr');
      await insertTank('ccr', 'left', 'sidemountLeft');
      await insertTank('ccr', 'o2', 'oxygenSupply', o2: 100, order: 1);

      final trend = await repository.getCcrGasUsePerDive();

      expect(trend.diluent.single.value, closeTo(9, 1e-9));
    });

    test('a pure O2 Sidemount cylinder lands in O2', () async {
      await insertDive('ccr');
      await insertTank('ccr', 'left', 'sidemountLeft', o2: 100);

      final trend = await repository.getCcrGasUsePerDive();

      expect(trend.o2.single.value, closeTo(9, 1e-9));
      expect(trend.diluent, isEmpty);
    });

    test('a dive ticked out of gas statistics stays out', () async {
      await insertDive('out', excludedFromGasStats: true);
      await insertTank('out', 'dil', 'diluent');

      expect((await repository.getCcrGasUsePerDive()).isEmpty, isTrue);
    });

    test('open-circuit, SCR and gauge dives stay out', () async {
      for (final mode in ['oc', 'scr', 'gauge']) {
        await insertDive(mode, diveMode: mode);
        await insertTank(mode, '$mode-dil', 'diluent');
      }

      expect((await repository.getCcrGasUsePerDive()).isEmpty, isTrue);
    });

    test('the view filter applies', () async {
      await insertCcrDive('early', day: 1);
      await insertCcrDive('late', day: 20);

      final trend = await repository.getCcrGasUsePerDive(
        filter: DiveFilterState(startDate: DateTime(2026, 1, 10)),
      );

      expect(trend.o2.map((p) => p.diveId), ['late']);
    });

    test('the diver filter applies', () async {
      await db
          .into(db.divers)
          .insert(
            const DiversCompanion(
              id: Value('a'),
              name: Value('A'),
              medicalNotes: Value(''),
              notes: Value(''),
              isDefault: Value(false),
              createdAt: Value(0),
              updatedAt: Value(0),
            ),
          );
      await insertDive('mine', diverId: 'a');
      await insertTank('mine', 'mine-dil', 'diluent');
      await insertCcrDive('other');

      final trend = await repository.getCcrGasUsePerDive(diverId: 'a');

      expect(trend.diluent.map((p) => p.diveId), ['mine']);
    });

    test('no CCR dives gives an empty trend', () async {
      expect((await repository.getCcrGasUsePerDive()).isEmpty, isTrue);
    });

    test('a dive with a bailout uses its series for loop time', () async {
      await insertCcrDive('ccr');
      await insertTank('ccr', 'bail', 'bailout', start: 200, end: 200);
      // 21 of the 42 minutes on the loop.
      await insertSwitch('ccr', 'bail', 21 * 60);
      await TankPressureRepository().insertTankPressures('ccr', {
        'ccr-o2': [
          (timestamp: 0, pressure: 200),
          (timestamp: 21 * 60, pressure: 158),
          (timestamp: 42 * 60, pressure: 74),
        ],
      });

      final trend = await repository.getCcrGasUsePerDive();

      expect(trend.o2.single.value, closeTo(42 * 3 / 21, 1e-9));
    });

    test('a two-source dive uses the primary series', () async {
      await insertDive('ccr');
      await insertTank('ccr', 'dil', 'diluent', start: null, end: null);
      final now = DateTime.fromMillisecondsSinceEpoch(0);
      for (final (id, primary) in [('src-a', false), ('src-b', true)]) {
        await db
            .into(db.diveDataSources)
            .insert(
              DiveDataSourcesCompanion.insert(
                id: id,
                diveId: 'ccr',
                isPrimary: Value(primary),
                importedAt: now,
                createdAt: now,
              ),
            );
      }
      final pressures = TankPressureRepository();
      await pressures.insertTankPressures('ccr', {
        'dil': [
          (timestamp: 0, pressure: 200),
          (timestamp: 42 * 60, pressure: 100),
        ],
      }, sourceId: 'src-a');
      await pressures.insertTankPressures('ccr', {
        'dil': [
          (timestamp: 0, pressure: 200),
          (timestamp: 42 * 60, pressure: 158),
        ],
      }, sourceId: 'src-b');

      final trend = await repository.getCcrGasUsePerDive();

      expect(trend.diluent.single.value, closeTo(42 * 3 / 42, 1e-9));
    });

    test('a two-computer dive counts one copy of each cylinder', () async {
      await insertDive('ccr');
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
                diveId: const Value('ccr'),
                computerId: Value(computer),
                isPrimary: Value(primary),
                importedAt: Value(DateTime.utc(2024)),
                createdAt: Value(DateTime.utc(2024)),
              ),
            );
        await insertTank(
          'ccr',
          'o2-$computer',
          'oxygenSupply',
          o2: 100,
          computerId: computer,
        );
      }

      final trend = await repository.getCcrGasUsePerDive();

      expect(trend.o2.single.value, closeTo(9, 1e-9));
    });

    test(
      'a bailout logged by the other computer still ends the loop',
      () async {
        await insertDive('ccr');
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
                  diveId: const Value('ccr'),
                  computerId: Value(computer),
                  isPrimary: Value(primary),
                  importedAt: Value(DateTime.utc(2024)),
                  createdAt: Value(DateTime.utc(2024)),
                ),
              );
        }
        await insertTank(
          'ccr',
          'o2-c1',
          'oxygenSupply',
          o2: 100,
          computerId: 'c1',
        );
        await insertTank(
          'ccr',
          'bail-c2',
          'bailout',
          start: 200,
          end: 200,
          order: 1,
          computerId: 'c2',
        );
        await insertSwitch('ccr', 'bail-c2', 21 * 60);

        final dives = DiveRepository();
        final dive = (await dives.getDiveById('ccr'))!;
        final rows = const GasAnalysisService(gasModel: GasModel.ideal)
            .calculateCylinderSac(
              dive: dive,
              profile: dive.profile,
              gasSwitches: await dives.getGasSwitchesForDive('ccr'),
            );
        final trend = await repository.getCcrGasUsePerDive();

        final o2 = rows.singleWhere((r) => r.role == TankRole.oxygenSupply);
        expect(o2.loopRate, closeTo(378 / 21, 1e-9));
        expect(trend.o2.single.value, closeTo(o2.loopRate!, 1e-9));
      },
    );

    test('a dive with no runtime takes its end from the profile', () async {
      await insertDive('ccr', runtime: null);
      await insertTank('ccr', 'dil', 'diluent');
      await ProfileSeriesRepository().insertSeries(
        diveId: 'ccr',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0),
          ProfileSample(timestamp: 42 * 60, depth: 0),
        ],
        now: 0,
      );

      final trend = await repository.getCcrGasUsePerDive();

      expect(trend.diluent.single.value, closeTo(9, 1e-9));
    });

    test('a single-sample profile still gives the card\'s dive end', () async {
      await insertDive('ccr', runtime: null);
      await insertTank('ccr', 'dil', 'diluent');
      await ProfileSeriesRepository().insertSeries(
        diveId: 'ccr',
        samples: const [ProfileSample(timestamp: 42 * 60, depth: 20)],
        now: 0,
      );

      final trend = await repository.getCcrGasUsePerDive();

      expect(trend.diluent.single.value, closeTo(9, 1e-9));
    });

    test('one dive reads the same here as on the card', () async {
      await insertCcrDive('ccr');
      await insertTank('ccr', 'bail', 'bailout', start: 200, end: 120);
      await insertSwitch('ccr', 'bail', 30 * 60);
      await TankPressureRepository().insertTankPressures('ccr', {
        'ccr-dil': [
          (timestamp: 0, pressure: 200),
          (timestamp: 30 * 60, pressure: 150),
          (timestamp: 42 * 60, pressure: 140),
        ],
      });

      final dives = DiveRepository();
      final dive = (await dives.getDiveById('ccr'))!;
      final rows = const GasAnalysisService(gasModel: GasModel.ideal)
          .calculateCylinderSac(
            dive: dive,
            profile: dive.profile,
            gasSwitches: await dives.getGasSwitchesForDive('ccr'),
            tankPressures: await TankPressureRepository()
                .getTankPressuresForDive('ccr'),
          );

      final trend = await repository.getCcrGasUsePerDive();

      final o2 = rows.singleWhere((r) => r.role == TankRole.oxygenSupply);
      final dil = rows.singleWhere((r) => r.role == TankRole.diluent);
      expect(o2.loopRate, isNotNull);
      expect(trend.o2.single.value, closeTo(o2.loopRate!, 1e-9));
      expect(trend.diluent.single.value, closeTo(dil.loopRate!, 1e-9));
    });
  });

  group('CcrGasUseTrend', () {
    test('averages are the mean of the per-dive rates', () async {
      await insertCcrDive('a', day: 1);
      await insertDive('b', day: 2);
      await insertTank('b', 'b-o2', 'oxygenSupply', end: 158, o2: 100);

      final trend = await repository.getCcrGasUsePerDive();

      expect(trend.o2Average, closeTo((9 + 3) / 2, 1e-9));
      expect(trend.diluentAverage, closeTo(9, 1e-9));
    });

    test('an empty line has no average', () {
      const trend = CcrGasUseTrend(o2: [], diluent: []);
      expect(trend.isEmpty, isTrue);
      expect(trend.o2Average, isNull);
      expect(trend.diluentAverage, isNull);
    });
  });
}
