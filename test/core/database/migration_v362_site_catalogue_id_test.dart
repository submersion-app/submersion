import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v362: dive_sites.catalogue_id, the built-in catalogue record a
/// site was adopted from. Nullable and never backfilled: a site made before
/// this column has no link.
void main() {
  NativeDatabase dbAt(int version, {required bool withColumn}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          rawDb.execute(
            'CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL, country TEXT, country_code TEXT'
            "${withColumn ? ', catalogue_id TEXT' : ''})",
          );
          rawDb.execute(
            "INSERT INTO dive_sites (id, name) VALUES ('s1', 'Salt Pier')",
          );
        },
      );

  Future<List<String>> columns(AppDatabase db) async =>
      (await db.customSelect("PRAGMA table_info('dive_sites')").get())
          .map((row) => row.read<String>('name'))
          .toList();

  test('v362 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(362));
    expect(AppDatabase.migrationVersions, contains(362));
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(362));
  });

  test(
    'upgrading adds the column and leaves existing sites unlinked',
    () async {
      final db = AppDatabase(dbAt(361, withColumn: false));
      addTearDown(db.close);

      expect(await columns(db), contains('catalogue_id'));
      final row = await db
          .customSelect("SELECT catalogue_id FROM dive_sites WHERE id = 's1'")
          .getSingle();
      expect(row.read<String?>('catalogue_id'), isNull);
    },
  );

  test('a link already stored is kept', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 361');
          rawDb.execute(
            'CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL, country TEXT, country_code TEXT, '
            'catalogue_id TEXT)',
          );
          rawDb.execute(
            'INSERT INTO dive_sites (id, name, catalogue_id) '
            "VALUES ('s1', 'Salt Pier', 'osm_node_1')",
          );
        },
      ),
    );
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT catalogue_id FROM dive_sites WHERE id = 's1'")
        .getSingle();
    expect(row.read<String?>('catalogue_id'), 'osm_node_1');
  });

  test('a database stamped current without the column is healed', () async {
    // A colliding branch that took this version number first.
    final db = AppDatabase(
      dbAt(AppDatabase.currentSchemaVersion, withColumn: false),
    );
    addTearDown(db.close);

    expect(await columns(db), contains('catalogue_id'));
  });

  test('a database without dive_sites upgrades without failing', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) => rawDb.execute('PRAGMA user_version = 361'),
      ),
    );
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get(); // opens and migrates
  });
}
