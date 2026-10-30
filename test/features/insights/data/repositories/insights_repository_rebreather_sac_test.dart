import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3673: a rebreather's cylinders do not drain with the diver's
/// breathing, so a CCR or SCR dive leaves the SAC and RMV averages, trends
/// and records, the way a gauge dive does. Its gas data still counts where
/// it is meaningful: the gas mixes, the litres drawn, and the breakdown by
/// cylinder role.
///
/// The fixture seeds three dives, identical apart from the dive mode, each
/// with a diluent (or back gas) cylinder and an oxygen cylinder.
void main() {
  late InsightsRepository repository;
  late AppDatabase db;

  Future<void> insertDive(String id, String diveMode, int day) async {
    final at = DateTime.utc(2026, 1, day).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(at),
            diveMode: Value(diveMode),
            runtime: const Value(42 * 60),
            avgDepth: const Value(20.0),
            maxDepth: const Value(25.0),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
    final firstRole = diveMode == 'oc' ? 'backGas' : 'diluent';
    for (final (order, role, o2) in [
      (0, firstRole, 21.0),
      (1, 'oxygenSupply', 100.0),
    ]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value('$id-$order'),
              diveId: Value(id),
              startPressure: const Value(200.0),
              endPressure: const Value(74.0),
              volume: const Value(3.0),
              tankRole: Value(role),
              o2Percent: Value(o2),
              hePercent: const Value(0.0),
              tankOrder: Value(order),
            ),
          );
    }
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
    await insertDive('oc', 'oc', 1);
    await insertDive('ccr', 'ccr', 2);
    await insertDive('scr', 'scr', 3);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('SAC and RMV aggregates leave rebreather dives out', () {
    test('getSacPressurePerDive', () async {
      final points = await repository.getSacPressurePerDive();
      expect(points.map((p) => p.diveId), ['oc']);
    });

    test('getSacVolumePerDive', () async {
      final points = await repository.getSacVolumePerDive();
      expect(points.map((p) => p.diveId), ['oc']);
    });

    test('getSacPressureRecords', () async {
      final records = await repository.getSacPressureRecords();
      expect(records.best?.id, 'oc');
      expect(records.worst?.id, anyOf(isNull, 'oc'));
    });

    test('getSacVolumeRecords', () async {
      final records = await repository.getSacVolumeRecords();
      expect(records.best?.id, 'oc');
      expect(records.worst?.id, anyOf(isNull, 'oc'));
    });
  });

  group('gas aggregates that are not a rate keep rebreather dives', () {
    test('getGasMixDistribution counts every dive', () async {
      final dist = await repository.getGasMixDistribution();
      final total = dist.fold<int>(0, (sum, s) => sum + s.count);
      // Air and oxygen on each of the three dives.
      expect(total, 6);
    });

    test('getGasUsedPerDive keeps the litres drawn on a loop', () async {
      final points = await repository.getGasUsedPerDive();
      expect(points.map((p) => p.diveId), ['oc', 'ccr', 'scr']);
    });

    test('getSacPressureByTankRole keeps the diluent cylinders', () async {
      final byRole = await repository.getSacPressureByTankRole();
      expect(byRole.keys, containsAll(['backGas', 'diluent', 'oxygenSupply']));
    });

    test('getSacVolumeByTankRole keeps the diluent cylinders', () async {
      final byRole = await repository.getSacVolumeByTankRole();
      expect(byRole.keys, containsAll(['backGas', 'diluent', 'oxygenSupply']));
    });
  });
}
