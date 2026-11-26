import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v383: species_covers and species_practice (issue #5027).
void main() {
  /// A database at [version] with only the tables v383 points at.
  NativeDatabase setupDb({int version = 382, bool withParents = true}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          if (!withParents) return;
          rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
          rawDb.execute('CREATE TABLE species (id TEXT NOT NULL PRIMARY KEY)');
        },
      );

  Future<Map<String, bool>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return {
      for (final c in cols) c.read<String>('name'): c.read<int>('notnull') == 0,
    };
  }

  test('version bookkeeping', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(383));
    expect(AppDatabase.migrationVersions, contains(383));
    expect(
      AppDatabase.migrationStepCount(382),
      AppDatabase.migrationStepCount(383) + 1,
    );
    // Additive tables: the floor does not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 381);
  });

  test('upgrading from v382 adds both tables', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    final covers = await columnsOf(db, 'species_covers');
    expect(covers.keys.toSet(), {
      'id',
      'diver_id',
      'species_id',
      'media_id',
      'identification_id',
      'created_at',
      'updated_at',
      'hlc',
    });
    expect(covers['media_id'], isTrue, reason: 'a cleared cover nulls it');
    expect(covers['identification_id'], isTrue);
    final practice = await columnsOf(db, 'species_practice');
    expect(practice.keys.toSet(), {
      'id',
      'diver_id',
      'species_id',
      'box',
      'due_at',
      'right_count',
      'wrong_count',
      'last_practised_at',
      'created_at',
      'updated_at',
      'hlc',
    });
    expect(practice['last_practised_at'], isTrue);
    expect(practice['box'], isFalse);
  });

  test('a fixture without the parents gains no table', () async {
    final db = AppDatabase(setupDb(withParents: false));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'species_covers'), isEmpty);
    expect(await columnsOf(db, 'species_practice'), isEmpty);
  });

  test('the backstop heals a current-version file missing both', () async {
    final db = AppDatabase(setupDb(version: AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'species_covers'), contains('media_id'));
    expect(await columnsOf(db, 'species_practice'), contains('due_at'));
  });

  test('a fresh database has both', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(await columnsOf(db, 'species_covers'), contains('species_id'));
    expect(await columnsOf(db, 'species_practice'), contains('box'));
  });
}
