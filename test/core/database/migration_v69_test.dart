import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('Migration v69 - is_shared on trips and dive_sites', () {
    /// Creates an in-memory database at v68 (pre-migration) with the tables the
    /// v69 migration touches: divers, trips, and dive_sites.
    ///
    /// The trips and dive_sites schemas include all columns through v68 but
    /// none of the v69 additions (is_shared column).
    NativeDatabase setupDb({
      List<
            (
              String id,
              String name,
              int startDate,
              int endDate,
              int createdAt,
              int updatedAt,
            )
          >
          trips =
          const [],
      List<(String id, String name, int createdAt, int updatedAt)> sites =
          const [],
    }) {
      return NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON');
          rawDb.execute('PRAGMA user_version = 68');

          rawDb.execute('''
            CREATE TABLE divers (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');
          rawDb.execute(
            "INSERT INTO divers (id, name) VALUES ('diver1', 'Alice')",
          );

          // v68 schema: all columns present before v69 -- no is_shared column.
          rawDb.execute('''
            CREATE TABLE trips (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              name TEXT NOT NULL,
              start_date INTEGER NOT NULL,
              end_date INTEGER NOT NULL,
              location TEXT,
              resort_name TEXT,
              liveaboard_name TEXT,
              trip_type TEXT NOT NULL DEFAULT 'shore',
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // v68 schema: all columns present before v69 -- no is_shared column.
          rawDb.execute('''
            CREATE TABLE dive_sites (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              name TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              latitude REAL,
              longitude REAL,
              min_depth REAL,
              max_depth REAL,
              difficulty TEXT,
              country TEXT,
              region TEXT,
              rating REAL,
              notes TEXT NOT NULL DEFAULT '',
              hazards TEXT,
              access_notes TEXT,
              mooring_number TEXT,
              parking_info TEXT,
              altitude REAL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          for (final t in trips) {
            rawDb.execute(
              "INSERT INTO trips"
              " (id, diver_id, name, start_date, end_date, created_at, updated_at)"
              " VALUES ('${t.$1}', 'diver1', '${t.$2}', ${t.$3},"
              "  ${t.$4}, ${t.$5}, ${t.$6})",
            );
          }
          for (final s in sites) {
            rawDb.execute(
              "INSERT INTO dive_sites"
              " (id, diver_id, name, created_at, updated_at)"
              " VALUES ('${s.$1}', 'diver1', '${s.$2}', ${s.$3}, ${s.$4})",
            );
          }
        },
      );
    }

    test('adds is_shared column to trips', () async {
      final nativeDb = setupDb();
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final columns = await db.customSelect("PRAGMA table_info('trips')").get();
      final colNames = columns.map((c) => c.read<String>('name')).toSet();

      expect(colNames, contains('is_shared'));
    });

    test('adds is_shared column to dive_sites', () async {
      final nativeDb = setupDb();
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final columns = await db
          .customSelect("PRAGMA table_info('dive_sites')")
          .get();
      final colNames = columns.map((c) => c.read<String>('name')).toSet();

      expect(colNames, contains('is_shared'));
    });

    test('existing rows default to is_shared = 0 after migration', () async {
      const now = 1700000000000;
      final nativeDb = setupDb(
        trips: [('trip1', 'Test Trip', now, now, now, now)],
        sites: [('site1', 'Test Site', now, now)],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final tripRows = await db
          .customSelect("SELECT id, is_shared FROM trips WHERE id = 'trip1'")
          .get();
      expect(tripRows, hasLength(1));
      expect(tripRows.first.read<int>('is_shared'), 0);

      final siteRows = await db
          .customSelect(
            "SELECT id, is_shared FROM dive_sites WHERE id = 'site1'",
          )
          .get();
      expect(siteRows, hasLength(1));
      expect(siteRows.first.read<int>('is_shared'), 0);
    });

    test(
      'is_shared defaults to false on fresh inserts via Drift API',
      () async {
        final nativeDb = setupDb();
        final db = AppDatabase(nativeDb);
        addTearDown(db.close);

        const now = 1700000000000;

        await db
            .into(db.trips)
            .insert(
              TripsCompanion.insert(
                id: 't1',
                name: 'Test Trip',
                startDate: now,
                endDate: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        final tripRow = await (db.select(
          db.trips,
        )..where((t) => t.id.equals('t1'))).getSingle();
        expect(tripRow.isShared, isFalse);

        await db
            .into(db.diveSites)
            .insert(
              DiveSitesCompanion.insert(
                id: 's1',
                name: 'Test Site',
                createdAt: now,
                updatedAt: now,
              ),
            );
        final siteRow = await (db.select(
          db.diveSites,
        )..where((t) => t.id.equals('s1'))).getSingle();
        expect(siteRow.isShared, isFalse);
      },
    );

    test(
      'migration succeeds when is_shared column already exists (re-run guard)',
      () async {
        // Simulate a database where the v69 is_shared column was already added
        // (e.g. partial migration or re-run). The PRAGMA table_info guard should
        // skip the ALTER TABLE statements without error.
        const now = 1700000000000;
        final nativeDb = NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON');
            rawDb.execute('PRAGMA user_version = 68');

            rawDb.execute('''
              CREATE TABLE divers (
                id TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                created_at INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL DEFAULT 0
              )
            ''');
            rawDb.execute(
              "INSERT INTO divers (id, name) VALUES ('diver1', 'Alice')",
            );

            // v68 schema WITH the v69 is_shared column already present --
            // simulates a partial migration where ADD COLUMN succeeded.
            rawDb.execute('''
              CREATE TABLE trips (
                id TEXT NOT NULL PRIMARY KEY,
                diver_id TEXT REFERENCES divers(id),
                name TEXT NOT NULL,
                start_date INTEGER NOT NULL,
                end_date INTEGER NOT NULL,
                location TEXT,
                resort_name TEXT,
                liveaboard_name TEXT,
                trip_type TEXT NOT NULL DEFAULT 'shore',
                notes TEXT NOT NULL DEFAULT '',
                is_shared INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');
            rawDb.execute('''
              CREATE TABLE dive_sites (
                id TEXT NOT NULL PRIMARY KEY,
                diver_id TEXT REFERENCES divers(id),
                name TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                latitude REAL,
                longitude REAL,
                min_depth REAL,
                max_depth REAL,
                difficulty TEXT,
                country TEXT,
                region TEXT,
                rating REAL,
                notes TEXT NOT NULL DEFAULT '',
                hazards TEXT,
                access_notes TEXT,
                mooring_number TEXT,
                parking_info TEXT,
                altitude REAL,
                is_shared INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');

            rawDb.execute(
              "INSERT INTO trips (id, diver_id, name, start_date, end_date,"
              " is_shared, created_at, updated_at)"
              " VALUES ('trip1', 'diver1', 'Existing Trip', $now, $now, 1, $now, $now)",
            );
            rawDb.execute(
              "INSERT INTO dive_sites (id, diver_id, name, is_shared,"
              " created_at, updated_at)"
              " VALUES ('site1', 'diver1', 'Existing Site', 1, $now, $now)",
            );
          },
        );

        final db = AppDatabase(nativeDb);
        addTearDown(db.close);

        // Migration should complete without error; is_shared column must exist.
        final tripCols = await db
            .customSelect("PRAGMA table_info('trips')")
            .get();
        final tripColNames = tripCols
            .map((c) => c.read<String>('name'))
            .toSet();
        expect(tripColNames, contains('is_shared'));

        final siteCols = await db
            .customSelect("PRAGMA table_info('dive_sites')")
            .get();
        final siteColNames = siteCols
            .map((c) => c.read<String>('name'))
            .toSet();
        expect(siteColNames, contains('is_shared'));

        // Pre-existing data should be preserved through the re-run guard.
        final tripRows = await db
            .customSelect("SELECT id, is_shared FROM trips WHERE id = 'trip1'")
            .get();
        expect(tripRows, hasLength(1));
        expect(tripRows.first.read<int>('is_shared'), 1);

        final siteRows = await db
            .customSelect(
              "SELECT id, is_shared FROM dive_sites WHERE id = 'site1'",
            )
            .get();
        expect(siteRows, hasLength(1));
        expect(siteRows.first.read<int>('is_shared'), 1);
      },
    );
  });
}
