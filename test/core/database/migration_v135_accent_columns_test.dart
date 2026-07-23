import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v135 shape: a diver_settings table without the accent columns,
/// stamped at v134 so the 134->135 upgrade runs the accent-columns block.
NativeDatabase _dbAt134() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 134');
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
  test('v135 adds accent toggle columns defaulting to 0', () async {
    final db = AppDatabase(_dbAt134());
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>{
        'accent_nav_icons',
        'accent_section_headers',
        'accent_list_icons',
      }),
    );

    // The pre-existing row hydrates with the disabled default.
    final row = await db
        .customSelect(
          'SELECT accent_nav_icons, accent_section_headers, '
          'accent_list_icons FROM diver_settings',
        )
        .getSingle();
    expect(row.read<int>('accent_nav_icons'), 0);
    expect(row.read<int>('accent_section_headers'), 0);
    expect(row.read<int>('accent_list_icons'), 0);
  });

  test('fresh databases get the accent columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>{
        'accent_nav_icons',
        'accent_section_headers',
        'accent_list_icons',
      }),
    );
  });

  test('v135 is the current schema version (exact-latest tripwire)', () {
    // Exact assertion: the newest migration owns the tripwire, so the next
    // schema bump must move it forward. Relax to greaterThanOrEqualTo and add
    // a fresh exact test when a later migration lands on top of v135.
    expect(AppDatabase.currentSchemaVersion, 135);
    expect(AppDatabase.migrationVersions, contains(135));
  });
}
