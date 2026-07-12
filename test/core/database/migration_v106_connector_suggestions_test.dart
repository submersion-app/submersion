import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('fresh v106 schema has connector columns on pending photo '
      'suggestions', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('pending_photo_suggestions')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      containsAll(['connector_account_id', 'remote_asset_id']),
    );
  });

  test('real onUpgrade from v105 adds the columns, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 105');
        // Minimal pre-v106 suggestions shape: enough columns for the row
        // to survive and prove the ALTERs are additive.
        rawDb.execute('''
          CREATE TABLE pending_photo_suggestions (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            platform_asset_id TEXT NOT NULL,
            taken_at INTEGER NOT NULL,
            thumbnail_path TEXT,
            dismissed INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          "INSERT INTO pending_photo_suggestions "
          "(id, dive_id, platform_asset_id, taken_at, created_at) "
          "VALUES ('s1', 'd1', 'a1', 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('pending_photo_suggestions')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      containsAll(['connector_account_id', 'remote_asset_id']),
    );

    final row = await db
        .customSelect(
          "SELECT platform_asset_id, remote_asset_id "
          "FROM pending_photo_suggestions WHERE id = 's1'",
        )
        .getSingle();
    expect(row.data['platform_asset_id'], 'a1');
    expect(row.data['remote_asset_id'], isNull);
  });

  test('version ladder includes 106', () {
    // The exact-latest tripwire moved to the v107 connected-accounts test.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(106));
    expect(AppDatabase.migrationVersions, contains(106));
  });

  test('backstop heals a database stranded past v106 by a parallel-branch '
      'version collision', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('''
          CREATE TABLE pending_photo_suggestions (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            platform_asset_id TEXT NOT NULL,
            taken_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // No migration runs (user_version == currentSchemaVersion); only the
    // beforeOpen backstop can add the missing columns.
    final cols = await db
        .customSelect("PRAGMA table_info('pending_photo_suggestions')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      containsAll(['connector_account_id', 'remote_asset_id']),
      reason: 'connector columns must be re-asserted by beforeOpen',
    );
  });
}
