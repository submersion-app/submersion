import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v230 adds the nav_tracks table for measured underwater routes (spec
/// 2026-09-10-underwater-nav-track-design.md, issues #1195, #1445).

Future<Set<String>> _tables(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<void> _insertMinimalDive(AppDatabase db, String id) {
  return db.customStatement(
    "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
    "VALUES ('$id', 1, 1, 1)",
  );
}

void main() {
  test('v230 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 230);
    expect(AppDatabase.migrationVersions, contains(230));
    // Earlier numbers this rung held before main shipped them elsewhere.
    expect(AppDatabase.migrationVersions, isNot(contains(209)));
    expect(AppDatabase.migrationStepCount(228), 1);
  });

  test('a fresh database has the nav_tracks table and its columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _tables(db), contains('nav_tracks'));
    expect(
      await _columns(db, 'nav_tracks'),
      containsAll([
        'id',
        'dive_id',
        'link_mode',
        'is_primary',
        'site_id',
        'source',
        'source_ref',
        'device_name',
        'name',
        'equipment_id',
        'start_time',
        'end_time',
        'tz_offset_minutes',
        'time_offset_seconds',
        'point_count',
        'total_distance',
        'max_depth',
        'max_speed',
        'avg_speed',
        'anchor_latitude',
        'anchor_longitude',
        'end_mode',
        'end_latitude',
        'end_longitude',
        'trust_fraction',
        'heading_offset_deg',
        'codec_version',
        'points',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('a database stranded before v230 gains the table', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 228');
        rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            dive_date_time INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _tables(db), contains('nav_tracks'));
  });

  test('a database that never runs onUpgrade still gets the table via the '
      'beforeOpen backstop', () async {
    // Simulates a restore or a sync-adopted database: already at the
    // current version, so onUpgrade's own v230 rung never fires, and the
    // table can only appear because beforeOpen re-asserts it too.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _tables(db), contains('nav_tracks'));
  });

  test('deleting the linked dive nulls dive_id, not the route', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _insertMinimalDive(db, 'd1');
    await db.customStatement(
      "INSERT INTO nav_tracks (id, dive_id, source, start_time, end_time, "
      "point_count, points, created_at, updated_at) "
      "VALUES ('r1', 'd1', 'seacraft_enc', 0, 1, 2, x'', 1, 1)",
    );

    await db.customStatement("DELETE FROM dives WHERE id = 'd1'");

    final row = await db
        .customSelect("SELECT dive_id FROM nav_tracks WHERE id = 'r1'")
        .getSingle();
    expect(row.read<String?>('dive_id'), isNull);
  });

  test('a route can exist with no linked dive at all', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement(
      "INSERT INTO nav_tracks (id, source, start_time, end_time, "
      "point_count, points, created_at, updated_at) "
      "VALUES ('r1', 'seacraft_enc', 0, 1, 2, x'', 1, 1)",
    );

    final row = await db
        .customSelect("SELECT dive_id FROM nav_tracks WHERE id = 'r1'")
        .getSingle();
    expect(row.read<String?>('dive_id'), isNull);
  });
}
