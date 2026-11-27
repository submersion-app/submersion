import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v387 (issue #5073): a dive site's address, phone, email, website
/// and opening hours. All nullable and never backfilled.
void main() {
  const added = ['address', 'phone', 'email', 'website', 'opening_hours'];

  NativeDatabase dbAt(int version, {bool withTable = true}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          if (!withTable) return;
          rawDb.execute(
            'CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL, parking_info TEXT)',
          );
          rawDb.execute(
            "INSERT INTO dive_sites (id, name) VALUES ('s1', 'Stoney Cove')",
          );
        },
      );

  Future<List<String>> columns(AppDatabase db) async =>
      (await db.customSelect("PRAGMA table_info('dive_sites')").get())
          .map((row) => row.read<String>('name'))
          .toList();

  test('v387 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(387));
    expect(AppDatabase.migrationVersions, contains(387));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(387));
  });

  test('upgrading adds the columns and leaves existing rows empty', () async {
    final db = AppDatabase(dbAt(386));
    addTearDown(db.close);

    expect(await columns(db), containsAll(added));
    final row = await db
        .customSelect('SELECT ${added.join(', ')} FROM dive_sites')
        .getSingle();
    for (final column in added) {
      expect(row.read<String?>(column), isNull, reason: column);
    }
  });

  test('a database stamped current without the columns is healed', () async {
    final db = AppDatabase(dbAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);

    expect(await columns(db), containsAll(added));
  });

  test('a database without the table upgrades without failing', () async {
    final db = AppDatabase(dbAt(386, withTable: false));
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });
}
