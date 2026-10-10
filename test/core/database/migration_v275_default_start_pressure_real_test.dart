import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// A v274 diver_settings shape: the whole-bar start pressure between two
/// neighbours that must survive the retype untouched.
const _v274DiverSettings = '''
  CREATE TABLE diver_settings (
    id TEXT NOT NULL PRIMARY KEY,
    diver_id TEXT NOT NULL,
    default_tank_volume REAL NOT NULL DEFAULT 12.0,
    default_start_pressure INTEGER NOT NULL DEFAULT 200,
    default_tank_preset TEXT DEFAULT 'al80'
  )
''';

const _insertRow =
    'INSERT INTO diver_settings '
    '(id, diver_id, default_tank_volume, default_start_pressure, '
    'default_tank_preset) '
    "VALUES ('s1', 'd1', 11.1, 232, 'hp100')";

Future<String?> _startPressureType(AppDatabase db) async {
  final rows = await db
      .customSelect("PRAGMA table_info('diver_settings')")
      .get();
  for (final r in rows) {
    if (r.read<String>('name') == 'default_start_pressure') {
      return r.read<String>('type');
    }
  }
  return null;
}

AppDatabase _v274Database({int userVersion = 274}) => AppDatabase(
  NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute(_v274DiverSettings);
      rawDb.execute(_insertRow);
    },
  ),
);

void main() {
  test('v275 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(275));
    expect(AppDatabase.migrationVersions, contains(275));
    expect(
      AppDatabase.migrationStepCount(274),
      AppDatabase.migrationStepCount(275) + 1,
    );
  });

  test('the retype raises the sync floor to 275', () {
    // An older reader decodes the field with a hard int cast, so a decimal
    // start pressure would throw in its DiverSetting.fromJson.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 275);
  });

  test('a fresh install stores the start pressure as REAL', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _startPressureType(db), 'REAL');
  });

  test('v275 retypes the column and keeps every row and neighbour', () async {
    final db = _v274Database();
    addTearDown(db.close);

    expect(await _startPressureType(db), 'REAL');
    final row = await db
        .customSelect(
          'SELECT default_tank_volume, default_start_pressure, '
          'default_tank_preset, typeof(default_start_pressure) AS t '
          "FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<double>('default_start_pressure'), 232.0);
    expect(row.read<String>('t'), 'real');
    expect(row.read<double>('default_tank_volume'), 11.1);
    expect(row.read<String>('default_tank_preset'), 'hp100');
  });

  test('the retyped column holds a decimal and defaults to 200', () async {
    final db = _v274Database();
    addTearDown(db.close);

    await db.customStatement(
      'UPDATE diver_settings SET default_start_pressure = 206.8428 '
      "WHERE id = 's1'",
    );
    await db.customStatement(
      "INSERT INTO diver_settings (id, diver_id) VALUES ('s2', 'd2')",
    );
    final rows = await db
        .customSelect(
          'SELECT id, default_start_pressure FROM diver_settings ORDER BY id',
        )
        .get();
    expect(rows[0].read<double>('default_start_pressure'), 206.8428);
    expect(rows[1].read<double>('default_start_pressure'), 200.0);
  });

  test('the beforeOpen backstop retypes a database already stamped at the '
      'current version', () async {
    // A database at the current version never enters the v275 rung: one
    // adopted from a peer, or one another branch carried past 275.
    final db = _v274Database(userVersion: AppDatabase.currentSchemaVersion);
    addTearDown(db.close);

    expect(await _startPressureType(db), 'REAL');
    final row = await db
        .customSelect(
          "SELECT default_start_pressure FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<double>('default_start_pressure'), 232.0);
  });
}
