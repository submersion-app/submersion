import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v224: media fact clocks (media sync program, spec 5.1). Upload and
/// verification facts get their own clock columns so a fact write never
/// moves the row clock.
void main() {
  /// A v221 database with a media table and the tables the beforeOpen
  /// backstops touch (the v221 test's fixture plus media).
  NativeDatabase setupDb({int userVersion = 221}) {
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
        rawDb.execute("INSERT INTO media (id, hlc) VALUES ('m2', NULL)");
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<Map<String, (String?, String?)>> clocks(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT id, upload_facts_hlc, verify_facts_hlc FROM media',
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('id'): (
          r.read<String?>('upload_facts_hlc'),
          r.read<String?>('verify_facts_hlc'),
        ),
    };
  }

  test('v224 is at or below the current schema version and in the ladder', () {
    // Relaxed once v226 (media cloud asset id) landed on top; the newest
    // rung owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(224));
    expect(AppDatabase.migrationVersions, contains(224));
    expect(AppDatabase.migrationStepCount(223), greaterThanOrEqualTo(1));
    // This rung RAISES the floor: the columns are additive, but the
    // semantics are not. A pre-v224 reader knows nothing of the fact clocks
    // and blind-upserts media, so a fact-only export from this build would
    // overwrite a caption that reader holds and we do not have.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test(
    'upgrading from v221 adds both clocks, filled from the row clock',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      expect(
        await columnsOf(db, 'media'),
        containsAll(['upload_facts_hlc', 'verify_facts_hlc']),
      );
      final c = await clocks(db);
      expect(c['m1'], ('H1', 'H1'));
      expect(c['m2'], (null, null), reason: 'no row clock, nothing to copy');
    },
  );

  test('the backstop re-adds missing columns without backfilling', () async {
    // A database already at the current version that lost the columns to a
    // version collision on a parallel branch: no rung runs, so only the
    // beforeOpen backstop can put them back, and it does not backfill.
    final db = AppDatabase(
      setupDb(userVersion: AppDatabase.currentSchemaVersion),
    );
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'media'),
      containsAll(['upload_facts_hlc', 'verify_facts_hlc']),
    );
    expect((await clocks(db))['m1'], (null, null));
  });

  test('a fresh database has both columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'media'),
      containsAll(['upload_facts_hlc', 'verify_facts_hlc']),
    );
  });
}
