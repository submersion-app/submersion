import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('media_stores has last_sweep_at after open (fresh database)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('media_stores')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('last_sweep_at'));
  });

  test('an existing media_stores table gains last_sweep_at on upgrade',
      () async {
    // Simulate a database stranded at the pre-v136 media_stores shape: the
    // beforeOpen backstop (mirroring _assertMediaStoreSchema) must add the
    // column even when onUpgrade never ran.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE media_stores (
            id TEXT NOT NULL PRIMARY KEY,
            provider_type TEXT NOT NULL,
            display_hint TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO media_stores (id, provider_type, display_hint, "
          "created_at, updated_at) VALUES ('s1', 's3', 'hint', 1, 1)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);
    final row = await db
        .customSelect(
          "SELECT id, last_sweep_at FROM media_stores WHERE id = 's1'",
        )
        .getSingle();
    expect(row.data['id'], 's1');
    expect(row.data['last_sweep_at'], isNull);
  });

  test('v136 is the current schema version (exact-latest tripwire)', () {
    // Exact assertion: the newest migration owns the tripwire, so the next
    // schema bump must move it forward. Relax to greaterThanOrEqualTo and
    // add a fresh exact test when a later migration lands on top of v136.
    // (v135 is reserved by the in-flight color-accents branch; this claim
    // deliberately skips it, mirroring the v132-over-v131 precedent.)
    expect(AppDatabase.currentSchemaVersion, 136);
    expect(AppDatabase.migrationVersions, contains(136));
  });
}
