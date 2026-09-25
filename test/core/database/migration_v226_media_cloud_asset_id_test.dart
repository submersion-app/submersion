import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v226: media.cloud_asset_id, the PhotoKit cloud identifier a
/// gallery link is matched by on another device (media sync program spec
/// 6.2). Rung 226 because open PR #1978 holds 225.
void main() {
  NativeDatabase setupDb({int userVersion = 224}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT,
            applies_to_dives INTEGER NOT NULL DEFAULT 1
              CHECK (applies_to_dives IN (0, 1)),
            applies_to_sites INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_sites IN (0, 1)),
            applies_to_equipment INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_equipment IN (0, 1))
          )
        ''');
        rawDb.execute('CREATE TABLE media (id TEXT PRIMARY KEY, hlc TEXT)');
        rawDb.execute("INSERT INTO media (id, hlc) VALUES ('m1', 'H1')");
      },
    );
  }

  Future<Map<String, int>> mediaColumns(AppDatabase db) async {
    final cols = await db.customSelect("PRAGMA table_info('media')").get();
    return {
      for (final c in cols) c.read<String>('name'): c.read<int>('notnull'),
    };
  }

  test('v226 is at or below the current schema version and in the ladder', () {
    // Relaxed once v227 (hidden tank presets) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(226));
    expect(AppDatabase.migrationVersions, contains(226));
    // Counted from 225 so it holds whether or not #1978's rung has landed.
    expect(AppDatabase.migrationStepCount(225), greaterThanOrEqualTo(1));
  });

  test('the column is additive and did not move the sync floor', () {
    // The floor is 224, raised by the media fact clocks. An older reader
    // never sees a cloud id and leaves it alone (the merge upserts with
    // nullToAbsent), so this rung does not raise it.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('a fresh database has media.cloud_asset_id, nullable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await mediaColumns(db);
    expect(cols, contains('cloud_asset_id'));
    expect(cols['cloud_asset_id'], 0);
  });

  test('a v224 database upgrades with the column, left empty', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(await mediaColumns(db), contains('cloud_asset_id'));
    final row = await db
        .customSelect("SELECT cloud_asset_id FROM media WHERE id = 'm1'")
        .getSingle();
    expect(row.read<String?>('cloud_asset_id'), isNull);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), AppDatabase.currentSchemaVersion);
  });

  test('the backstop re-adds the column at the current version', () async {
    // A version collision on a parallel branch: no rung runs, so only the
    // beforeOpen backstop can put the column back.
    final db = AppDatabase(
      setupDb(userVersion: AppDatabase.currentSchemaVersion),
    );
    addTearDown(db.close);
    expect(await mediaColumns(db), contains('cloud_asset_id'));
  });
}
