import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v242 adds equipment_service_status: the local service-due cache the
/// query language's serviceDue field reads (#2365 PR 3).
Future<Set<String>> _tables(AppDatabase db) async => {
  for (final r
      in await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get())
    r.read<String>('name'),
};

void main() {
  test('v242 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    // Relaxed once v245 landed on top; the newest rung owns the exact
    // assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(242));
    expect(AppDatabase.migrationVersions, contains(242));
    expect(AppDatabase.migrationStepCount(240), greaterThanOrEqualTo(1));
    // A local cache: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database has the cache table and no hlc column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await _tables(db), contains('equipment_service_status'));
    final cols = await db
        .customSelect("PRAGMA table_info('equipment_service_status')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), isNot(contains('hlc')));
  });

  test('a database already at the current version gains the table', () async {
    // Only the beforeOpen backstop can add it there.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          raw.execute(
            'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL)',
          );
        },
      ),
    );
    addTearDown(db.close);
    expect(await _tables(db), contains('equipment_service_status'));
  });
}
