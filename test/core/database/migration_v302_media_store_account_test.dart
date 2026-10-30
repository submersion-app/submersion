import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v302: media_stores.account_id (issue #3482), the roster row the attached
/// store lives on, so a second device holding that account attaches with
/// nothing to type. Column only, no backfill: existing stores read null. The
/// sync floor does not move: an older peer omits the column, and a null from
/// a peer never clears a stored id.
void main() {
  Future<Set<String>> columns(AppDatabase db) async {
    final rows = await db
        .customSelect("PRAGMA table_info('media_stores')")
        .get();
    return {for (final r in rows) r.read<String>('name')};
  }

  /// A file stranded at [userVersion] whose media_stores lacks the column
  /// and holds one store.
  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute(
        'CREATE TABLE media_stores (id TEXT NOT NULL PRIMARY KEY, '
        'provider_type TEXT NOT NULL, display_hint TEXT NOT NULL, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
        'hlc TEXT, last_sweep_at INTEGER)',
      );
      rawDb.execute(
        'INSERT INTO media_stores '
        '(id, provider_type, display_hint, created_at, updated_at) '
        "VALUES ('s1', 's3', 'media @ minio', 1, 1)",
      );
    },
  );

  Future<String?> accountOf(AppDatabase db, String id) async {
    final row = await db
        .customSelect("SELECT account_id FROM media_stores WHERE id = '$id'")
        .getSingle();
    return row.read<String?>('account_id');
  }

  test('v302 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(302));
    expect(AppDatabase.migrationVersions, contains(302));
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(302) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(302) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(302));
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(await columns(db), contains('account_id'));
  });

  test(
    'upgrading from v301 adds the column; existing stores read null',
    () async {
      final db = AppDatabase(strandedAt(301));
      addTearDown(db.close);
      expect(await columns(db), contains('account_id'));
      expect(await accountOf(db, 's1'), isNull);
    },
  );

  test('a database already at v302 without the column regains it', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect(await columns(db), contains('account_id'));
  });
}
