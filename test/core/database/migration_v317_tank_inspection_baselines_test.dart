import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v317 (issue #3662): a tank saved before the fix kept its last
/// visual inspection and last hydro dates only as attributes, and its VIP
/// and hydro clocks counted from the purchase date. The rung copies each
/// date onto its clock as the baseline, where the clock has none and no
/// service of the kind is logged.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
  });
  tearDown(() => db.close());

  const vipMs = 1790000000000;
  const hydroMs = 1780000000000;
  const attrSavedAt = 1795000000000;

  Future<void> insertTank(String id, {String type = 'tank'}) async {
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, purchase_date, created_at, '
      'updated_at) VALUES (?, ?, ?, ?, ?, ?)',
      [id, 'Tank $id', type, 949000000000, 1000, 2000],
    );
  }

  Future<void> insertDate(
    String equipmentId,
    String key,
    int ms, {
    bool isCustom = false,
  }) async {
    await db.customStatement(
      'INSERT INTO equipment_attributes (id, equipment_id, attr_key, '
      'is_custom, value_num, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        isCustom ? 'custom-$equipmentId-$key' : 'attr_${equipmentId}_$key',
        equipmentId,
        key,
        isCustom ? 1 : 0,
        ms.toDouble(),
        attrSavedAt,
        attrSavedAt,
      ],
    );
  }

  Future<void> insertClock(
    String equipmentId,
    String kindId, {
    int? anchorDate,
  }) async {
    await db.customStatement(
      'INSERT INTO service_schedules (id, equipment_id, service_kind_id, '
      'anchor_date, enabled, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, 1, ?, ?)',
      [
        'auto-$kindId-$equipmentId',
        equipmentId,
        kindId,
        anchorDate,
        1000,
        2000,
      ],
    );
  }

  Future<void> insertRecord(String equipmentId, String kindId) async {
    await db.customStatement(
      'INSERT INTO service_records (id, equipment_id, service_category, '
      'service_kind_id, service_date, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        'rec-$equipmentId-$kindId',
        equipmentId,
        'inspection',
        kindId,
        1700000000000,
        1000,
        2000,
      ],
    );
  }

  Future<({int? anchorDate, int? anchorSetAt})> anchorOf(
    String equipmentId,
    String kindId,
  ) async {
    final row = await db
        .customSelect(
          'SELECT anchor_date, anchor_set_at FROM service_schedules '
          'WHERE id = ?',
          variables: [Variable<String>('auto-$kindId-$equipmentId')],
        )
        .getSingle();
    return (
      anchorDate: row.read<int?>('anchor_date'),
      anchorSetAt: row.read<int?>('anchor_set_at'),
    );
  }

  test('v317 is in the ladder and did not move the sync floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(317));
    expect(AppDatabase.migrationVersions, contains(317));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(317));
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(317) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(317) + 1,
    );
  });

  test(
    'copies both dates onto clocks with no baseline and no record',
    () async {
      await insertTank('t1');
      await insertDate('t1', 'last_visual_inspection', vipMs);
      await insertDate('t1', 'last_hydro_test', hydroMs);
      await insertClock('t1', 'vip');
      await insertClock('t1', 'hydro');

      await db.backfillTankInspectionBaselines();

      // Stamped with when the date was saved, so every device that runs the
      // rung on the same synced rows writes the same values.
      expect(await anchorOf('t1', 'vip'), (
        anchorDate: vipMs,
        anchorSetAt: attrSavedAt,
      ));
      expect(await anchorOf('t1', 'hydro'), (
        anchorDate: hydroMs,
        anchorSetAt: attrSavedAt,
      ));
    },
  );

  test('leaves a clock that already has a baseline', () async {
    await insertTank('t2');
    await insertDate('t2', 'last_hydro_test', hydroMs);
    await insertClock('t2', 'hydro', anchorDate: 1600000000000);

    await db.backfillTankInspectionBaselines();

    expect((await anchorOf('t2', 'hydro')).anchorDate, 1600000000000);
  });

  test('leaves a clock with a service of its kind logged', () async {
    await insertTank('t3');
    await insertDate('t3', 'last_hydro_test', hydroMs);
    await insertDate('t3', 'last_visual_inspection', vipMs);
    await insertClock('t3', 'hydro');
    await insertClock('t3', 'vip');
    await insertRecord('t3', 'hydro');

    await db.backfillTankInspectionBaselines();

    expect((await anchorOf('t3', 'hydro')).anchorDate, isNull);
    // The VIP clock has no VIP record, so it still takes its date.
    expect((await anchorOf('t3', 'vip')).anchorDate, vipMs);
  });

  test('ignores a custom field with the same key', () async {
    await insertTank('t4');
    await insertDate('t4', 'last_hydro_test', hydroMs, isCustom: true);
    await insertClock('t4', 'hydro');

    await db.backfillTankInspectionBaselines();

    expect((await anchorOf('t4', 'hydro')).anchorDate, isNull);
  });

  test('ignores an item that is not a tank', () async {
    await insertTank('r1', type: 'regulator');
    await insertDate('r1', 'last_hydro_test', hydroMs);
    await insertClock('r1', 'hydro');

    await db.backfillTankInspectionBaselines();

    expect((await anchorOf('r1', 'hydro')).anchorDate, isNull);
  });
}
