import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v303: media.remote_store_id (issue #3482), the store a row's upload
/// stamps refer to, so a device that switches stores counts and uploads to
/// the new one from zero. Column only, no backfill: existing rows read null,
/// which counts for whichever store is attached until a switch claims them.
/// The sync floor does not move: an older peer omits the column, and an
/// omitted fact column keeps this device's value.
void main() {
  Future<Set<String>> columns(AppDatabase db) async {
    final rows = await db.customSelect("PRAGMA table_info('media')").get();
    return {for (final r in rows) r.read<String>('name')};
  }

  /// A file stranded at [userVersion] whose media lacks the column and holds
  /// one stamped row.
  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute(
        'CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY, '
        'remote_uploaded_at INTEGER)',
      );
      rawDb.execute(
        "INSERT INTO media (id, remote_uploaded_at) VALUES ('m1', 1)",
      );
    },
  );

  Future<String?> storeOf(AppDatabase db, String id) async {
    final row = await db
        .customSelect("SELECT remote_store_id FROM media WHERE id = '$id'")
        .getSingle();
    return row.read<String?>('remote_store_id');
  }

  test('v303 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(303));
    expect(AppDatabase.migrationVersions, contains(303));
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(303) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(303) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(303));
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(await columns(db), contains('remote_store_id'));
  });

  test(
    'upgrading from v302 adds the column; existing rows read null',
    () async {
      final db = AppDatabase(strandedAt(302));
      addTearDown(db.close);
      expect(await columns(db), contains('remote_store_id'));
      expect(await storeOf(db, 'm1'), isNull);
    },
  );

  test('a database already at v303 without the column regains it', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect(await columns(db), contains('remote_store_id'));
  });
}
