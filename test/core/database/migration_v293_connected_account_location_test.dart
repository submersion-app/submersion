import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v293: connected_accounts.location (issue #3482), a secret-free description
/// of where an S3 or WebDAV account points. Column only, no backfill:
/// existing rows read null. The sync floor does not move: an older peer omits
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

  Future<String?> locationOf(AppDatabase db, String id) async {
    final row = await db
        .customSelect(
          "SELECT location FROM connected_accounts WHERE id = '$id'",
        )
        .getSingle();
    return row.read<String?>('location');
  }

  test('v293 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(293));
    expect(AppDatabase.migrationVersions, contains(293));
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(293) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(293) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(293));
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(await columns(db), contains('location'));
  });

  test(
    'upgrading from v292 adds the column; existing rows read null',
    () async {
      final db = AppDatabase(strandedAt(292));
      addTearDown(db.close);
      expect(await columns(db), contains('location'));
      expect(await locationOf(db, 'a1'), isNull);
    },
  );

  test('a database already at v293 without the column regains it', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect(await columns(db), contains('location'));
    expect(await locationOf(db, 'a1'), isNull);
  });
}
