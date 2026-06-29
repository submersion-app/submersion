import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/core/database/database.dart'
    show kSeedBuiltInDiveTypesSql, AppDatabase;

void main() {
  test('v93 backfill seeds all 15 built-in dive types and is idempotent', () {
    final db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE dive_types (
        id TEXT PRIMARY KEY,
        diver_id TEXT,
        name TEXT NOT NULL,
        is_built_in INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Rows that must survive the backfill untouched: 'cavern' (added by the v88
    // migration) and a synced custom type.
    db.execute(
      "INSERT INTO dive_types (id, name, is_built_in, sort_order, created_at, updated_at) "
      "VALUES ('cavern', 'Cavern', 1, 14, 111, 111)",
    );
    db.execute(
      "INSERT INTO dive_types (id, diver_id, name, is_built_in, sort_order, created_at, updated_at) "
      "VALUES ('reef-cleanup', 'diver-1', 'Reef Cleanup', 0, 99, 222, 222)",
    );

    // Run twice: INSERT OR IGNORE on stable slug ids must be a no-op the second
    // time (and every app launch re-runs no migration, but defensiveness is free).
    db.execute(kSeedBuiltInDiveTypesSql);
    db.execute(kSeedBuiltInDiveTypesSql);

    final builtIns = db.select(
      'SELECT id, sort_order FROM dive_types WHERE is_built_in = 1 ORDER BY sort_order',
    );
    expect(builtIns.length, 15);
    expect(builtIns.first['id'], 'recreational');
    expect(builtIns[4]['id'], 'wreck');
    expect(builtIns.last['id'], 'cavern');

    // created_at / updated_at are seeded from a single computed value, so a
    // freshly inserted built-in has them identical (PR #430 review).
    final ts = db
        .select(
          "SELECT created_at, updated_at FROM dive_types WHERE id = 'recreational'",
        )
        .first;
    expect(ts['created_at'], ts['updated_at']);

    // Pre-existing rows preserved, not overwritten or duplicated.
    final cavern = db.select(
      "SELECT created_at FROM dive_types WHERE id = 'cavern'",
    );
    expect(cavern.length, 1);
    expect(cavern.first['created_at'], 111); // original kept, not re-seeded

    final custom = db.select(
      "SELECT name FROM dive_types WHERE id = 'reef-cleanup'",
    );
    expect(custom.length, 1);
    expect(custom.first['name'], 'Reef Cleanup');

    db.dispose();
  });

  test('schema version is 93 and the migration list includes it', () {
    // Latest-version tripwire: bumping the schema must come with a matching
    // migration block and an update here.
    expect(AppDatabase.currentSchemaVersion, 93);
    expect(AppDatabase.migrationVersions, contains(93));
  });
}
