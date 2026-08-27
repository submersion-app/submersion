import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v161 shape: a diver_settings table without the O2 cell mV
/// default-visibility column, stamped at v160 so the 160->161 upgrade runs.
NativeDatabase _dbAt160() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 160');
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
  test('v161 adds default_show_o2_cell_mv defaulting to 0', () async {
    final db = AppDatabase(_dbAt160());
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('default_show_o2_cell_mv'));

    final row = await db
        .customSelect('SELECT default_show_o2_cell_mv FROM diver_settings')
        .getSingle();
    expect(row.read<int>('default_show_o2_cell_mv'), 0);
  });

  test('fresh databases get the default_show_o2_cell_mv column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('default_show_o2_cell_mv'));
  });

  test('the helper no-ops when diver_settings is absent', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 160'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('v161 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(161));
    expect(AppDatabase.migrationVersions, contains(161));
  });
}
