import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

const _index = 'idx_dive_profile_events_dive_id';

Future<bool> _hasIndex(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
        variables: [const Variable<String>(_index)],
      )
      .get();
  return rows.isNotEmpty;
}

void main() {
  test('v235 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 235);
    expect(AppDatabase.migrationVersions, contains(235));
    expect(AppDatabase.migrationStepCount(231), 1);
  });

  test('scoped event tombstones raise the sync floor to 235', () {
    // An older reader stores a scope tombstone as an inert unknown entity
    // type and keeps the events it names for good (#1926), so readers below
    // this rung are held until they update.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 235);
  });

  test('a fresh database indexes profile events by dive', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _hasIndex(db), isTrue);
  });

  test('a database stranded before v235 gains the index', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE dive_profile_events (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            event_type TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _hasIndex(db), isTrue);
  });
}
