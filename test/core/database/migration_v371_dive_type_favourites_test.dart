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

  test('v371 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(371));
    expect(AppDatabase.migrationVersions, contains(371));
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(371));
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
}
