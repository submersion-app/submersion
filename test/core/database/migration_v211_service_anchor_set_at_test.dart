import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v211 gives `service_schedules` an `anchor_set_at`: when the diver set the
/// clock's baseline date. A baseline now outranks the service records logged
/// before it, where until v211 any record of the kind won. The rung adds the
/// column and backfills nothing: a null set time keeps the old rule for every
/// existing baseline, so no clock moves on upgrade, on any device.
void main() {
  // Epoch millis for local midnights, as the date pickers store them.
  int day(int y, int m, int d) => DateTime(y, m, d).millisecondsSinceEpoch;

  NativeDatabase preV211({int userVersion = 210}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('''
          CREATE TABLE service_schedules (
            id TEXT NOT NULL PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            service_kind_id TEXT NOT NULL,
            anchor_date INTEGER,
            enabled INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          'INSERT INTO service_schedules (id, equipment_id, service_kind_id, '
          'anchor_date, created_at, updated_at) VALUES (?, ?, ?, ?, 1, 7)',
          ['legacy-svc-e1', 'e1', 'general-service', day(2024, 6, 1)],
        );
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('v211 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 211);
    expect(AppDatabase.migrationVersions, contains(211));
  });

  test('a fresh database has anchor_set_at', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await columnsOf(db, 'service_schedules'), contains('anchor_set_at'));
  });

  test('adds the column and leaves every existing row as it was', () async {
    final db = AppDatabase(preV211());
    addTearDown(db.close);

    expect(await columnsOf(db, 'service_schedules'), contains('anchor_set_at'));
    final row =
        (await db
                .customSelect(
                  'SELECT anchor_date, anchor_set_at, updated_at '
                  'FROM service_schedules',
                )
                .get())
            .single;
    // The baseline stays; its null set time is what keeps the pre-v211 rule
    // (any record of the kind outranks it), so no clock moves.
    expect(row.read<int?>('anchor_date'), day(2024, 6, 1));
    expect(row.read<int?>('anchor_set_at'), isNull);
    expect(row.read<int>('updated_at'), 7);
  });

  test('the beforeOpen backstop adds the column at v211 too', () async {
    // A device that reached 211 through a parallel branch never enters the
    // `from < 211` block; every schedule read selects the column.
    final db = AppDatabase(preV211(userVersion: 211));
    addTearDown(db.close);

    expect(await columnsOf(db, 'service_schedules'), contains('anchor_set_at'));
  });
}
