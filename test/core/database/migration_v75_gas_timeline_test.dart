import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test(
    'v75 schema includes default_show_gas_timeline on diver_settings',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();

      expect(names, contains('default_show_gas_timeline'));
    },
  );

  test(
    'v74 -> v75 upgrade adds default_show_gas_timeline defaulting to 0',
    () async {
      // Minimal pre-v75 diver_settings table at user_version = 74 (no gas
      // timeline column) so the v75 ALTER TABLE path runs.
      final native = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 74');
          rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT NOT NULL
          )
        ''');
        },
      );
      final db = AppDatabase(native);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final col = cols.firstWhere(
        (c) => c.read<String>('name') == 'default_show_gas_timeline',
      );
      expect(col.read<int>('notnull'), 1);
      expect(col.read<String?>('dflt_value'), '0');
    },
  );
}
