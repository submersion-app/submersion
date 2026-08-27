import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v166 shape: a diver_settings table without the place name
/// language column, stamped at v161 so the 161->166 upgrade runs.
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
  test("v166 adds place_name_language defaulting to 'en'", () async {
    final db = AppDatabase(_dbAt161());
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('place_name_language'));

    final row = await db
        .customSelect('SELECT place_name_language FROM diver_settings')
        .getSingle();
    expect(row.read<String>('place_name_language'), 'en');
  });

  test('fresh databases get the place_name_language column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('place_name_language'));
  });

  test('the helper no-ops when diver_settings is absent', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 161'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('v166 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(166));
    expect(AppDatabase.migrationVersions, contains(166));
  });
}
