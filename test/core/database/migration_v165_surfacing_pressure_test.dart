import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v165 shape: a diver_settings table without the surfacing
/// pressure column, stamped at v161 so the upgrade to 165 runs.
NativeDatabase _dbAt161() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 161');
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
  test('v165 adds trim_tank_pressure_at_surfacing defaulting to 1', () async {
    final db = AppDatabase(_dbAt161());
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('trim_tank_pressure_at_surfacing'));

    // Existing divers opt in, because the reading the rule prefers can only
    // ever be the higher, earlier one (issue #1092).
    final row = await db
        .customSelect(
          'SELECT trim_tank_pressure_at_surfacing FROM '
          'diver_settings',
        )
        .getSingle();
    expect(row.read<int>('trim_tank_pressure_at_surfacing'), 1);
  });

  test(
    'fresh databases get the trim_tank_pressure_at_surfacing column',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('trim_tank_pressure_at_surfacing'));
    },
  );

  test('the helper no-ops when diver_settings is absent', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 161'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('v165 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(165));
    expect(AppDatabase.migrationVersions, contains(165));
  });
}
