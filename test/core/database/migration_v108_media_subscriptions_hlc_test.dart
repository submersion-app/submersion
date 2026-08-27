import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('fresh v108 schema has media_subscriptions.hlc', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('media_subscriptions')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), contains('hlc'));
  });

  test('real onUpgrade from v107 adds the column, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 107');
        rawDb.execute('''
          CREATE TABLE media_subscriptions (
            id TEXT NOT NULL PRIMARY KEY,
            manifest_url TEXT NOT NULL,
            format TEXT NOT NULL,
            display_name TEXT,
            poll_interval_seconds INTEGER NOT NULL DEFAULT 86400,
            is_active INTEGER NOT NULL DEFAULT 1,
            credentials_host_id TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          "INSERT INTO media_subscriptions "
          "(id, manifest_url, format, created_at, updated_at) "
          "VALUES ('sub-1', 'https://x/feed.xml', 'atom', 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final row = await db
        .customSelect(
          "SELECT manifest_url, hlc FROM media_subscriptions "
          "WHERE id = 'sub-1'",
        )
        .getSingle();
    expect(row.data['manifest_url'], 'https://x/feed.xml');
    expect(row.data['hlc'], isNull);
  });

  test('version ladder includes 108', () {
    // Relaxed when v109/v110/v111 landed. The exact-latest tripwire lives in
    // the newest migration's test.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(108));
    expect(AppDatabase.migrationVersions, contains(108));
  });

  test('backstop heals a database stranded past v108 by a parallel-branch '
      'version collision', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('''
          CREATE TABLE media_subscriptions (
            id TEXT NOT NULL PRIMARY KEY,
            manifest_url TEXT NOT NULL,
            format TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('media_subscriptions')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      contains('hlc'),
      reason: 'hlc must be re-asserted by beforeOpen',
    );
  });
}
