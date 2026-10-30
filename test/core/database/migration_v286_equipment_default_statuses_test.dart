import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v286: diver_settings.equipment_default_statuses (issue #2628).
void main() {
  /// A v285 database whose diver_settings lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 285');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v286 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(286));
    expect(AppDatabase.migrationVersions, contains(286));
    expect(
      AppDatabase.migrationStepCount(285),
      AppDatabase.migrationStepCount(286) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(286));
  });

  test('upgrading keeps every diver on the factory default view', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final rows = await db
        .customSelect(
          'SELECT equipment_default_statuses AS v FROM diver_settings',
        )
        .get();
    expect(rows.single.read<String?>('v'), isNull);
  });
}
