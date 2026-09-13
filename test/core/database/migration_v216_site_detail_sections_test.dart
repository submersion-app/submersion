import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

const _columns = ['site_detail_sections', 'site_detail_layout'];

void main() {
  test('v216 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 216);
    expect(AppDatabase.migrationVersions, contains(216));
  });

  test('the columns are additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('a fresh database has both site detail columns, nullable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final byName = {for (final c in cols) c.read<String>('name'): c};
    for (final name in _columns) {
      expect(byName, contains(name));
      expect(byName[name]!.read<int>('notnull'), 0, reason: name);
    }
  });

  test(
    'a database stranded before v216 gains both columns via beforeOpen',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, containsAll(_columns));
    },
  );

  test('the assert is a no-op when the table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });
}
