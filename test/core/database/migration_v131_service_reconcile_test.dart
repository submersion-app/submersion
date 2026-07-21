import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v131 reconciliation: legacy service intervals edited after the v122 backfill
/// (so never mirrored into a clock) get a deterministic `legacy-svc-<id>`
/// "General service" clock, unless the user already deleted that clock.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> insertEquipment(String id, {int? intervalDays}) async {
    await db.customStatement(
      'INSERT INTO equipment '
      '(id, name, type, service_interval_days, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [id, 'Reg $id', 'regulator', intervalDays, 1000, 2000],
    );
  }

  Future<List<int?>> scheduleIntervals(String scheduleId) async {
    final rows = await db
        .customSelect(
          'SELECT interval_days FROM service_schedules WHERE id = ?',
          variables: [_str(scheduleId)],
        )
        .get();
    return rows.map((r) => r.read<int?>('interval_days')).toList();
  }

  test('creates a legacy-svc clock for an un-migrated interval', () async {
    await insertEquipment('e1', intervalDays: 180);

    await db.reconcileLegacyServiceSchedulesForTest();

    expect(await scheduleIntervals('legacy-svc-e1'), [180]);
  });

  test('skips equipment whose interval is null', () async {
    await insertEquipment('e0');

    await db.reconcileLegacyServiceSchedulesForTest();

    expect(await scheduleIntervals('legacy-svc-e0'), isEmpty);
  });

  test('does not resurrect a tombstoned legacy-svc clock', () async {
    await insertEquipment('e2', intervalDays: 180);
    await db.customStatement(
      'INSERT INTO deletion_log (id, entity_type, record_id, deleted_at) '
      'VALUES (?, ?, ?, ?)',
      ['del1', 'serviceSchedules', 'legacy-svc-e2', 3000],
    );

    await db.reconcileLegacyServiceSchedulesForTest();

    expect(await scheduleIntervals('legacy-svc-e2'), isEmpty);
  });

  test('leaves an existing legacy-svc clock untouched', () async {
    await insertEquipment('e3', intervalDays: 180);
    await db.customStatement(
      'INSERT INTO service_schedules '
      '(id, equipment_id, service_kind_id, interval_days, enabled, '
      'created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      ['legacy-svc-e3', 'e3', 'general-service', 999, true, 1000, 2000],
    );

    await db.reconcileLegacyServiceSchedulesForTest();

    // INSERT OR IGNORE + NOT EXISTS guard: the original interval survives.
    expect(await scheduleIntervals('legacy-svc-e3'), [999]);
  });

  test('v131 is the current schema version (exact-latest tripwire)', () {
    // Exact assertion: the newest migration owns the tripwire, so the next
    // schema bump must move it forward. Relax to greaterThanOrEqualTo and add
    // a fresh exact test when a later migration lands on top of v131.
    expect(AppDatabase.currentSchemaVersion, 131);
    expect(AppDatabase.migrationVersions, contains(131));
  });
}

// Small helper to keep the customSelect variables terse.
Variable<String> _str(String v) => Variable<String>(v);
