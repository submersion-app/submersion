import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/role_consumption.dart';

import '../../../../helpers/test_database.dart';

/// An Avelo Hydrotank's pressure rises with the water pumped in for
/// buoyancy, so it is no measure of the gas used (issue #4657). The SQL
/// statistics agree with `Dive.sac` and `Dive.rmvFor`: the dive has no SAC,
/// in bar or litres, rather than a pony standing in for it, and its gas used
/// counts only the cylinders that measure it.
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

  /// A 45 minute dive at 12 m average depth.
  Future<void> insertDive(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            runtime: const Value(45 * 60),
            avgDepth: const Value(12.0),
            maxDepth: const Value(18.0),
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
    required double volume,
    required double end,
    int? usageSeconds,
  }) async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('$diveId-$order'),
            diveId: Value(diveId),
            startPressure: const Value(200),
            endPressure: Value(end),
            volume: Value(volume),
            tankRole: Value(role),
            o2Percent: const Value(21.0),
            hePercent: const Value(0.0),
            tankOrder: Value(order),
            usageDuration: Value(usageSeconds),
          ),
        );
  }

  Future<void> insertHydrotank(String diveId) =>
      insertTank(diveId, 0, 'hydrotank', volume: 10, end: 185);

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

  group('a Hydrotank and a pony', () {
    setUp(() async {
      await insertDive('h');
      await insertHydrotank('h');
      await insertTank(
        'h',
        1,
        'pony',
        volume: 3,
        end: 170,
        usageSeconds: 10 * 60,
      );
    });

    test('has no SAC in bar, as Dive.sac', () async {
      expect(await repository.getSacPressurePerDive(), isEmpty);
      expect((await repository.getSacPressureRecords()).best, isNull);
      expect(await queryLanguageSac('h'), isNull);
    });

    test('has no SAC in litres, as Dive.rmvFor', () async {
      expect(await repository.getSacVolumePerDive(), isEmpty);
      expect((await repository.getSacVolumeRecords()).best, isNull);
    });

    test('its gas used is the pony alone', () async {
      // The pony's 3 L from 200 to 170 bar is about 79 litres with the real
      // gas model (90 ideal). Counting the Hydrotank's 15 bar drop of 10 L as
      // well read about 209.
      final used = await repository.getGasUsedPerDive();
      expect(used.single.value, inInclusiveRange(70, 95));
    });

    test('the Hydrotank is in no role line', () async {
      final trend = await repository.getRoleConsumptionPerDive();
      expect(trend.rmv.keys, isNot(contains(ConsumptionRoleGroup.bottomGas)));
      expect(trend.sac.keys, isNot(contains(ConsumptionRoleGroup.bottomGas)));
    });
  });

  test('a dive whose only cylinder is the Hydrotank has no gas figures, but '
      'still counts by its gas', () async {
    await insertDive('only');
    await insertHydrotank('only');

    expect(await repository.getSacPressurePerDive(), isEmpty);
    expect(await repository.getSacVolumePerDive(), isEmpty);
    expect(await repository.getGasUsedPerDive(), isEmpty);
    expect(await queryLanguageSac('only'), isNull);
    expect((await repository.getGasMixDistribution()).map((r) => r.label), [
      'Air',
    ]);
  });

  test('back gas listed before the Hydrotank gives no SAC in bar', () async {
    // Back gas is the SQL reference then, as in Dive.sac.
    await insertDive('bh');
    await insertTank('bh', 0, 'backGas', volume: 10, end: 150);
    await insertTank('bh', 1, 'hydrotank', volume: 10, end: 185);

    expect(await repository.getSacPressurePerDive(), isEmpty);
    expect(await queryLanguageSac('bh'), isNull);
  });

  test('the same pressures on back gas still give a SAC', () async {
    await insertDive('b');
    await insertTank('b', 0, 'backGas', volume: 10, end: 185);

    expect(await repository.getSacPressurePerDive(), hasLength(1));
    expect(await queryLanguageSac('b'), isNotNull);
  });
}
