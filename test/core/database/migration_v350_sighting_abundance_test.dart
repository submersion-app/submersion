import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v350: sightings gain a nullable abundance column (issue #4337).
/// Null means the count is exact, so every existing sighting keeps the
/// count it had and reads exactly as before. The sync floor rises to 350:
/// an older peer would store a Seen or REEF-group sighting as count 1 only,
/// and after it upgraded its first edit would publish a null that turns the
/// sighting into an exact 1 on every device.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE sightings (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL, species_id TEXT NOT NULL, '
        'count INTEGER NOT NULL DEFAULT 1, notes TEXT NOT NULL DEFAULT \'\', '
        'hlc TEXT)',
      );
      rawDb.execute(
        "INSERT INTO sightings (id, dive_id, species_id, count) "
        "VALUES ('s1', 'd1', 'sp1', 1), ('s2', 'd1', 'sp2', 12)",
      );
    },
  );

  test('v350 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(350));
    expect(AppDatabase.migrationVersions, contains(350));
    expect(
      AppDatabase.migrationStepCount(349),
      AppDatabase.migrationStepCount(350) + 1,
    );
  });

  test('the column raises the sync floor to 350', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 350);
  });

  test('upgrading from v347 keeps every existing sighting exact', () async {
    final db = AppDatabase(dbAt(347));
    addTearDown(db.close);
    final rows = await db
        .customSelect('SELECT id, count, abundance FROM sightings ORDER BY id')
        .get();
    expect(rows.map((r) => r.read<String?>('abundance')), [null, null]);
    expect(rows.map((r) => r.read<int>('count')), [1, 12]);
  });

  test('beforeOpen heals a database already at v350 that lacks it', () async {
    final db = AppDatabase(dbAt(350));
    addTearDown(db.close);
    final columns =
        (await db.customSelect("PRAGMA table_info('sightings')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(columns, contains('abundance'));
  });
}
