import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v146 backfill: the retired bottom-time heuristic (time at/above 85% of
/// max depth) collapsed multilevel dives to their deepest segment. For any
/// dive whose stored bottom_time exactly reproduces that old heuristic's
/// output for its primary profile (i.e. it was machine-derived, not
/// user-typed), the migration recomputes it with the multilevel-correct
/// rule (surface departure to the last sample at/deeper than
/// min(max(6 m, 33% of max), 85% of max)).
void main() {
  // Stamped at 145 so ONLY the v146 step runs (the v132 backfill and every
  // earlier step are skipped), isolating what this test asserts.
  NativeDatabase setupDb(void Function(dynamic rawDb) seed) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 145');
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

  // Multilevel profile: 29 m until t=600, a 15.2 m tail until t=3060, then
  // safety stop and surface. Old heuristic: threshold 24.65 m, window
  // t=60..600 -> 540 s (the fingerprint). New rule: threshold 9.57 m, last
  // sample at/deeper t=3060, surface departure t=0 -> 3060 s.
  void insertMultilevelProfile(
    dynamic rawDb,
    String diveId, {
    required bool isPrimary,
    String prefix = 'p',
  }) {
    const points = [
      [0, 0.0],
      [60, 29.0],
      [600, 29.0],
      [660, 15.2],
      [3060, 15.2],
      [3120, 5.0],
      [3300, 5.0],
      [3600, 0.0],
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

  test('recomputes a bottom time that matches the old heuristic', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertDive(rawDb, 'd1', bottomTime: 540, runtime: 3600);
        insertMultilevelProfile(rawDb, 'd1', isPrimary: true);
      }),
    );
    addTearDown(db.close);

    expect(await bottomTimeOf(db, 'd1'), 3060);
  });

  test('leaves a user-typed bottom time untouched', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        // 2000 s does not match the old heuristic's 540 s for this
        // profile, so it was not machine-derived and must not change.
        insertDive(rawDb, 'd2', bottomTime: 2000, runtime: 3600);
        insertMultilevelProfile(rawDb, 'd2', isPrimary: true);
      }),
    );
    addTearDown(db.close);

    expect(await bottomTimeOf(db, 'd2'), 2000);
  });

  test('leaves a profile-less dive untouched', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertDive(rawDb, 'd3', bottomTime: 1000, runtime: 1200);
      }),
    );
    addTearDown(db.close);

    expect(await bottomTimeOf(db, 'd3'), 1000);
  });

  test('ignores secondary computer rows (primary profile only)', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertDive(rawDb, 'd4', bottomTime: 540, runtime: 3600);
        insertMultilevelProfile(rawDb, 'd4', isPrimary: false);
      }),
    );
    addTearDown(db.close);

    // No primary rows: the fingerprint cannot be computed, so no change.
    expect(await bottomTimeOf(db, 'd4'), 540);
  });

  test('does not bump hlc (deterministic local correction)', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertDive(rawDb, 'd5', bottomTime: 540, runtime: 3600, hlc: 'H1');
        insertMultilevelProfile(rawDb, 'd5', isPrimary: true);
      }),
    );
    addTearDown(db.close);

    expect(await bottomTimeOf(db, 'd5'), 3060);
    final row = await db
        .customSelect(
          'SELECT hlc FROM dives WHERE id = ?',
          variables: [const Variable<String>('d5')],
        )
        .getSingle();
    expect(row.data['hlc'], 'H1');
  });

  test('no-ops safely when dive_profiles lacks a dive_id column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 145');
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
            ['d6', 540, 3600],
          );
        },
      ),
    );
    addTearDown(db.close);

    expect(await bottomTimeOf(db, 'd6'), 540);
  });

  test('schema version is at least 146 and the migration list includes it', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(146));
    expect(AppDatabase.migrationVersions, contains(146));
  });
}
