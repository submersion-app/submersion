import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/gas_use_window.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #2930: the statistics divide a dive's consumption by its gas-use
/// window, the time underwater with surface runs at the ends left out, so
/// they agree with what `Dive.sac` shows.
void main() {
  late InsightsRepository repository;
  late AppDatabase db;

  // 100 bar of a 12 L cylinder over a 50 min recording at an average of
  // 15 m, 40 min of it underwater at an average of 18 m.
  const dropBar = 100.0;
  const runtimeMinutes = 50;
  const recordedAvgDepth = 15.0;
  const windowMinutes = 40;
  const windowAvgDepth = 18.0;
  const volume = 12.0;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository(gasModel: GasModel.ideal);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive({int? cachedWindowMinutes}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(now),
            runtime: const Value(runtimeMinutes * 60),
            avgDepth: const Value(recordedAvgDepth),
            maxDepth: const Value(25),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          const DiveTanksCompanion(
            id: Value('t1'),
            diveId: Value('d1'),
            startPressure: Value(200),
            endPressure: Value(200 - dropBar),
            volume: Value(volume),
            tankRole: Value('backGas'),
            o2Percent: Value(21.0),
            hePercent: Value(0.0),
            tankOrder: Value(0),
          ),
        );
    if (cachedWindowMinutes != null) {
      await db
          .into(db.diveDerivedMetricsRows)
          .insert(
            DiveDerivedMetricsRowsCompanion(
              diveId: const Value('d1'),
              engineVersion: const Value(4),
              sourceUpdatedAt: const Value(0),
              computedAt: const Value(0),
              gasUseS: Value(cachedWindowMinutes * 60),
              gasUseAvgDepthM: const Value(windowAvgDepth),
            ),
          );
    }
  }

  domain.Dive entity({GasUse? storedGasUse}) => domain.Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026),
    runtime: const Duration(minutes: runtimeMinutes),
    avgDepth: recordedAvgDepth,
    tanks: const [
      domain.DiveTank(
        id: 't1',
        volume: volume,
        startPressure: 200,
        endPressure: 200 - dropBar,
      ),
    ],
    storedGasUse: storedGasUse,
  );

  group('a dive with a stored window', () {
    final expectedSac =
        dropBar / windowMinutes / entity().environment.pressureAtDepth(18);
    final expectedRmv =
        dropBar *
        volume /
        windowMinutes /
        entity().environment.pressureAtDepth(18);

    setUp(() => insertDive(cachedWindowMinutes: windowMinutes));

    test('the pressure trend and records divide by the window', () async {
      final points = await repository.getSacPressurePerDive();
      expect(points.single.value, closeTo(expectedSac, 1e-9));
      final records = await repository.getSacPressureRecords();
      expect(records.best!.value, closeTo(expectedSac, 1e-9));
    });

    test('the volume trend and records divide by the window', () async {
      final points = await repository.getSacVolumePerDive();
      expect(points.single.value, closeTo(expectedRmv, 1e-9));
      final records = await repository.getSacVolumeRecords();
      expect(records.best!.value, closeTo(expectedRmv, 1e-9));
    });

    test('the by-role breakdowns divide by the window', () async {
      final pressure = await repository.getSacPressureByTankRole();
      expect(pressure['backGas'], closeTo(expectedSac, 1e-9));
      final volumeByRole = await repository.getSacVolumeByTankRole();
      expect(volumeByRole['backGas'], closeTo(expectedRmv, 1e-9));
    });

    test('the chart agrees with Dive.sac given the same window', () async {
      final points = await repository.getSacPressurePerDive();
      final sac = entity(
        storedGasUse: const GasUse(
          seconds: windowMinutes * 60,
          avgDepth: windowAvgDepth,
        ),
      ).sac!;
      expect(points.single.value, closeTo(sac, 1e-9));
    });
  });

  test('a dive with no stored window keeps the runtime and depth', () async {
    await insertDive();
    final points = await repository.getSacPressurePerDive();
    expect(
      points.single.value,
      closeTo(
        dropBar /
            runtimeMinutes /
            entity().environment.pressureAtDepth(recordedAvgDepth),
        1e-9,
      ),
    );
    expect(points.single.value, closeTo(entity().sac!, 1e-9));
  });

  test('a stored window longer than the runtime uses the runtime', () async {
    await insertDive(cachedWindowMinutes: runtimeMinutes + 10);
    final points = await repository.getSacPressurePerDive();
    expect(
      points.single.value,
      closeTo(
        dropBar /
            runtimeMinutes /
            entity().environment.pressureAtDepth(windowAvgDepth),
        1e-9,
      ),
    );
  });
}
