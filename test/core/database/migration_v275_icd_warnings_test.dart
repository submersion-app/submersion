import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v275: diver_settings.icd_warnings_enabled (issue #3121).
void main() {
  /// A v274 database whose diver_settings lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 274');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v275 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(275));
    expect(AppDatabase.migrationVersions, contains(275));
    expect(
      AppDatabase.migrationStepCount(274),
      AppDatabase.migrationStepCount(275) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('upgrading from v274 defaults the warnings on', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final rows = await db
        .customSelect('SELECT icd_warnings_enabled AS v FROM diver_settings')
        .get();
    expect(rows.single.read<int>('v'), 1);
  });
}
