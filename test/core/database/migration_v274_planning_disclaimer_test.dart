import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v274: diver_settings.has_accepted_planning_disclaimer (issue #3120).
void main() {
  /// A v273 database whose diver_settings lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 273');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v274 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(274));
    expect(AppDatabase.migrationVersions, contains(274));
    expect(
      AppDatabase.migrationStepCount(273),
      AppDatabase.migrationStepCount(274) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    // v275 raised the floor later (#3091); this rung did not move it.
    expect(
      AppDatabase.minimumCompatibleSchemaVersion,
      greaterThanOrEqualTo(240),
    );
  });

  test(
    'upgrading from v273 adds has_accepted_planning_disclaimer defaulted off',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      final rows = await db
          .customSelect(
            'SELECT diver_id, has_accepted_planning_disclaimer AS v '
            'FROM diver_settings',
          )
          .get();
      expect(rows.single.read<String>('diver_id'), 'd1');
      expect(rows.single.read<int>('v'), 0);
    },
  );
}
