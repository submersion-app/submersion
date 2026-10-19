import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v295: connected_accounts.nickname (issue #3522), the short name a diver
/// gives a storage account. Column only, no backfill: existing rows read
/// null and show their shortened label. The sync floor does not move: an older peer omits
/// the column, and both apply paths keep a column a payload omits.
void main() {
  Future<Set<String>> columns(AppDatabase db) async {
    final rows = await db
        .customSelect("PRAGMA table_info('connected_accounts')")
        .get();
    return {for (final r in rows) r.read<String>('name')};
  }

  /// A file stranded at [userVersion] whose roster lacks the column and holds
  /// one account.
  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute(
        'CREATE TABLE connected_accounts (id TEXT NOT NULL PRIMARY KEY, '
        'kind TEXT NOT NULL, label TEXT NOT NULL, account_identifier TEXT, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)',
      );
      rawDb.execute(
        'INSERT INTO connected_accounts '
        "(id, kind, label, created_at, updated_at) VALUES ('a1', 's3', 'x', 1, 1)",
      );
    },
  );

  Future<String?> nicknameOf(AppDatabase db, String id) async {
    final row = await db
        .customSelect(
          "SELECT nickname FROM connected_accounts WHERE id = '$id'",
        )
        .getSingle();
    return row.read<String?>('nickname');
  }

  test('v295 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(295));
    expect(AppDatabase.migrationVersions, contains(295));
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(295) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(295) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(295));
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(await columns(db), contains('nickname'));
  });

  test(
    'upgrading from v294 adds the column; existing rows read null',
    () async {
      final db = AppDatabase(strandedAt(294));
      addTearDown(db.close);
      expect(await columns(db), contains('nickname'));
      expect(await nicknameOf(db, 'a1'), isNull);
    },
  );

  test('a database already at v295 without the column regains it', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect(await columns(db), contains('nickname'));
    expect(await nicknameOf(db, 'a1'), isNull);
  });
}
