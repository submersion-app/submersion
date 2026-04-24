import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('Migration v68 - source column on dive_profile_events', () {
    /// Creates an in-memory database at v67 with the tables the v68 migration
    /// touches: dives and dive_profile_events.
    ///
    /// The dive_profile_events schema includes all columns through v67 but
    /// none of the v68 additions (source column).
    NativeDatabase setupDb({
      List<String> diveIds = const [],
      List<
            (
              String id,
              String diveId,
              int timestamp,
              String eventType,
              String severity,
              int createdAt,
            )
          >
          events =
          const [],
    }) {
      return NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON');
          rawDb.execute('PRAGMA user_version = 67');

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

          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              dive_date_time INTEGER NOT NULL DEFAULT 0,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');

          // v67 schema: all columns present before v68 -- no source column.
          rawDb.execute('''
            CREATE TABLE dive_profile_events (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              timestamp INTEGER NOT NULL,
              event_type TEXT NOT NULL,
              severity TEXT NOT NULL DEFAULT 'info',
              description TEXT,
              depth REAL,
              value REAL,
              tank_id TEXT,
              created_at INTEGER NOT NULL
            )
          ''');

          for (final diveId in diveIds) {
            rawDb.execute(
              "INSERT INTO dives (id, diver_id) VALUES ('$diveId', 'diver1')",
            );
          }
          for (final e in events) {
            rawDb.execute(
              "INSERT INTO dive_profile_events"
              " (id, dive_id, timestamp, event_type, severity, created_at)"
              " VALUES ('${e.$1}', '${e.$2}', ${e.$3},"
              "  '${e.$4}', '${e.$5}', ${e.$6})",
            );
          }
        },
      );
    }

    test('adds source column to dive_profile_events', () async {
      final nativeDb = setupDb(
        diveIds: ['dive1'],
        events: [
          ('evt1', 'dive1', 120, 'safetyStopStart', 'info', 1700000000000),
        ],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      // Verify the source column was added by querying PRAGMA table_info.
      final columns = await db
          .customSelect("PRAGMA table_info('dive_profile_events')")
          .get();
      final colNames = columns.map((c) => c.read<String>('name')).toSet();

      expect(colNames, contains('source'));
    });

    test('existing rows default to imported after migration', () async {
      final nativeDb = setupDb(
        diveIds: ['dive1'],
        events: [
          ('evt1', 'dive1', 120, 'safetyStopStart', 'info', 1700000000000),
        ],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final rows = await db
          .customSelect(
            "SELECT id, source FROM dive_profile_events WHERE id = 'evt1'",
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.read<String>('source'), 'imported');
    });

    test(
      'migration succeeds when source column already exists (re-run guard)',
      () async {
        // Simulate a database where the v68 source column was already added
        // (e.g. partial migration or re-run). The PRAGMA table_info guard
        // should skip the ALTER TABLE statement without error.
        final nativeDb = NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON');
            rawDb.execute('PRAGMA user_version = 67');

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

            rawDb.execute('''
              CREATE TABLE dives (
                id TEXT NOT NULL PRIMARY KEY,
                diver_id TEXT REFERENCES divers(id),
                dive_date_time INTEGER NOT NULL DEFAULT 0,
                notes TEXT NOT NULL DEFAULT '',
                created_at INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL DEFAULT 0
              )
            ''');

            // v67 schema WITH the v68 source column already present --
            // simulates a partial migration where ADD COLUMN succeeded.
            rawDb.execute('''
              CREATE TABLE dive_profile_events (
                id TEXT NOT NULL PRIMARY KEY,
                dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
                timestamp INTEGER NOT NULL,
                event_type TEXT NOT NULL,
                severity TEXT NOT NULL DEFAULT 'info',
                description TEXT,
                depth REAL,
                value REAL,
                tank_id TEXT,
                source TEXT NOT NULL DEFAULT 'imported',
                created_at INTEGER NOT NULL
              )
            ''');

            rawDb.execute(
              "INSERT INTO dives (id, diver_id) VALUES ('dive1', 'diver1')",
            );
            rawDb.execute(
              "INSERT INTO dive_profile_events"
              " (id, dive_id, timestamp, event_type, severity, source, created_at)"
              " VALUES ('evt1', 'dive1', 120, 'bookmark', 'info', 'user', 1700000000000)",
            );
          },
        );

        final db = AppDatabase(nativeDb);
        addTearDown(db.close);

        // Migration should complete without error; source column must still exist.
        final columns = await db
            .customSelect("PRAGMA table_info('dive_profile_events')")
            .get();
        final colNames = columns.map((c) => c.read<String>('name')).toSet();
        expect(colNames, contains('source'));

        // Pre-existing data should be preserved through the re-run guard.
        final rows = await db
            .customSelect(
              "SELECT id, source FROM dive_profile_events WHERE id = 'evt1'",
            )
            .get();
        expect(rows, hasLength(1));
        expect(rows.first.read<String>('source'), 'user');
      },
    );
  });
}
