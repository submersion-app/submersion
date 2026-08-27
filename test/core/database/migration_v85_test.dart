import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  Future<Set<String>> cols(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v85 adds hlc to media, species, field_presets', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await cols(db, 'media'), contains('hlc'));
    expect(await cols(db, 'species'), contains('hlc'));
    expect(await cols(db, 'field_presets'), contains('hlc'));
  });

  test('v84 -> v85 upgrade adds the three hlc columns', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 84');
        rawDb.execute('CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE species (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute(
          'CREATE TABLE field_presets (id TEXT NOT NULL PRIMARY KEY)',
        );
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    expect(await cols(db, 'media'), contains('hlc'));
    expect(await cols(db, 'species'), contains('hlc'));
    expect(await cols(db, 'field_presets'), contains('hlc'));
  });
}
