import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v179 shape: a dives table without the dismissal column,
/// stamped at v175 so the ladder runs up through the 179 rung.
NativeDatabase _dbAt175() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 175');
      rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          dive_datetime INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute(
        "INSERT INTO dives (id, dive_datetime, created_at, updated_at) "
        "VALUES ('d1', 0, 0, 0)",
      );
    },
  );
}

void main() {
  test('v179 adds site_suggestion_dismissed_at defaulting to NULL', () async {
    final db = AppDatabase(_dbAt175());
    addTearDown(() => db.close());

    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('site_suggestion_dismissed_at'));

    final row = await db
        .customSelect('SELECT site_suggestion_dismissed_at AS v FROM dives')
        .getSingle();
    expect(row.readNullable<int>('v'), isNull);
  });

  test('fresh databases get the column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('site_suggestion_dismissed_at'));
  });

  test('the helper no-ops when dives is absent', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 175'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);
    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('v179 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(179));
    expect(AppDatabase.migrationVersions, contains(179));
  });
}
