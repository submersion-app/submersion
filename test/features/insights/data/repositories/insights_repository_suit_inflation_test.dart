import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// A suit inflation bottle is not breathing gas (issue #4243): the
/// statistics read a dive as if it were not carried.
void main() {
  late InsightsRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// A 42 minute dive at 20 m average depth: 3 bar ambient, so a 126 bar
  /// drop is 1.0 bar/min at the surface.
  Future<void> insertDive(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            runtime: const Value(42 * 60),
            avgDepth: const Value(20.0),
            maxDepth: const Value(25.0),
            diveMode: const Value('oc'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertTank(
    String diveId,
    int order,
    String role, {
    double? volume = 11.1,
    double start = 200,
    double end = 74,
    double o2 = 21.0,
    int? usageSeconds,
  }) async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('$diveId-$order'),
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
  }

  /// The argon bottle every dive below carries first: air in the database,
  /// as an import writes it, sized and dropping.
  Future<void> insertSuit(String diveId) =>
      insertTank(diveId, 0, 'suitInflation', volume: 0.85, end: 120);

  Future<double?> queryLanguageSac(String diveId) async {
    final row = await db
        .customSelect(
          'SELECT ${kDiveSacSql.replaceAll('{r}', 'd')} AS sac '
          'FROM dives d WHERE d.id = ?',
          variables: [Variable(diveId)],
        )
        .getSingle();
    return row.read<double?>('sac');
  }

  test('SAC in pressure is the sidemount pair alone', () async {
    await insertDive('sm');
    await insertSuit('sm');
    await insertTank('sm', 1, 'sidemountLeft', volume: null, o2: 32);
    await insertTank('sm', 2, 'sidemountRight', volume: null, end: 137, o2: 32);

    // (126 + 63) bar / 42 min / 3 bar = 1.5 bar/min
    final trend = await repository.getSacPressurePerDive();
    expect(trend.single.value, closeTo(1.5, 1e-9));
    final records = await repository.getSacPressureRecords();
    expect(records.best!.value, closeTo(1.5, 1e-9));
    expect(await queryLanguageSac('sm'), closeTo(1.5, 1e-9));
  });

  test('SAC in volume and gas used leave the bottle out', () async {
    await insertDive('bg');
    await insertSuit('bg');
    await insertTank('bg', 1, 'backGas', o2: 32);
    final withSuit = await repository.getSacVolumePerDive();
    final usedWithSuit = await repository.getGasUsedPerDive();
    final recordsWithSuit = await repository.getSacVolumeRecords();

    await (db.delete(db.diveTanks)..where((t) => t.id.equals('bg-0'))).go();

    expect(
      withSuit.single.value,
      closeTo((await repository.getSacVolumePerDive()).single.value, 1e-9),
    );
    expect(
      usedWithSuit.single.value,
      closeTo((await repository.getGasUsedPerDive()).single.value, 1e-9),
    );
    expect(
      recordsWithSuit.best!.value,
      closeTo((await repository.getSacVolumeRecords()).best!.value!, 1e-9),
    );
  });

  test('SAC by role has no suit inflation bucket', () async {
    await insertDive('r');
    await insertSuit('r');
    await insertTank('r', 1, 'backGas', o2: 32);

    expect(
      (await repository.getSacPressureByTankRole()).keys,
      isNot(contains('suitInflation')),
    );
    expect(
      (await repository.getSacVolumeByTankRole()).keys,
      isNot(contains('suitInflation')),
    );
  });

  test('an air argon bottle does not make a nitrox dive an air dive', () async {
    await insertDive('nx');
    await insertSuit('nx');
    await insertTank('nx', 1, 'backGas', o2: 32);

    final rows = await repository.getGasMixDistribution();

    expect(rows.map((r) => r.label), ['Nitrox']);
    expect(await repository.getGasMixDiveIds(gasType: 'Air'), isEmpty);
  });

  test('a dive whose only cylinder is the bottle has no gas figures', () async {
    await insertDive('only');
    await insertSuit('only');

    expect(await repository.getSacPressurePerDive(), isEmpty);
    expect(await repository.getSacVolumePerDive(), isEmpty);
    expect(await repository.getGasUsedPerDive(), isEmpty);
    expect(await repository.getGasMixDistribution(), isEmpty);
    expect(await queryLanguageSac('only'), isNull);
  });

  test(
    'a switch onto the bottle does not hide a recorded breathing time',
    () async {
      // The argon bottle is air and no breathing cylinder is, so the Cylinders
      // card drops the switch, and the 30 minutes the log recorded for the back
      // gas stand. Read as logged, the switch would say when the back gas was
      // breathed and the recorded time would be ignored for the whole dive.
      await insertDive('sw');
      await insertSuit('sw');
      await insertTank('sw', 1, 'backGas', o2: 32, usageSeconds: 30 * 60);
      await db
          .into(db.gasSwitches)
          .insert(
            const GasSwitchesCompanion(
              id: Value('sw-switch'),
              diveId: Value('sw'),
              tankId: Value('sw-0'),
              timestamp: Value(10 * 60),
              createdAt: Value(0),
            ),
          );

      final byRole = await repository.getSacPressureByTankRole();

      expect(byRole.keys, ['backGas']);
      // 126 bar / 30 min / about 3 bar at 20 m; the whole dive would be 1.0.
      expect(byRole['backGas'], closeTo(1.4, 0.05));
    },
  );
}
