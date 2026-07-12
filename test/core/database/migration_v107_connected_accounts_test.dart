import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('fresh v107 schema has connected_accounts and '
      'sync_metadata.sync_account_id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='connected_accounts'",
        )
        .get();
    expect(tables, hasLength(1));

    final cols = await db
        .customSelect("PRAGMA table_info('sync_metadata')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      contains('sync_account_id'),
    );
  });

  test('real onUpgrade from v106 creates the table and column', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 106');
        // Minimal pre-v107 sync_metadata shape: enough columns for the row
        // to survive and prove the ALTER is additive.
        rawDb.execute('''
          CREATE TABLE sync_metadata (
            id TEXT NOT NULL PRIMARY KEY,
            device_id TEXT NOT NULL,
            sync_provider TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          "INSERT INTO sync_metadata "
          "(id, device_id, sync_provider, created_at, updated_at) "
          "VALUES ('global', 'dev-1', 's3', 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='connected_accounts'",
        )
        .get();
    expect(tables, hasLength(1));

    final row = await db
        .customSelect(
          "SELECT sync_provider, sync_account_id "
          "FROM sync_metadata WHERE id = 'global'",
        )
        .getSingle();
    expect(row.data['sync_provider'], 's3');
    expect(row.data['sync_account_id'], isNull);
  });

  test('v107 adopts lightroom connector rows (ids preserved) and drops '
      'connector_accounts', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 106');
        rawDb.execute('''
          CREATE TABLE connector_accounts (
            id TEXT NOT NULL PRIMARY KEY,
            connector_type TEXT NOT NULL,
            display_name TEXT NOT NULL,
            base_url TEXT,
            account_identifier TEXT,
            credentials_ref TEXT NOT NULL,
            added_at INTEGER NOT NULL,
            last_used_at INTEGER
          )
        ''');
        rawDb.execute(
          "INSERT INTO connector_accounts "
          "(id, connector_type, display_name, credentials_ref, "
          "account_identifier, added_at) "
          "VALUES ('lr-1', 'lightroom', 'My Lightroom', 'lightroom_auth', "
          "'catalog-9', 5)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final adopted = await db
        .customSelect(
          "SELECT kind, label, account_identifier "
          "FROM connected_accounts WHERE id = 'lr-1'",
        )
        .getSingle();
    expect(adopted.data['kind'], 'adobeLightroom');
    expect(adopted.data['label'], 'My Lightroom');
    expect(adopted.data['account_identifier'], 'catalog-9');

    final oldTable = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='connector_accounts'",
        )
        .get();
    expect(oldTable, isEmpty, reason: 'connector_accounts is retired');
  });

  test('version ladder includes 107', () {
    // v107 is the newest migration: this test holds the exact-latest
    // tripwire until the next migration lands and relaxes it.
    expect(AppDatabase.currentSchemaVersion, 107);
    expect(AppDatabase.migrationVersions, contains(107));
  });

  test('backstop heals a database stranded past v107 by a parallel-branch '
      'version collision', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('''
          CREATE TABLE sync_metadata (
            id TEXT NOT NULL PRIMARY KEY,
            device_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // No migration runs (user_version == currentSchemaVersion); only the
    // beforeOpen backstop can create the table and column.
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='connected_accounts'",
        )
        .get();
    expect(
      tables,
      hasLength(1),
      reason: 'connected_accounts must be re-asserted by beforeOpen',
    );
    final cols = await db
        .customSelect("PRAGMA table_info('sync_metadata')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      contains('sync_account_id'),
      reason: 'sync_account_id must be re-asserted by beforeOpen',
    );
  });
}
