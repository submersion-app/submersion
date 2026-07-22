import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// beforeOpen data self-heal: dives that have primary profile samples but no
/// dive_data_sources row (older file imports) get a synthesized primary source
/// so the grouped-by-source view (3D/spatial/compare) stops spinning.
void main() {
  // Minimal pre-seeded schema at currentSchemaVersion: only the three tables
  // the backfill touches. beforeOpen's other backstops self-guard on missing
  // tables, and ensurePerformanceIndexes swallows index DDL errors, so a
  // partial schema is safe (same technique as the v105 heading test).
  NativeDatabase seeded(void Function(dynamic rawDb) rows) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_data_sources (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 0,
            imported_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        rows(rawDb);
      },
    );
  }

  test('heals a dive that has primary profile rows but no data source', () async {
    final db = AppDatabase(
      seeded((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('orphan')");
        rawDb.execute(
          "INSERT INTO dive_profiles (id, dive_id, is_primary, timestamp, depth) "
          "VALUES ('p1', 'orphan', 1, 0, 5.0), ('p2', 'orphan', 1, 10, 8.0)",
        );
      }),
    );
    addTearDown(() => db.close());

    final rows = await db
        .customSelect(
          "SELECT id, is_primary, imported_at FROM dive_data_sources "
          "WHERE dive_id = 'orphan'",
        )
        .get();

    expect(rows, hasLength(1));
    expect(rows.single.data['id'], 'legacy-src-orphan');
    expect(rows.single.data['is_primary'], 1);
    // imported_at is a Drift dateTime() column: unix SECONDS, not millis.
    final importedAt = rows.single.data['imported_at'] as int;
    expect(importedAt, greaterThan(1000000000)); // > 2001
    expect(importedAt, lessThan(100000000000)); // < year 5138 (i.e. not millis)
  });

  test('leaves a dive that already has a data source untouched', () async {
    final db = AppDatabase(
      seeded((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('sourced')");
        rawDb.execute(
          "INSERT INTO dive_profiles (id, dive_id, is_primary, timestamp, depth) "
          "VALUES ('p1', 'sourced', 1, 0, 5.0)",
        );
        rawDb.execute(
          "INSERT INTO dive_data_sources "
          "(id, dive_id, is_primary, imported_at, created_at) "
          "VALUES ('real-src', 'sourced', 1, 111, 111)",
        );
      }),
    );
    addTearDown(() => db.close());

    final rows = await db
        .customSelect(
          "SELECT id FROM dive_data_sources WHERE dive_id = 'sourced'",
        )
        .get();

    expect(rows.map((r) => r.data['id']), ['real-src']);
  });

  test('does not heal a dive whose only profile rows are non-primary', () async {
    final db = AppDatabase(
      seeded((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('demoted')");
        rawDb.execute(
          "INSERT INTO dive_profiles (id, dive_id, is_primary, timestamp, depth) "
          "VALUES ('p1', 'demoted', 0, 0, 5.0)",
        );
      }),
    );
    addTearDown(() => db.close());

    final rows = await db
        .customSelect(
          "SELECT id FROM dive_data_sources WHERE dive_id = 'demoted'",
        )
        .get();

    expect(rows, isEmpty);
  });
}
