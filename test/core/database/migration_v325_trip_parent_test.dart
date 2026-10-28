import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v325: trips gains parent_trip_id (issue #3658), the larger trip a
/// side trip is part of. Every existing trip stays a trip of its own.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL)',
      );
      rawDb.execute("INSERT INTO trips (id, name) VALUES ('t1', 'Bonaire')");
    },
  );

  Future<Set<String>> tripColumns(AppDatabase db) async =>
      (await db.customSelect("PRAGMA table_info('trips')").get())
          .map((c) => c.read<String>('name'))
          .toSet();

  test('v325 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(325));
    expect(AppDatabase.migrationVersions, contains(325));
    expect(
      AppDatabase.migrationStepCount(324),
      AppDatabase.migrationStepCount(325) + 1,
    );
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(325));
  });

  test('upgrading from v324 leaves every trip without a parent', () async {
    final db = AppDatabase(dbAt(324));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT parent_trip_id FROM trips')
        .getSingle();
    expect(row.read<String?>('parent_trip_id'), isNull);
    final index = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_trips_parent_trip_id'",
        )
        .get();
    expect(index, hasLength(1));
  });

  test('beforeOpen heals a database already at v325 that lacks it', () async {
    final db = AppDatabase(dbAt(325));
    addTearDown(db.close);
    expect(await tripColumns(db), contains('parent_trip_id'));
  });
}
