import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v276: diver_settings.icd_warnings_enabled (issue #3121).
void main() {
  /// A v275 database whose diver_settings lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 275');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v276 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(276));
    expect(AppDatabase.migrationVersions, contains(276));
    expect(
      AppDatabase.migrationStepCount(275),
      AppDatabase.migrationStepCount(276) + 1,
    );
  });

  test('this rung did not raise the floor to 276', () {
    // v275 raised it (#3091); v276 is additive. v277 (#2361) later raised
    // it past 276 for an unrelated reason, so assert only that 276 itself
    // was never the floor.
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(276));
  });

  test('upgrading from v275 defaults the warnings on', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final rows = await db
        .customSelect('SELECT icd_warnings_enabled AS v FROM diver_settings')
        .get();
    expect(rows.single.read<int>('v'), 1);
  });
}
