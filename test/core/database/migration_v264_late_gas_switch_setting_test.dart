import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v264: diver_settings.default_show_late_gas_switches (issue #2939).
void main() {
  /// A v263 database whose diver_settings lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 263');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v264 is at or below the current schema version and in the ladder', () {
    // Relaxed once v265 (Insights observation dismissals, #2381) landed on
    // top; the newest rung owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(264));
    expect(AppDatabase.migrationVersions, contains(264));
    expect(
      AppDatabase.migrationStepCount(263),
      AppDatabase.migrationStepCount(264) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('upgrading from v263 defaults the overlay on', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final rows = await db
        .customSelect(
          'SELECT default_show_late_gas_switches AS v FROM diver_settings',
        )
        .get();
    expect(rows.single.read<int>('v'), 1);
  });
}
