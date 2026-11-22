import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v378 marks the species tags the app applied (issue #4727): whether the
/// diver has yet to confirm one, and whether it created its sighting or
/// species. Null in all three is the diver's own tag, so nothing is
/// backfilled. The columns sync, so the floor rises to 378.
Future<List<String>> _columns(AppDatabase db, String table) async => [
  for (final c in await db.customSelect("PRAGMA table_info('$table')").get())
    c.read<String>('name'),
];

const _appTagColumns = ['unconfirmed', 'created_sighting', 'created_species'];

/// The tags table exactly as v377 left it, with one hand tag.
NativeDatabase _at377() => NativeDatabase.memory(
  setup: (raw) {
    registerAppSqlFunctions(raw);
    raw.execute('PRAGMA user_version = 377');
    raw.execute('CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY)');
    raw.execute(
      'CREATE TABLE media_species ('
      'id TEXT NOT NULL PRIMARY KEY, media_id TEXT NOT NULL, '
      'species_id TEXT NOT NULL, sighting_id TEXT NULL, '
      'bbox_x REAL NULL, bbox_y REAL NULL, bbox_width REAL NULL, '
      'bbox_height REAL NULL, notes TEXT NULL, created_at INTEGER NOT NULL, '
      'hlc TEXT NULL)',
    );
    raw.execute(
      "INSERT INTO media_species (id, media_id, species_id, created_at) "
      "VALUES ('t1', 'm1', 's1', 1)",
    );
  },
);

void main() {
  test('v378 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(378));
    expect(AppDatabase.migrationVersions, contains(378));
  });

  test('the floor rises to 378', () {
    // An older peer would publish the marks as explicit nulls once it
    // updates, silently confirming the app's tags everywhere. A later rung
    // (v381, issue #4876) raised it again.
    expect(
      AppDatabase.minimumCompatibleSchemaVersion,
      greaterThanOrEqualTo(378),
    );
  });

  test('a fresh database has the three columns', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(await _columns(db, 'media_species'), containsAll(_appTagColumns));
  });

  test('upgrading from 377 adds them null: the diver\'s own tag', () async {
    final db = AppDatabase(_at377());
    addTearDown(db.close);
    final row =
        (await db
                .customSelect(
                  'SELECT id, species_id, unconfirmed, created_sighting, '
                  'created_species FROM media_species',
                )
                .getSingle())
            .data;
    expect(row['id'], 't1');
    expect(row['species_id'], 's1');
    expect(row['unconfirmed'], isNull);
    expect(row['created_sighting'], isNull);
    expect(row['created_species'], isNull);
  });

  test('a database already at the current version gains them', () async {
    // Only the beforeOpen backstop reaches a restore or a sync-adopt.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          registerAppSqlFunctions(raw);
          raw.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          raw.execute('CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY)');
          raw.execute(
            'CREATE TABLE media_species ('
            'id TEXT NOT NULL PRIMARY KEY, media_id TEXT NOT NULL, '
            'species_id TEXT NOT NULL, created_at INTEGER NOT NULL)',
          );
        },
      ),
    );
    addTearDown(db.close);
    expect(await _columns(db, 'media_species'), containsAll(_appTagColumns));
  });
}
