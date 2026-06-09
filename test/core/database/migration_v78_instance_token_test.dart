import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Migration 78 adds a nullable `instance_token` column to sync_metadata. The
/// token is rotated each launch and mirrored outside the DB so a restore that
/// leaves the device id unchanged (a same-device backup) is still detectable.
/// This exercises the actual onUpgrade ALTER TABLE path (the rest of the suite
/// only covers the fresh createAll schema).
void main() {
  test(
    'v78 schema includes a nullable instance_token on sync_metadata',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('sync_metadata')")
          .get();
      final col = cols.firstWhere(
        (c) => c.read<String>('name') == 'instance_token',
      );
      expect(
        col.read<int>('notnull'),
        0,
        reason: 'instance_token must be nullable',
      );
    },
  );

  test('v77 -> v78 upgrade adds instance_token to sync_metadata', () async {
    // Minimal pre-v78 sync_metadata at user_version = 77 so the v78 ALTER runs.
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 77');
        rawDb.execute('''
          CREATE TABLE sync_metadata (
            id TEXT NOT NULL PRIMARY KEY,
            device_id TEXT NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('sync_metadata')")
        .get();
    expect(cols.any((c) => c.read<String>('name') == 'instance_token'), isTrue);
  });

  test('v77 -> v78 upgrade preserves existing sync_metadata rows', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 77');
        rawDb.execute('''
          CREATE TABLE sync_metadata (
            id TEXT NOT NULL PRIMARY KEY,
            device_id TEXT NOT NULL
          )
        ''');
        rawDb.execute(
          "INSERT INTO sync_metadata (id, device_id) "
          "VALUES ('global', 'dev-keep')",
        );
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT device_id, instance_token FROM sync_metadata "
          "WHERE id = 'global'",
        )
        .getSingle();
    expect(row.read<String>('device_id'), 'dev-keep');
    expect(
      row.read<String?>('instance_token'),
      isNull,
      reason: 'migrated rows start with a null instance token (first-run seed)',
    );
  });
}
