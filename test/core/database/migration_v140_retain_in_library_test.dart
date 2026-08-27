import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v140 shape: a media table without retain_in_library, stamped
/// at v137 so the 137->140 upgrade runs the retain-in-library block. The
/// ladder deliberately skips 138 (divelogs, parallel branch) and 139
/// (cylinder configs, on main until the merge); the beforeOpen backstop
/// self-heals any database a parallel-branch version collision strands in
/// between.
NativeDatabase _dbAt137() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 137');
      rawDb.execute('''
        CREATE TABLE media (
          id TEXT NOT NULL PRIMARY KEY,
          file_path TEXT NOT NULL,
          file_type TEXT NOT NULL DEFAULT 'photo'
        )
      ''');
      rawDb.execute("INSERT INTO media (id, file_path) VALUES ('m1', '')");
    },
  );
}

void main() {
  test('v140 adds media.retain_in_library defaulting to 0', () async {
    final db = AppDatabase(_dbAt137());
    addTearDown(() => db.close());

    final cols = await db.customSelect("PRAGMA table_info('media')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('retain_in_library'));

    // The pre-existing row hydrates with the not-retained default.
    final row = await db
        .customSelect('SELECT retain_in_library FROM media')
        .getSingle();
    expect(row.read<int>('retain_in_library'), 0);
  });

  test('fresh databases get retain_in_library defaulting to 0', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('media')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('retain_in_library'));

    await db.customStatement(
      "INSERT INTO media (id, file_path, created_at, updated_at) "
      "VALUES ('m1', '', 0, 0)",
    );
    final row = await db
        .customSelect('SELECT retain_in_library FROM media')
        .getSingle();
    expect(row.read<int>('retain_in_library'), 0);
  });

  test('v140 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(140));
    expect(AppDatabase.migrationVersions, contains(140));
  });
}
