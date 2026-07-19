import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-incidents shape stamped at v126 so the 126->127 upgrade runs
/// the incidents migration block directly. The incidents table has FK
/// references to divers/dives, but CREATE TABLE records those constraints
/// without requiring the parent tables to exist, so no prior schema is needed.
NativeDatabase _dbAt126() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 126');
    },
  );
}

void main() {
  test('v127 creates the incidents table with the expected columns', () async {
    final db = AppDatabase(_dbAt126());
    addTearDown(() => db.close());

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name = 'incidents'",
        )
        .get();
    expect(tables, hasLength(1), reason: 'incidents table created at v127');

    final cols = await db.customSelect("PRAGMA table_info('incidents')").get();
    final names = {for (final c in cols) c.read<String>('name')};
    expect(
      names,
      containsAll(<String>[
        'id',
        'diver_id',
        'dive_id',
        'occurred_at',
        'category',
        'severity',
        'narrative',
        'contributing_factors',
        'lessons_learned',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('v127 severs (not cascades) the dive link on dive deletion', () async {
    // The near-miss report must survive its dive: dive_id is a nullable FK
    // with ON DELETE SET NULL, unlike the cascading diver_id.
    final db = AppDatabase(_dbAt126());
    addTearDown(() => db.close());

    final fks = await db
        .customSelect("PRAGMA foreign_key_list('incidents')")
        .get();
    final byColumn = {
      for (final fk in fks)
        fk.read<String>('from'): fk.read<String>('on_delete'),
    };
    expect(byColumn['dive_id'], 'SET NULL');
    expect(byColumn['diver_id'], 'CASCADE');
  });

  test('v127 is the current schema version (exact-latest tripwire)', () {
    // Exact assertion: the newest migration owns the tripwire, so the next
    // schema bump must move it forward. Relax to greaterThanOrEqualTo and add
    // a fresh exact test when a later migration lands on top of v127.
    expect(AppDatabase.currentSchemaVersion, 127);
    expect(AppDatabase.migrationVersions, contains(127));
  });
}
