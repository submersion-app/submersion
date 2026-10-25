import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v315: one Equipment entry per dive computer and transmitter
/// (issue #3676).
void main() {
  /// A v314 database holding one hand-made transmitter entry.
  NativeDatabase setupDb() {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 314');
        rawDb.execute('''
          CREATE TABLE transmitters (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            transmitter_serial TEXT,
            dive_computer_id TEXT,
            channel_index INTEGER,
            label TEXT NOT NULL,
            tank_role TEXT NOT NULL,
            volume_l REAL,
            working_pressure_bar REAL,
            tank_material TEXT,
            preset_name TEXT,
            equipment_id TEXT,
            transmitter_equipment_id TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          'INSERT INTO transmitters (id, transmitter_serial, label, '
          "tank_role, created_at, updated_at) VALUES ('tx1', '4A21F', "
          "'Back gas', 'backGas', 0, 0)",
        );
      },
    );
  }

  test('v315 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(315));
    expect(AppDatabase.migrationVersions, contains(315));
  });

  test('the column is additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 308);
  });

  test('upgrading from v314 marks every existing entry configured', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT is_configured FROM transmitters WHERE id = 'tx1'")
        .getSingle();
    expect(row.read<int>('is_configured'), 1);
  });
}
