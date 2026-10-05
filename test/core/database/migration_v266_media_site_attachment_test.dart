import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v266: media.site_category and media.display_size, a site
/// attachment's category and size override (issue #1039).
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY, '
        "file_path TEXT NOT NULL DEFAULT '', original_filename TEXT)",
      );
      rawDb.execute(
        "INSERT INTO media (id, original_filename) VALUES ('m1', 'map.pdf')",
      );
    },
  );

  test('v266 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands. Counted from 265 so the
    // pin holds whether or not the open 262/264/265 claims land first.
    expect(AppDatabase.currentSchemaVersion, 266);
    expect(AppDatabase.migrationVersions, contains(266));
    expect(AppDatabase.migrationStepCount(265), 1);
  });

  test('the columns are additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test(
    'upgrading from v265 adds both columns as null and keeps the row',
    () async {
      final db = AppDatabase(dbAt(265));
      addTearDown(db.close);
      final row = await db
          .customSelect(
            'SELECT original_filename, site_category, display_size FROM media',
          )
          .getSingle();
      expect(row.read<String>('original_filename'), 'map.pdf');
      expect(row.read<String?>('site_category'), isNull);
      expect(row.read<String?>('display_size'), isNull);
    },
  );

  test('beforeOpen heals a database already at v266 that lacks them', () async {
    final db = AppDatabase(dbAt(266));
    addTearDown(db.close);
    final names = (await db.customSelect("PRAGMA table_info('media')").get())
        .map((c) => c.read<String>('name'))
        .toSet();
    expect(names, containsAll(['site_category', 'display_size']));
  });
}
