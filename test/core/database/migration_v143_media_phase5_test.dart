import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v143 shape stamped at v142 (main's version when this phase
/// was built), so the 142->143 upgrade runs the Phase 5 table creation.
NativeDatabase _dbAt142() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 142');
      rawDb.execute('''
        CREATE TABLE media (
          id TEXT NOT NULL PRIMARY KEY,
          file_path TEXT NOT NULL,
          file_type TEXT NOT NULL DEFAULT 'photo'
        )
      ''');
    },
  );
}

Future<Set<String>> _tableNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('v143 creates the repair log and smart album tables', () async {
    final db = AppDatabase(_dbAt142());
    addTearDown(db.close);

    expect(
      await _tableNames(db),
      containsAll(['media_repair_log', 'media_smart_albums']),
    );
  });

  test('fresh databases get both tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(
      await _tableNames(db),
      containsAll(['media_repair_log', 'media_smart_albums']),
    );
  });

  test('the repair log is per-device: not a synced entity', () async {
    // A row in a synced table carries an hlc column; the repair log
    // deliberately does not, and nothing registers it for sync.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('media_repair_log')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, isNot(contains('hlc')));

    final albumCols = await db
        .customSelect("PRAGMA table_info('media_smart_albums')")
        .get();
    expect(albumCols.map((c) => c.read<String>('name')), contains('hlc'));
  });

  test('v143 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(143));
    expect(AppDatabase.migrationVersions, contains(143));
  });
}
