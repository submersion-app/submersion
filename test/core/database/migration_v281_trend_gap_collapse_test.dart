import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v281: diver_settings.trend_gap_collapse_months (issue #3251).
void main() {
  /// A v280 database whose diver_settings lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 280');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v281 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(281));
    expect(AppDatabase.migrationVersions, contains(281));
    expect(
      AppDatabase.migrationStepCount(280),
      AppDatabase.migrationStepCount(281) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(281));
  });

  test('upgrading from v280 gives every diver a one-year threshold', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final rows = await db
        .customSelect(
          'SELECT trend_gap_collapse_months AS v FROM diver_settings',
        )
        .get();
    expect(rows.single.read<int>('v'), 12);
  });
}
