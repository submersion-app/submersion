import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart';

/// v263: diver_settings.distance_unit (issue #2030). Backfilled from each
/// diver's depth unit as the column is added, so nobody's site distances
/// change unit on upgrade; never rewritten afterwards.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('v263_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File dbFile() => File(p.join(dir.path, 'v263.db'));

  /// A diver_settings table as it stood at main's v261: no distance_unit.
  NativeDatabase fixtureAt(int userVersion) => NativeDatabase(
    dbFile(),
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          depth_unit TEXT NOT NULL DEFAULT 'meters',
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
      rawDb.execute(
        'INSERT INTO diver_settings (id, depth_unit) VALUES '
        "('metric', 'meters'), ('imperial', 'feet')",
      );
    },
  );

  Future<Map<String, String>> distanceUnits(AppDatabase db) async {
    final rows = await db
        .customSelect('SELECT id, distance_unit FROM diver_settings')
        .get();
    return {
      for (final r in rows)
        r.read<String>('id'): r.read<String>('distance_unit'),
    };
  }

  test('v263 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands. 262 is held by an open
    // branch (#2991), so from 261 this is one step.
    expect(AppDatabase.currentSchemaVersion, 263);
    expect(AppDatabase.migrationVersions, contains(263));
    expect(AppDatabase.migrationVersions.last, 263);
    expect(AppDatabase.migrationStepCount(261), 1);
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database defaults the column to kilometers', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'distance_unit',
    );
    expect(column.read<int>('notnull'), 1);
    expect(column.read<String?>('dflt_value'), contains('kilometers'));
  });

  test('upgrading from v261 backfills from the depth unit', () async {
    final db = AppDatabase(fixtureAt(261));
    addTearDown(db.close);
    expect(await distanceUnits(db), {
      'metric': 'kilometers',
      'imperial': 'miles',
    });
  });

  test('a database already at v263 without the column regains it, '
      'backfilled, via beforeOpen', () async {
    final db = AppDatabase(fixtureAt(263));
    addTearDown(db.close);
    expect(await distanceUnits(db), {
      'metric': 'kilometers',
      'imperial': 'miles',
    });
  });

  test('a later choice survives reopening (no second backfill)', () async {
    final first = AppDatabase(fixtureAt(261));
    await distanceUnits(first);
    await first.customStatement(
      "UPDATE diver_settings SET distance_unit = 'kilometers' "
      "WHERE id = 'imperial'",
    );
    await first.close();

    final second = AppDatabase(NativeDatabase(dbFile()));
    addTearDown(second.close);
    expect((await distanceUnits(second))['imperial'], 'kilometers');
  });
}
