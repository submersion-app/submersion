import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v369: dive_sites.catalogue_answers, and the catalogue link and
/// answers a profile keeps for a shared library site in library_site_notes.
/// All nullable and never backfilled.
void main() {
  const answers = '{"not":["osm_node_2"]}';

  NativeDatabase dbAt(
    int version, {
    required bool withColumns,
    bool withTables = true,
  }) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      if (!withTables) return;
      rawDb.execute(
        'CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, country TEXT, country_code TEXT, '
        'catalogue_id TEXT'
        "${withColumns ? ', catalogue_answers TEXT' : ''})",
      );
      rawDb.execute(
        'CREATE TABLE library_site_notes (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL, site_id TEXT NOT NULL, '
        "notes TEXT NOT NULL DEFAULT '', rating REAL, "
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT'
        "${withColumns ? ', catalogue_id TEXT, catalogue_answers TEXT' : ''})",
      );
      rawDb.execute(
        "INSERT INTO dive_sites (id, name) VALUES ('s1', 'Salt Pier')",
      );
      rawDb.execute(
        'INSERT INTO library_site_notes '
        '(id, diver_id, site_id, created_at, updated_at) '
        "VALUES ('d1:s1', 'd1', 's1', 1, 1)",
      );
      if (withColumns) {
        rawDb.execute("UPDATE dive_sites SET catalogue_answers = '$answers'");
        rawDb.execute(
          "UPDATE library_site_notes SET catalogue_id = 'osm_node_1', "
          "catalogue_answers = '$answers'",
        );
      }
    },
  );

  Future<List<String>> columns(AppDatabase db, String table) async =>
      (await db.customSelect("PRAGMA table_info('$table')").get())
          .map((row) => row.read<String>('name'))
          .toList();

  Future<void> expectColumns(AppDatabase db) async {
    expect(await columns(db, 'dive_sites'), contains('catalogue_answers'));
    expect(
      await columns(db, 'library_site_notes'),
      containsAll(['catalogue_id', 'catalogue_answers']),
    );
  }

  test('v369 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(369));
    expect(AppDatabase.migrationVersions, contains(369));
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(369));
  });

  test('upgrading adds the columns and leaves existing rows empty', () async {
    final db = AppDatabase(dbAt(367, withColumns: false));
    addTearDown(db.close);

    await expectColumns(db);
    final site = await db
        .customSelect(
          "SELECT catalogue_answers FROM dive_sites WHERE id = 's1'",
        )
        .getSingle();
    expect(site.read<String?>('catalogue_answers'), isNull);
    final notes = await db
        .customSelect(
          'SELECT catalogue_id, catalogue_answers FROM library_site_notes',
        )
        .getSingle();
    expect(notes.read<String?>('catalogue_id'), isNull);
    expect(notes.read<String?>('catalogue_answers'), isNull);
  });

  test('values already stored are kept', () async {
    final db = AppDatabase(dbAt(367, withColumns: true));
    addTearDown(db.close);

    final site = await db
        .customSelect(
          "SELECT catalogue_answers FROM dive_sites WHERE id = 's1'",
        )
        .getSingle();
    expect(site.read<String?>('catalogue_answers'), answers);
    final notes = await db
        .customSelect(
          'SELECT catalogue_id, catalogue_answers FROM library_site_notes',
        )
        .getSingle();
    expect(notes.read<String?>('catalogue_id'), 'osm_node_1');
    expect(notes.read<String?>('catalogue_answers'), answers);
  });

  test('a database stamped current without the columns is healed', () async {
    final db = AppDatabase(
      dbAt(AppDatabase.currentSchemaVersion, withColumns: false),
    );
    addTearDown(db.close);

    await expectColumns(db);
  });

  test('a database without either table upgrades without failing', () async {
    final db = AppDatabase(dbAt(367, withColumns: false, withTables: false));
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });
}
