import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v311: trip_shares and site_shares, the profiles a trip or site is
/// shared with when it is not shared with everyone (issue #2151).
void main() {
  /// A v310 database with only the parents the shares point at.
  NativeDatabase setupDb({bool withParents = true}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA foreign_keys = ON');
      rawDb.execute('PRAGMA user_version = 310');
      rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
      if (withParents) {
        rawDb.execute('CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY)');
      }
    },
  );

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('v311 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(311));
    expect(AppDatabase.migrationVersions, contains(311));
    expect(AppDatabase.migrationStepCount(310), greaterThanOrEqualTo(1));
    // Additive tables: the floor stays where v308 put it.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 308);
  });

  test('upgrading from v310 creates trip_shares and site_shares', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'trip_shares'), {
      'id',
      'trip_id',
      'diver_id',
      'created_at',
      'hlc',
    });
    expect(await columnsOf(db, 'site_shares'), {
      'id',
      'site_id',
      'diver_id',
      'created_at',
      'hlc',
    });
  });

  test('an item is shared with a profile once', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customStatement("INSERT INTO divers (id) VALUES ('d1')");
    await db.customStatement("INSERT INTO trips (id) VALUES ('t1')");
    await db.customStatement("INSERT INTO dive_sites (id) VALUES ('s1')");
    await db.customStatement(
      "INSERT INTO trip_shares (id, trip_id, diver_id, created_at) "
      "VALUES ('a', 't1', 'd1', 0)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO trip_shares (id, trip_id, diver_id, created_at) "
        "VALUES ('b', 't1', 'd1', 0)",
      ),
      throwsA(isA<SqliteException>()),
    );
    await db.customStatement(
      "INSERT INTO site_shares (id, site_id, diver_id, created_at) "
      "VALUES ('c', 's1', 'd1', 0)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO site_shares (id, site_id, diver_id, created_at) "
        "VALUES ('d', 's1', 'd1', 0)",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('each share cascades with its item and its profile', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    for (final table in const ['trip_shares', 'site_shares']) {
      final row = await db
          .customSelect(
            'SELECT sql FROM sqlite_master WHERE name = ?',
            variables: [Variable.withString(table)],
          )
          .getSingle();
      expect(
        'ON DELETE CASCADE'.allMatches(row.read<String>('sql')).length,
        2,
        reason: table,
      );
    }
  });

  test('a fixture without the parents gains no shares tables', () async {
    final db = AppDatabase(setupDb(withParents: false));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'trip_shares'), isEmpty);
    expect(await columnsOf(db, 'site_shares'), isEmpty);
  });

  test(
    'beforeOpen recreates the tables on a v311 database without them',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA user_version = 311');
            rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
            rawDb.execute('CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)');
            rawDb.execute(
              'CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY)',
            );
          },
        ),
      );
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      expect(await columnsOf(db, 'trip_shares'), contains('trip_id'));
      expect(await columnsOf(db, 'site_shares'), contains('site_id'));
    },
  );
}
