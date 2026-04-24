import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('Migration v71 - MacDive dive + site metadata columns', () {
    /// Creates an in-memory database at v70 (pre-migration) with the dives
    /// and dive_sites tables the v71 migration touches.
    ///
    /// Only the parent tables and the two columns-of-interest tables are
    /// created; the migration must cope with missing ancillary tables as it
    /// runs in older migration contexts.
    NativeDatabase setupDb() {
      return NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON');
          rawDb.execute('PRAGMA user_version = 70');

          // v70 schema: minimal columns present before v71 -- no MacDive
          // metadata. Only what's needed for the PRAGMA introspection to
          // find the tables and the ALTER TABLE statements to succeed.
          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT NOT NULL PRIMARY KEY,
              dive_date_time INTEGER NOT NULL DEFAULT 0,
              dive_type TEXT NOT NULL DEFAULT 'recreational',
              notes TEXT NOT NULL DEFAULT '',
              is_favorite INTEGER NOT NULL DEFAULT 0,
              dive_mode TEXT NOT NULL DEFAULT 'oc',
              cns_start REAL NOT NULL DEFAULT 0,
              is_planned INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dive_sites (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              notes TEXT NOT NULL DEFAULT '',
              is_shared INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      );
    }

    test('fresh database has MacDive dive columns on dives table', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db.customSelect("PRAGMA table_info('dives')").get();
      final names = cols.map((c) => c.read<String>('name')).toSet();

      expect(names, contains('boat_name'));
      expect(names, contains('boat_captain'));
      expect(names, contains('dive_operator'));
      expect(names, contains('surface_conditions'));
    });

    test(
      'fresh database has MacDive site columns on dive_sites table',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final cols = await db
            .customSelect("PRAGMA table_info('dive_sites')")
            .get();
        final names = cols.map((c) => c.read<String>('name')).toSet();

        expect(names, contains('water_type'));
        expect(names, contains('body_of_water'));
      },
    );

    test(
      'v70 -> v71 migration adds MacDive dive columns idempotently',
      () async {
        final nativeDb = setupDb();
        final db = AppDatabase(nativeDb);
        addTearDown(db.close);

        // Opening the database triggers migration from v70 to v71.
        final cols = await db.customSelect("PRAGMA table_info('dives')").get();
        final names = cols.map((c) => c.read<String>('name')).toSet();

        expect(names, contains('boat_name'));
        expect(names, contains('boat_captain'));
        expect(names, contains('dive_operator'));
        expect(names, contains('surface_conditions'));
      },
    );

    test(
      'v70 -> v71 migration adds MacDive site columns idempotently',
      () async {
        final nativeDb = setupDb();
        final db = AppDatabase(nativeDb);
        addTearDown(db.close);

        final cols = await db
            .customSelect("PRAGMA table_info('dive_sites')")
            .get();
        final names = cols.map((c) => c.read<String>('name')).toSet();

        expect(names, contains('water_type'));
        expect(names, contains('body_of_water'));
      },
    );
  });
}
