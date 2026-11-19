import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v373: dive_centers.logo, a dive center's logo as a 512x512 square
/// JPEG (issue #4460). Nullable, no backfill, so the sync floor holds.
void main() {
  NativeDatabase dbAt(int version, {bool withLogo = false}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          rawDb.execute(
            'CREATE TABLE dive_centers (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL, created_at INTEGER NOT NULL, '
            'updated_at INTEGER NOT NULL'
            "${withLogo ? ', logo BLOB' : ''})",
          );
          rawDb.execute(
            withLogo
                ? 'INSERT INTO dive_centers '
                      '(id, name, created_at, updated_at, logo) '
                      "VALUES ('c1', 'Blue Reef', 1, 1, X'010203')"
                : 'INSERT INTO dive_centers (id, name, created_at, updated_at) '
                      "VALUES ('c1', 'Blue Reef', 1, 1)",
          );
        },
      );

  Future<({String name, Uint8List? logo})> storedRow(AppDatabase db) async {
    final row = await db
        .customSelect('SELECT name, logo FROM dive_centers')
        .getSingle();
    return (
      name: row.read<String>('name'),
      logo: row.readNullable<Uint8List>('logo'),
    );
  }

  test('v373 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(373));
    expect(AppDatabase.migrationVersions, contains(373));
  });

  test('the new column kept the floor', () {
    // A later rung (v378, the marks on app-applied species tags) raised the
    // floor; v373 itself did not set it.
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(373));
  });

  test('upgrading from v372 adds a null logo and keeps the row', () async {
    final db = AppDatabase(dbAt(372));
    addTearDown(db.close);
    final row = await storedRow(db);
    expect(row.name, 'Blue Reef');
    expect(row.logo, isNull);
  });

  test('a database already carrying the column keeps its logo', () async {
    final db = AppDatabase(dbAt(372, withLogo: true));
    addTearDown(db.close);
    expect((await storedRow(db)).logo, [1, 2, 3]);
  });
}
