import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v313: dive_centers.is_permanently_closed (issue #3379).
void main() {
  /// A v312 database: `dive_centers` with its pre-v313 columns and one
  /// center, Toucan Diving.
  NativeDatabase setupDb({int userVersion = 312}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE dive_centers (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            street TEXT,
            city TEXT,
            state_province TEXT,
            postal_code TEXT,
            latitude REAL,
            longitude REAL,
            country TEXT,
            phone TEXT,
            email TEXT,
            website TEXT,
            affiliations TEXT,
            rating REAL,
            notes TEXT NOT NULL DEFAULT '',
            fill_opens_at INTEGER,
            fill_closes_at INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO dive_centers (id, name, created_at, updated_at) "
          "VALUES ('c1', 'Toucan Diving', 0, 0)",
        );
      },
    );
  }

  Future<Map<String, Object?>?> closedColumn(AppDatabase db) async {
    final cols = await db
        .customSelect("PRAGMA table_info('dive_centers')")
        .get();
    for (final c in cols) {
      if (c.data['name'] == 'is_permanently_closed') {
        return {
          'type': c.data['type'],
          'notnull': c.data['notnull'],
          'dflt_value': c.data['dflt_value'],
        };
      }
    }
    return null;
  }

  test('v313 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(313));
    expect(AppDatabase.migrationVersions, contains(313));
    expect(
      AppDatabase.migrationStepCount(312),
      AppDatabase.migrationStepCount(313) + 1,
    );
    // Additive synced column: the sync compatibility floor does not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 308);
  });

  test('existing centers start open', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT is_permanently_closed FROM dive_centers WHERE id = 'c1'",
        )
        .getSingle();
    expect(row.read<int>('is_permanently_closed'), 0);
  });

  test(
    'a database stamped v313 without the column gets it back in beforeOpen',
    () async {
      final db = AppDatabase(setupDb(userVersion: 313));
      addTearDown(db.close);

      expect(await closedColumn(db), isNotNull);
    },
  );

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(fresh.close);

    final upgradedColumn = await closedColumn(upgraded);
    expect(upgradedColumn, isNotNull);
    expect(upgradedColumn, await closedColumn(fresh));
  });
}
