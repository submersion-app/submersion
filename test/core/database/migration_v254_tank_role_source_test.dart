import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v254: dive_tanks.role_source, where a cylinder's role came from
/// (issue #2595).
void main() {
  /// A v251 database whose dive_tanks lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 251');
      rawDb.execute(
        'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
        "dive_id TEXT NOT NULL, tank_role TEXT NOT NULL DEFAULT 'backGas')",
      );
      rawDb.execute(
        "INSERT INTO dive_tanks (id, dive_id, tank_role) "
        "VALUES ('t1', 'd1', 'oxygenSupply')",
      );
    },
  );

  test('v254 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 254);
    expect(AppDatabase.migrationVersions, contains(254));
    // 251 (dive_tanks.source_id, #2716) sits below; 252 and 253 are held
    // by open branches.
    expect(AppDatabase.migrationVersions, contains(251));
    expect(AppDatabase.migrationStepCount(251), 1);
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test(
    'upgrading from v251 adds a null role_source and keeps the role',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      final rows = await db
          .customSelect('SELECT tank_role, role_source FROM dive_tanks')
          .get();
      expect(rows.single.read<String>('tank_role'), 'oxygenSupply');
      expect(rows.single.read<String?>('role_source'), isNull);
    },
  );
}
