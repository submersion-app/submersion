import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v254: dive_tanks.role_source, where a cylinder's role came from
/// (issue #2595).
void main() {
  /// A v252 database whose dive_tanks lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 252');
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

  test('v254 is at or below the current schema version and in the ladder', () {
    // Relaxed once v255 (safety stop ceilings, #2550), v256 (computer
    // tissue, #1977) and v257 (profile revision history, #1197) landed on
    // top; the newest rung owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(254));
    expect(AppDatabase.migrationVersions, contains(254));
    // 253 (safety review inputs, #2592) sits directly below, and 252
    // (nav_tracks.diver_id, #2703) below that; 255 (#2550), 256 (#1977)
    // and 257 (#1197) sit above.
    expect(AppDatabase.migrationVersions, containsAll([251, 252, 253]));
    final above254 = AppDatabase.migrationStepCount(254);
    expect(AppDatabase.migrationStepCount(253), above254 + 1);
    expect(AppDatabase.migrationStepCount(252), above254 + 2);
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test(
    'upgrading from v252 adds a null role_source and keeps the role',
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
