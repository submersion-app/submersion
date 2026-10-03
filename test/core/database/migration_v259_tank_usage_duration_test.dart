import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v259: dive_tanks.usage_duration, how long a cylinder was breathed
/// as the source log recorded it (issue #1496).
void main() {
  /// A v257 database whose dive_tanks lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 257');
      rawDb.execute(
        'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
        "dive_id TEXT NOT NULL, tank_role TEXT NOT NULL DEFAULT 'backGas')",
      );
      rawDb.execute(
        'INSERT INTO dive_tanks (id, dive_id, tank_role) '
        "VALUES ('t1', 'd1', 'stage')",
      );
    },
  );

  test('v259 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands. 258 is held by an open
    // branch (#2828), so the step count is taken from 258.
    expect(AppDatabase.currentSchemaVersion, 259);
    expect(AppDatabase.migrationVersions, contains(259));
    expect(AppDatabase.migrationStepCount(258), 1);
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test(
    'upgrading from v257 adds a null usage_duration and keeps the row',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      final rows = await db
          .customSelect('SELECT tank_role, usage_duration FROM dive_tanks')
          .get();
      expect(rows.single.read<String>('tank_role'), 'stage');
      expect(rows.single.read<int?>('usage_duration'), isNull);
    },
  );
}
