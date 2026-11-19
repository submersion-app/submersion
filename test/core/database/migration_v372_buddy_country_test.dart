import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v372: buddies.country and buddies.country_code, a buddy's country
/// as written and the ISO code read from it (issue #4457). Nullable, no
/// backfill, so the sync floor holds.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE buddies (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL)',
      );
      rawDb.execute("INSERT INTO buddies (id, name) VALUES ('b1', 'Marco')");
    },
  );

  test('v372 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(372));
    expect(AppDatabase.migrationVersions, contains(372));
  });

  test('the new columns keep the floor', () {
    // A later rung (v378, the marks on app-applied species tags) raised the
    // floor; v372 itself did not set it.
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(372));
  });

  test('upgrading from v371 adds both columns, empty', () async {
    final db = AppDatabase(dbAt(371));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT country, country_code FROM buddies')
        .getSingle();
    expect(row.read<String?>('country'), isNull);
    expect(row.read<String?>('country_code'), isNull);
  });
}
