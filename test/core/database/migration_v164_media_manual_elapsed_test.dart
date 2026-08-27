import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v164 adds `media.manual_elapsed_seconds`: the moment in the dive the diver
/// pinned a media item to when its capture time is wrong or missing
/// (issue #1090). Nullable with no default, because null means "position it
/// from the capture time" and a pre-v164 writer's payload omits the key.
NativeDatabase _dbAt161() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 161');
      rawDb.execute('''
        CREATE TABLE media (
          id TEXT NOT NULL PRIMARY KEY,
          file_path TEXT NOT NULL,
          file_type TEXT NOT NULL DEFAULT 'photo',
          retain_in_library INTEGER NOT NULL DEFAULT 0
        )
      ''');
      rawDb.execute("INSERT INTO media (id, file_path) VALUES ('m1', '')");
    },
  );
}

void main() {
  test('v164 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(164));
    expect(AppDatabase.migrationVersions, contains(164));
  });

  test('a fresh database has media.manual_elapsed_seconds', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('media')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('manual_elapsed_seconds'));
  });

  test('the column is nullable and carries no default', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('media')").get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'manual_elapsed_seconds',
    );
    // A non-null default would claim the diver pinned every existing item
    // to the start of its dive.
    expect(column.read<int>('notnull'), 0);
    expect(column.read<String?>('dflt_value'), isNull);
  });

  test('a database at v161 gains the column and keeps its rows', () async {
    final db = AppDatabase(_dbAt161());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT manual_elapsed_seconds FROM media WHERE id = 'm1'",
        )
        .getSingle();
    expect(row.read<int?>('manual_elapsed_seconds'), isNull);
  });

  test('a database stranded at a parallel-branch v164 gains the column via '
      'beforeOpen', () async {
    // Stamped AT 164 but without the column: the onUpgrade block never
    // runs, so only the beforeOpen backstop can add it.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 164');
        rawDb.execute('''
            CREATE TABLE media (
              id TEXT NOT NULL PRIMARY KEY,
              file_path TEXT NOT NULL,
              file_type TEXT NOT NULL DEFAULT 'photo',
              retain_in_library INTEGER NOT NULL DEFAULT 0
            )
          ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('media')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('manual_elapsed_seconds'));
  });
}
