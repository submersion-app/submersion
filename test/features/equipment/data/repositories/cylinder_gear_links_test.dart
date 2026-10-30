import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/cylinder_gear_links.dart';

import '../../../../helpers/bound_variables.dart';
import '../../../../helpers/test_database.dart';

void main() {
  tearDown(tearDownTestDatabase);

  test('a bulk delete binds within SQLite\'s variable limit', () async {
    // Each chunk is bound twice, once per link column, so a chunk of 500
    // bound 1000 variables.
    final db = setUpLoggingTestDatabase();
    final ids = [for (var i = 0; i < 1200; i++) 'e$i'];
    final most = await maxBoundVariables(
      () => clearCylinderGearLinks(db, SyncRepository(), ids, now: 1),
    );
    expect(most, lessThanOrEqualTo(sqliteVariableLimit));
  });

  group('extra regulators (#3375)', () {
    late AppDatabase db;
    const t = 1000;

    setUp(() async {
      db = await setUpTestDatabase();
      for (final id in ['r1', 'r2', 'r3']) {
        await db
            .into(db.equipment)
            .insert(
              EquipmentCompanion.insert(
                id: id,
                name: id,
                type: 'regulator',
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'd1',
              diveDateTime: t,
              createdAt: t,
              updatedAt: t,
            ),
          );
    });

    Future<void> tank(String id, String? first, String? extras) => db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: id, diveId: 'd1').copyWith(
            regulatorEquipmentId: Value(first),
            extraRegulatorIds: Value(extras),
          ),
        );

    Future<(String?, String?, String?)> stored(String id) async {
      final row = await (db.select(
        db.diveTanks,
      )..where((r) => r.id.equals(id))).getSingle();
      return (row.regulatorEquipmentId, row.extraRegulatorIds, row.hlc);
    }

    Future<bool> pending(String id) async =>
        (await db
                .customSelect(
                  "SELECT 1 FROM sync_records WHERE entity_type = 'diveTanks' "
                  'AND record_id = ?',
                  variables: [Variable.withString(id)],
                )
                .get())
            .isNotEmpty;

    test('deleting an extra keeps the rest and stages the tank', () async {
      await tank('k1', 'r1', '["r2","r3"]');
      await clearCylinderGearLinks(db, SyncRepository(), ['r2'], now: 1);
      final (first, extras, hlc) = await stored('k1');
      expect(first, 'r1');
      expect(extras, '["r3"]');
      expect(hlc, isNotNull);
      expect(await pending('k1'), isTrue);
    });

    test('deleting the first moves the next one up', () async {
      await tank('k1', 'r1', '["r2","r3"]');
      await clearCylinderGearLinks(db, SyncRepository(), ['r1'], now: 1);
      final (first, extras, _) = await stored('k1');
      expect(first, 'r2');
      expect(extras, '["r3"]');
    });

    test('deleting every regulator leaves none', () async {
      await tank('k1', 'r1', '["r2"]');
      await clearCylinderGearLinks(db, SyncRepository(), ['r1', 'r2'], now: 1);
      final (first, extras, _) = await stored('k1');
      expect(first, isNull);
      expect(extras, isNull);
    });

    test('a tank naming none of the deleted ids is untouched', () async {
      await tank('k1', 'r1', '["r2"]');
      await clearCylinderGearLinks(db, SyncRepository(), ['r9'], now: 1);
      expect(await stored('k1'), ('r1', '["r2"]', null));
      expect(await pending('k1'), isFalse);
    });
  });
}
