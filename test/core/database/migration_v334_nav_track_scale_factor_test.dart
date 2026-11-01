import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v334 adds `nav_tracks.scale_factor` (issue #3823): a diver can resize a
/// dead-reckoned track against the map. NOT NULL with a default of 1, so every
/// existing track stays the size it was recorded.
void main() {
  test('v334 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(334));
    expect(AppDatabase.migrationVersions, contains(334));
  });

  test(
    'a fresh database has the column, NOT NULL with a default of 1',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('nav_tracks')")
          .get();
      final column = cols.firstWhere(
        (c) => c.read<String>('name') == 'scale_factor',
      );
      expect(column.read<int>('notnull'), 1);
      expect(column.read<String?>('dflt_value'), '1.0');
    },
  );

  /// The rung and the beforeOpen backstop share one idempotent helper, so
  /// this holds whichever runs first; the ladder entry above pins the rung.
  test('an existing track upgrades to 100%', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 332');
        rawDb.execute('''
          CREATE TABLE nav_tracks (
            id TEXT NOT NULL PRIMARY KEY, dive_id TEXT,
            start_time INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
        ''');
        rawDb.execute(
          "INSERT INTO nav_tracks (id, created_at, updated_at) "
          "VALUES ('t1', 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT scale_factor FROM nav_tracks WHERE id = 't1'")
        .getSingle();
    expect(row.read<double>('scale_factor'), 1.0);
  });
}
