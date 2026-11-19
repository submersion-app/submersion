import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v371: diver_settings.favourite_dive_type_ids, the dive types each
/// diver starred to list first in the pickers (issue #4413). Nullable, no
/// backfill, so the sync floor holds.
void main() {
  /// A v370 database whose diver_settings lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 370');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v371 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(371));
    expect(AppDatabase.migrationVersions, contains(371));
  });

  test('this rung is additive and did not move the sync floor', () {
    // A later rung (v378, the marks on app-applied species tags) raised the
    // floor; v371 itself did not set it.
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(371));
  });

  test(
    'upgrading from v370 adds a null favourite_dive_type_ids and keeps the row',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      final rows = await db
          .customSelect(
            'SELECT diver_id, favourite_dive_type_ids FROM diver_settings',
          )
          .get();
      expect(rows.single.read<String>('diver_id'), 'd1');
      expect(rows.single.read<String?>('favourite_dive_type_ids'), isNull);
    },
  );

  /// A database at [version] whose diver_settings already stores favourites.
  NativeDatabase carryingDb(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL, favourite_dive_type_ids TEXT)',
      );
      rawDb.execute(
        'INSERT INTO diver_settings (id, diver_id, favourite_dive_type_ids) '
        """VALUES ('s1', 'd1', '["night","wreck"]')""",
      );
    },
  );

  // The rung re-runs on a database that already gained the column, and the
  // beforeOpen backstop runs on every open: neither may touch the stars.
  for (final version in [370, 371]) {
    test('a database at v$version already carrying the column keeps its '
        'favourites', () async {
      final db = AppDatabase(carryingDb(version));
      addTearDown(db.close);
      final row = await db
          .customSelect('SELECT favourite_dive_type_ids FROM diver_settings')
          .getSingle();
      expect(row.read<String?>('favourite_dive_type_ids'), '["night","wreck"]');
    });
  }
}
