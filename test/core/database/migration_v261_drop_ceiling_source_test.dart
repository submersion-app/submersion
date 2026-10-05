import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// A v260 diver_settings shape: the retired ceiling source column beside a
/// neighbour that must survive the drop untouched.
const _v260DiverSettings = '''
  CREATE TABLE diver_settings (
    id TEXT NOT NULL PRIMARY KEY,
    diver_id TEXT NOT NULL,
    default_ndl_source INTEGER NOT NULL DEFAULT 1,
    default_ceiling_source INTEGER NOT NULL DEFAULT 1,
    default_tts_source INTEGER NOT NULL DEFAULT 1
  )
''';

const _insertRow =
    'INSERT INTO diver_settings '
    '(id, diver_id, default_ndl_source, default_ceiling_source, '
    'default_tts_source) '
    "VALUES ('s1', 'd1', 0, 0, 1)";

Future<Set<String>> _diverSettingsColumns(AppDatabase db) async {
  final rows = await db
      .customSelect("PRAGMA table_info('diver_settings')")
      .get();
  return {for (final r in rows) r.read<String>('name')};
}

void main() {
  test('v261 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 261);
    expect(AppDatabase.migrationVersions, contains(261));
    expect(AppDatabase.migrationStepCount(260), 1);
  });

  test('the drop does not move the sync floor', () {
    // Every build the floor admits stopped reading the column at v137
    // (#755), and an older peer fills the missing key from its column
    // default, so no reader at or above the floor loses anything.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh install has no default_ceiling_source column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(
      await _diverSettingsColumns(db),
      isNot(contains('default_ceiling_source')),
    );
  });

  test('v261 drops the column and keeps every row and neighbour', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 260');
          rawDb.execute(_v260DiverSettings);
          rawDb.execute(_insertRow);
        },
      ),
    );
    addTearDown(db.close);

    final columns = await _diverSettingsColumns(db);
    expect(columns, isNot(contains('default_ceiling_source')));
    expect(columns, containsAll(['default_ndl_source', 'default_tts_source']));

    final row = await db
        .customSelect(
          'SELECT default_ndl_source, default_tts_source '
          "FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<int>('default_ndl_source'), 0);
    expect(row.read<int>('default_tts_source'), 1);
  });

  test('v261 is a no-op on a table that no longer has the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 260');
          rawDb.execute('''
            CREATE TABLE diver_settings (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT NOT NULL,
              default_ndl_source INTEGER NOT NULL DEFAULT 1
            )
          ''');
          rawDb.execute(
            'INSERT INTO diver_settings (id, diver_id, default_ndl_source) '
            "VALUES ('s1', 'd1', 0)",
          );
        },
      ),
    );
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT default_ndl_source FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<int>('default_ndl_source'), 0);
  });

  test('the beforeOpen backstop drops the column from a database already '
      'stamped at the current version', () async {
    // A database at the current version never enters the v261 rung: one
    // adopted from a peer, or one another branch carried past 261.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          rawDb.execute(_v260DiverSettings);
          rawDb.execute(_insertRow);
        },
      ),
    );
    addTearDown(db.close);

    expect(
      await _diverSettingsColumns(db),
      isNot(contains('default_ceiling_source')),
    );
    final row = await db
        .customSelect(
          "SELECT default_ndl_source FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<int>('default_ndl_source'), 0);
  });
}
