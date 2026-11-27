import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v390: sightings gain a nullable seen_at_seconds column (issue
/// #5092), when in the dive the diver saw the species, in seconds from the
/// dive start. Null means no time, so every existing sighting reads as
/// before. The sync floor rises to 390: an older peer drops the time, and
/// after it upgraded its first edit would publish a null that erases the
/// time on every device.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE sightings (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL, species_id TEXT NOT NULL, '
        'count INTEGER NOT NULL DEFAULT 1, notes TEXT NOT NULL DEFAULT \'\', '
        'abundance TEXT, hlc TEXT)',
      );
      rawDb.execute(
        "INSERT INTO sightings (id, dive_id, species_id, count) "
        "VALUES ('s1', 'd1', 'sp1', 1), ('s2', 'd1', 'sp2', 12)",
      );
    },
  );

  test('v390 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(390));
    expect(AppDatabase.migrationVersions, contains(390));
    expect(
      AppDatabase.migrationStepCount(389),
      AppDatabase.migrationStepCount(390) + 1,
    );
  });

  test('the column raises the sync floor to 390', () {
    expect(
      AppDatabase.minimumCompatibleSchemaVersion,
      greaterThanOrEqualTo(390),
    );
  });

  test('upgrading from v387 keeps every sighting, with no time', () async {
    final db = AppDatabase(dbAt(387));
    addTearDown(db.close);
    final rows = await db
        .customSelect(
          'SELECT id, count, seen_at_seconds FROM sightings ORDER BY id',
        )
        .get();
    expect(rows.map((r) => r.read<int?>('seen_at_seconds')), [null, null]);
    expect(rows.map((r) => r.read<int>('count')), [1, 12]);
  });

  test('beforeOpen heals a database already at v390 that lacks it', () async {
    final db = AppDatabase(dbAt(390));
    addTearDown(db.close);
    final columns =
        (await db.customSelect("PRAGMA table_info('sightings')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(columns, contains('seen_at_seconds'));
  });
}
