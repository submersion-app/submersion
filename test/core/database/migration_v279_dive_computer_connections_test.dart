import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v279: the download connections each dive computer has reached the
/// library through (issue #3106).
void main() {
  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<Set<String>> indexesOf(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA index_list('$table')").get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v279 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(279));
    expect(AppDatabase.migrationVersions, contains(279));
    expect(
      AppDatabase.migrationStepCount(278),
      AppDatabase.migrationStepCount(279) + 1,
    );
  });

  test('a fresh database has the table and its computer index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_computer_connections'), {
      'id',
      'computer_id',
      'kind',
      'detail',
      'first_used_at',
      'last_used_at',
      'address',
      'local_last_used_at',
      'created_at',
      'updated_at',
      'hlc',
    });
    expect(
      await indexesOf(db, 'dive_computer_connections'),
      contains('idx_dive_computer_connections_computer'),
    );
  });

  test('beforeOpen creates the table on a file already at 279 without '
      'it', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 279');
          rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
          rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
          rawDb.execute(
            'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
          );
        },
      ),
    );
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'dive_computer_connections'),
      containsAll(['kind', 'address', 'local_last_used_at']),
    );
  });

  test('the rung skips a partial fixture without dive_computers', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 279');
          rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        },
      ),
    );
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_computer_connections'), isEmpty);
  });
}
