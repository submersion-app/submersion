import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/core/database/database.dart'
    show kSeedDiveDiveTypesSql, AppDatabase;

void main() {
  test(
    'v92 seed inserts one junction row per dive from its dive_type slug',
    () {
      final db = sqlite3.openInMemory();
      db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY, dive_type TEXT)');
      db.execute('''
      CREATE TABLE dive_dive_types (
        id TEXT PRIMARY KEY, dive_id TEXT, dive_type_id TEXT, created_at INTEGER)
    ''');
      db.execute('''
      INSERT INTO dives (id, dive_type) VALUES
        ('d1', 'wreck'), ('d2', ''), ('d3', NULL)
    ''');

      db.execute(kSeedDiveDiveTypesSql);

      final rows = db.select(
        'SELECT dive_id, dive_type_id FROM dive_dive_types ORDER BY dive_id',
      );
      expect(rows.length, 3);
      expect(rows[0]['dive_type_id'], 'wreck'); // d1 keeps its slug
      expect(rows[1]['dive_type_id'], 'recreational'); // d2 empty -> default
      expect(rows[2]['dive_type_id'], 'recreational'); // d3 null -> default

      // ids are unique and non-empty
      final ids = db.select('SELECT id FROM dive_dive_types');
      expect(ids.map((r) => r['id']).toSet().length, 3);
      db.dispose();
    },
  );

  test('the v92 migration remains registered in the migration list', () {
    // 92 is no longer the latest schema -- the current latest-version tripwire
    // lives in migration_v93_dive_types_seed_test.dart -- but its migration
    // block must stay registered so upgrade step counts stay correct.
    expect(AppDatabase.migrationVersions, contains(92));
  });
}
