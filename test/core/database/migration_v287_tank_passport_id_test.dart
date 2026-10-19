import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v287: dive_tanks.passport_id, the tagged cylinder a tank came
/// from (issue #2650). Renumbered from 285 and 286, which #3306 and
/// #3319 shipped first.
void main() {
  /// A v286 database whose dive_tanks lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 286');
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

  test('v287 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(287));
    expect(AppDatabase.migrationVersions, contains(287));
    expect(
      AppDatabase.migrationStepCount(286),
      AppDatabase.migrationStepCount(287) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(287));
  });

  test(
    'upgrading from v286 adds a null passport_id and keeps the row',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      final rows = await db
          .customSelect('SELECT tank_role, passport_id FROM dive_tanks')
          .get();
      expect(rows.single.read<String>('tank_role'), 'stage');
      expect(rows.single.read<String?>('passport_id'), isNull);
    },
  );

  test('a fresh database has the column and its index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db.customSelect("PRAGMA table_info('dive_tanks')").get();
    expect(cols.map((c) => c.read<String>('name')), contains('passport_id'));
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_dive_tanks_passport_id'",
        )
        .get();
    expect(idx, hasLength(1));
  });
}
