import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-no-fly shape: a diver_settings table with at least one column
/// (so the PRAGMA-guarded ALTER fires). Stamped at v124 so the 124->125
/// upgrade runs the no-fly migration block directly, without invoking the
/// v124 equipment-attributes migration (which expects an equipment table).
NativeDatabase _dbAt124() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 124');
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
  test('v125 adds no_fly_preset to diver_settings', () async {
    final db = AppDatabase(_dbAt124());
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final byName = {for (final c in cols) c.read<String>('name'): c};
    expect(byName.keys, contains('no_fly_preset'));
    // Existing rows take the guideline default.
    final rows = await db
        .customSelect("SELECT no_fly_preset FROM diver_settings")
        .get();
    expect(rows.single.read<String>('no_fly_preset'), 'standard');
  });

  test('v125 no_fly_preset migration is present', () {
    // The exact-latest tripwire moved to migration_v127_incidents_test when
    // the incidents migration (v127) landed on top of v125/v126.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(125));
    expect(AppDatabase.migrationVersions, contains(125));
  });
}
