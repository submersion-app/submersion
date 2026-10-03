import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v257 adds dive_profile_series_history: metadata-only revision pointers
/// over existing dive_profile_series rows (#1197). Local-only table, so the
/// sync floor stays at 240.

Future<Set<String>> _names(AppDatabase db, String type) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = '$type'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('v257 is at or below the current schema version and in the ladder', () {
    // Relaxed when v258 (gas_switches.computer_id, #2582) and v259
    // (dive_tanks.usage_duration, #1496) landed; the newest rung owns the
    // exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(257));
    expect(AppDatabase.migrationVersions, contains(257));
    expect(
      AppDatabase.migrationStepCount(256),
      AppDatabase.migrationStepCount(257) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database has the history table and its indexes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _names(db, 'table'), contains('dive_profile_series_history'));
    expect(
      await _names(db, 'index'),
      containsAll(<String>[
        'idx_profile_series_history_dive_created',
        'idx_profile_series_history_root_created',
        'idx_profile_series_history_dive_hash',
      ]),
    );
  });

  test('upgrading from v240 backfills one pointer row per series', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 240');
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE dive_profile_series (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute("INSERT INTO dives (id) VALUES ('dive-1')");
        rawDb.execute('''
          INSERT INTO dive_profile_series (id, dive_id, computer_id, created_at)
          VALUES ('s-computer', 'dive-1', 'dc-1', 100),
                 ('s-manual', 'dive-1', NULL, 200)
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT series_id, root_series_id, parent_series_id, '
          'content_hash, revision_kind, created_at '
          'FROM dive_profile_series_history ORDER BY series_id',
        )
        .get();

    expect(rows.map((r) => r.read<String>('series_id')), [
      's-computer',
      's-manual',
    ]);
    final byId = {for (final r in rows) r.read<String>('series_id'): r};
    expect(
      byId['s-computer']!.read<String>('revision_kind'),
      'computer_import',
    );
    expect(byId['s-manual']!.read<String>('revision_kind'), 'legacy');
    for (final r in rows) {
      final id = r.read<String>('series_id');
      expect(r.read<String>('root_series_id'), id);
      expect(r.read<String?>('parent_series_id'), isNull);
      expect(r.read<String>('content_hash'), 'legacy:$id');
    }
    expect(byId['s-manual']!.read<int>('created_at'), 200);
  });
}
