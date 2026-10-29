import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v320: the device-local `nearby_peers` table for nearby Bluetooth
/// sync (issue #3731). 319 is held by PR #3726.
void main() {
  /// A v318 database with no nearby_peers table.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      registerAppSqlFunctions(rawDb);
      rawDb.execute('PRAGMA user_version = 318');
      rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
    },
  );

  Future<List<Map<String, Object?>>> tableInfo(
    AppDatabase db,
    String table,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return [
      for (final c in cols)
        {
          'name': c.data['name'],
          'type': c.data['type'],
          'notnull': c.data['notnull'],
          'pk': c.data['pk'],
        },
    ];
  }

  test('v320 is in the ladder and did not move the sync floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(320));
    expect(AppDatabase.migrationVersions, contains(320));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(320));
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(320) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(320) + 1,
    );
  });

  test('a v318 database gains nearby_peers on open', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final names = (await tableInfo(db, 'nearby_peers')).map((c) => c['name']);
    expect(
      names,
      containsAll(<String>[
        'peer_device_id',
        'display_name',
        'paired_at',
        'last_synced_at',
        'last_seen_at',
        'peer_applied_hlc_high',
        'last_error',
        'resume_base_id',
        'resume_part_index',
        'resume_offered_at',
      ]),
    );
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(fresh.close);
    expect(
      await tableInfo(upgraded, 'nearby_peers'),
      await tableInfo(fresh, 'nearby_peers'),
    );
  });

  test('the table carries no hlc column (it is never synced)', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    final names = (await tableInfo(db, 'nearby_peers')).map((c) => c['name']);
    expect(names, isNot(contains('hlc')));
  });
}
