import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Migration 81 adds a nullable `last_sync_provider` column to sync_metadata.
/// It stamps the provider the sync cursor was minted against so a cursor from
/// a backend the user switched away from reads as absent for the new backend
/// (keeping the first-contact merge guard intact across a switch). This
/// exercises the real onUpgrade ALTER TABLE path.
void main() {
  test('v81 schema includes a nullable last_sync_provider', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('sync_metadata')")
        .get();
    final col = cols.firstWhere(
      (c) => c.read<String>('name') == 'last_sync_provider',
    );
    expect(
      col.read<int>('notnull'),
      0,
      reason: 'last_sync_provider must be nullable (legacy cursors are absent)',
    );
  });

  test('v80 -> v81 upgrade adds last_sync_provider to sync_metadata', () async {
    // Minimal pre-v81 sync_metadata at user_version = 80 so the v81 ALTER runs.
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 80');
        rawDb.execute('''
          CREATE TABLE sync_metadata (
            id TEXT NOT NULL PRIMARY KEY,
            device_id TEXT NOT NULL,
            last_sync_timestamp INTEGER
          )
        ''');
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('sync_metadata')")
        .get();
    expect(
      cols.any((c) => c.read<String>('name') == 'last_sync_provider'),
      isTrue,
    );
  });

  test('v80 -> v81 upgrade leaves an existing cursor unstamped (legacy, '
      'valid for any provider)', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 80');
        rawDb.execute('''
          CREATE TABLE sync_metadata (
            id TEXT NOT NULL PRIMARY KEY,
            device_id TEXT NOT NULL,
            last_sync_timestamp INTEGER
          )
        ''');
        rawDb.execute(
          "INSERT INTO sync_metadata (id, device_id, last_sync_timestamp) "
          "VALUES ('global', 'dev-keep', 12345)",
        );
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT device_id, last_sync_timestamp, last_sync_provider "
          "FROM sync_metadata WHERE id = 'global'",
        )
        .getSingle();
    expect(row.read<String>('device_id'), 'dev-keep');
    expect(row.read<int>('last_sync_timestamp'), 12345);
    expect(
      row.read<String?>('last_sync_provider'),
      isNull,
      reason:
          'a cursor that predates the stamp is legacy: null means "valid for '
          'any provider" so upgraders are not forced into a first-contact '
          'prompt',
    );
  });
}
