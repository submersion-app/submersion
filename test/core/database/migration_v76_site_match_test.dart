import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test(
    'v76 schema includes site_match_sensitivity on diver_settings',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();

      expect(names, contains('site_match_sensitivity'));
    },
  );

  test(
    'v75 -> v76 upgrade adds site_match_sensitivity defaulting to balanced',
    () async {
      // Minimal pre-v76 diver_settings table at user_version = 75 so the v76
      // ALTER TABLE path runs.
      final native = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 75');
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
        (c) => c.read<String>('name') == 'site_match_sensitivity',
      );
      expect(col.read<int>('notnull'), 1);
      expect(col.read<String?>('dflt_value'), contains('balanced'));
    },
  );
}
