import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v132 backfill: earlier imports (Subsurface/MacDive/CSV via the UDDF entity
/// importer) stored the total dive time in `bottom_time`, making it equal
/// `runtime`. When a profile exists, the migration recomputes bottom time from
/// the primary profile the same way [Dive.calculateBottomTimeFromProfile] does.
void main() {
  // Builds a pre-v132 database (stamped at main's v130) with just the tables
  // the backfill touches, then seeds dives + primary/secondary profile rows.
  NativeDatabase setupDb(void Function(dynamic rawDb) seed) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 130');
        rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            bottom_time INTEGER,
            runtime INTEGER,
            hlc TEXT
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL
          )
        ''');
        seed(rawDb);
      },
    );
  }

  void insertDive(
    dynamic rawDb,
    String id, {
    int? bottomTime,
    int? runtime,
    String? hlc,
  }) {
    rawDb.execute(
      'INSERT INTO dives (id, bottom_time, runtime, hlc) VALUES (?, ?, ?, ?)',
      [id, bottomTime, runtime, hlc],
    );
  }

  // A clear bottom window: 85% of 30 m = 25.5 m; the diver is at/above it from
  // t=60 to t=1200, so bottom time is 1140 s.
  void insertBottomWindowProfile(
    dynamic rawDb,
    String diveId, {
    required bool isPrimary,
    String prefix = 'p',
  }) {
    const points = [
      [0, 0.0],
      [60, 30.0],
      [120, 30.0],
      [1200, 30.0],
      [1260, 5.0],
      [1320, 0.0],
    ];
    for (var i = 0; i < points.length; i++) {
      rawDb.execute(
        'INSERT INTO dive_profiles (id, dive_id, is_primary, timestamp, depth) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          '$prefix-$diveId-$i',
          diveId,
          isPrimary ? 1 : 0,
          points[i][0],
          points[i][1],
        ],
      );
    }
  }

  Future<int?> bottomTimeOf(AppDatabase db, String id) async {
    final row = await db
        .customSelect(
          'SELECT bottom_time FROM dives WHERE id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingle();
    return row.data['bottom_time'] as int?;
  }

  test(
    'recomputes bottom time from the primary profile when it equals runtime',
    () async {
      final db = AppDatabase(
        setupDb((rawDb) {
          insertDive(rawDb, 'd1', bottomTime: 1320, runtime: 1320);
          insertBottomWindowProfile(rawDb, 'd1', isPrimary: true);
        }),
      );
      addTearDown(db.close);

      expect(await bottomTimeOf(db, 'd1'), 1140);
    },
  );

  test(
    'leaves a profile-less dive untouched (cannot derive bottom time)',
    () async {
      final db = AppDatabase(
        setupDb((rawDb) {
          insertDive(rawDb, 'd2', bottomTime: 1320, runtime: 1320);
        }),
      );
      addTearDown(db.close);

      expect(await bottomTimeOf(db, 'd2'), 1320);
    },
  );

  test(
    'leaves an already-correct dive untouched (bottom time != runtime)',
    () async {
      final db = AppDatabase(
        setupDb((rawDb) {
          insertDive(rawDb, 'd3', bottomTime: 1140, runtime: 1320);
          insertBottomWindowProfile(rawDb, 'd3', isPrimary: true);
        }),
      );
      addTearDown(db.close);

      expect(await bottomTimeOf(db, 'd3'), 1140);
    },
  );

  test(
    'uses only primary profile rows, ignoring secondary computer rows',
    () async {
      final db = AppDatabase(
        setupDb((rawDb) {
          insertDive(rawDb, 'd4', bottomTime: 1320, runtime: 1320);
          insertBottomWindowProfile(
            rawDb,
            'd4',
            isPrimary: true,
            prefix: 'pri',
          );
          // Secondary computer rows with an earlier bottom window that would
          // shift the computed value if wrongly included.
          rawDb.execute(
            'INSERT INTO dive_profiles (id, dive_id, is_primary, timestamp, depth)'
            ' VALUES (?, ?, 0, ?, ?)',
            ['sec-d4-0', 'd4', 30, 30.0],
          );
          rawDb.execute(
            'INSERT INTO dive_profiles (id, dive_id, is_primary, timestamp, depth)'
            ' VALUES (?, ?, 0, ?, ?)',
            ['sec-d4-1', 'd4', 90, 30.0],
          );
        }),
      );
      addTearDown(db.close);

      expect(await bottomTimeOf(db, 'd4'), 1140);
    },
  );

  test(
    'does not bump hlc (deterministic local correction, no sync traffic)',
    () async {
      final db = AppDatabase(
        setupDb((rawDb) {
          insertDive(rawDb, 'd5', bottomTime: 1320, runtime: 1320, hlc: 'H1');
          insertBottomWindowProfile(rawDb, 'd5', isPrimary: true);
        }),
      );
      addTearDown(db.close);

      expect(await bottomTimeOf(db, 'd5'), 1140);
      final row = await db
          .customSelect(
            'SELECT hlc FROM dives WHERE id = ?',
            variables: [const Variable<String>('d5')],
          )
          .getSingle();
      expect(row.data['hlc'], 'H1');
    },
  );

  test('no-ops safely when dive_profiles lacks a dive_id column', () async {
    // An ancient/minimal fixture could have dive_profiles with the read
    // columns but without dive_id (which the per-dive query filters on). The
    // guard must include dive_id so the migration no-ops instead of throwing
    // "no such column: dive_id".
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 130');
          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT NOT NULL PRIMARY KEY,
              bottom_time INTEGER,
              runtime INTEGER,
              hlc TEXT
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dive_profiles (
              id TEXT NOT NULL PRIMARY KEY,
              is_primary INTEGER NOT NULL DEFAULT 1,
              timestamp INTEGER NOT NULL,
              depth REAL NOT NULL
            )
          ''');
          rawDb.execute(
            'INSERT INTO dives (id, bottom_time, runtime) VALUES (?, ?, ?)',
            ['d6', 1320, 1320],
          );
        },
      ),
    );
    addTearDown(db.close);

    // Opening (which runs onUpgrade) must not throw; the dive is untouched.
    expect(await bottomTimeOf(db, 'd6'), 1320);
  });

  test('schema version is at least 132 and the migration list includes it', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(132));
    expect(AppDatabase.migrationVersions, contains(132));
  });
}
