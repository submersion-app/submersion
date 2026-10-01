import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v252: nav_tracks.diver_id, the route's owner. A linked route is
/// backfilled from its dive's diver; an unlinked one stays ownerless, which
/// every diver sees (shared), so no existing recording drops out of anyone's
/// list. The backfill runs in the rung only; the beforeOpen backstop
/// restores the column alone. 251 is dive_tanks.source_id (#2716).
/// The sync floor does not move: an older peer ignores the column.
void main() {
  Future<Set<String>> columns(AppDatabase db) async {
    final rows = await db.customSelect("PRAGMA table_info('nav_tracks')").get();
    return {for (final r in rows) r.read<String>('name')};
  }

  Future<Map<String, String?>> owners(AppDatabase db) async {
    final rows = await db
        .customSelect('SELECT id, diver_id FROM nav_tracks ORDER BY id')
        .get();
    return {
      for (final r in rows) r.read<String>('id'): r.read<String?>('diver_id'),
    };
  }

  /// A file stranded at [userVersion] holding a route linked to the diver
  /// 'me''s dive, a route linked to an ownerless dive, and an unlinked
  /// route.
  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute(
        'CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY, diver_id TEXT)',
      );
      rawDb.execute(
        'CREATE TABLE nav_tracks (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT, start_time INTEGER)',
      );
      rawDb.execute("INSERT INTO divers (id) VALUES ('me')");
      rawDb.execute("INSERT INTO dives (id, diver_id) VALUES ('d-me', 'me')");
      rawDb.execute(
        "INSERT INTO dives (id, diver_id) VALUES ('d-nobody', NULL)",
      );
      rawDb.execute(
        "INSERT INTO nav_tracks (id, dive_id) VALUES "
        "('r-linked', 'd-me'), ('r-nobody', 'd-nobody'), "
        "('r-unlinked', NULL)",
      );
    },
  );

  test('v252 is at or below the current schema version and in the ladder', () {
    // Relaxed once v254 (dive_tanks.role_source, #2595) and v256 (computer
    // tissue, #1977) landed on top; the newest rung owns the exact
    // assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(252));
    expect(AppDatabase.migrationVersions, contains(252));
    // v251 (dive_tanks.source_id, #2716) sits directly below this rung,
    // and v250 (profile hides, #2594) below that.
    expect(AppDatabase.migrationVersions, containsAll([250, 251]));
    expect(
      AppDatabase.migrationStepCount(250),
      AppDatabase.migrationStepCount(251) + 1,
    );
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database has the column and its index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await columns(db), contains('diver_id'));
    final index = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_nav_tracks_diver'",
        )
        .get();
    expect(index, hasLength(1));
  });

  test('a database at v249 gains the column; a linked route takes its '
      'dive\'s diver, every other route stays ownerless', () async {
    final db = AppDatabase(strandedAt(249));
    addTearDown(db.close);

    expect(await columns(db), contains('diver_id'));
    expect(await owners(db), {
      'r-linked': 'me',
      'r-nobody': null,
      'r-unlinked': null,
    });
  });

  test('a database already at v252 without the column regains it, and the '
      'backstop does not backfill', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);

    expect(await columns(db), contains('diver_id'));
    expect(await owners(db), {
      'r-linked': null,
      'r-nobody': null,
      'r-unlinked': null,
    });
  });
}
