import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v266: diver_settings.hidden_built_in_ids, the built-in catalog
/// entries each diver hid from the pickers (issue #401).
void main() {
  /// A v264 database whose diver_settings lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 264');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v266 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 266);
    expect(AppDatabase.migrationVersions, contains(266));
    expect(AppDatabase.migrationStepCount(264), 1);
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test(
    'upgrading from v264 adds a null hidden_built_in_ids and keeps the row',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      final rows = await db
          .customSelect(
            'SELECT diver_id, hidden_built_in_ids FROM diver_settings',
          )
          .get();
      expect(rows.single.read<String>('diver_id'), 'd1');
      expect(rows.single.read<String?>('hidden_built_in_ids'), isNull);
    },
  );
}
