import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-emergency-card shape: a diver_settings table (so the
/// PRAGMA-guarded ALTERs fire) with no emergency card columns and no
/// emergency_chambers table. Stamped at v125 so the 125->126 upgrade runs the
/// emergency card migration block (_assertEmergencyCardSchema) directly.
NativeDatabase _dbAt125() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 125');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY
        )
      ''');
      rawDb.execute("INSERT INTO diver_settings (id) VALUES ('settings')");
    },
  );
}

void main() {
  test('v126 creates emergency_chambers and adds settings columns', () async {
    final db = AppDatabase(_dbAt125());
    addTearDown(() => db.close());

    // The user-chamber table is created.
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type='table' AND name='emergency_chambers'",
        )
        .get();
    expect(tables, hasLength(1));

    // diver_settings gains the emergency card columns.
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = {for (final c in cols) c.read<String>('name')};
    expect(names, containsAll(['hidden_chamber_ids', 'emergency_region']));

    // The new columns are nullable and default to null.
    final row = await db
        .customSelect(
          'SELECT hidden_chamber_ids, emergency_region FROM diver_settings',
        )
        .getSingle();
    expect(row.read<String?>('hidden_chamber_ids'), isNull);
    expect(row.read<String?>('emergency_region'), isNull);
  });

  test('v126 is the current schema version (exact-latest tripwire)', () {
    // Exact assertion: the newest migration owns the tripwire, so the next
    // schema bump must move it forward. Relax to greaterThanOrEqualTo and add
    // a fresh exact test when a later migration lands on top of v126.
    expect(AppDatabase.currentSchemaVersion, 126);
    expect(AppDatabase.migrationVersions, contains(126));
  });
}
