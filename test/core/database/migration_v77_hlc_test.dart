import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Migration 77 adds a nullable `hlc` (Hybrid Logical Clock) column to every
/// conflict-capable syncable table plus sync_metadata. This exercises the
/// actual onUpgrade ALTER TABLE path (the rest of the suite only covers the
/// fresh createAll schema).
void main() {
  test('v77 schema includes a nullable hlc column on dives', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final hlc = cols.firstWhere((c) => c.read<String>('name') == 'hlc');
    expect(hlc.read<int>('notnull'), 0, reason: 'hlc must be nullable');
  });

  test(
    'v76 -> v77 upgrade adds hlc to entity tables and sync_metadata',
    () async {
      // Minimal pre-v77 tables at user_version = 76 so the v77 ALTER path runs.
      // Only a representative spread is needed: tables absent from this schema
      // are skipped by the migration's PRAGMA guard.
      final native = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 76');
          rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
          rawDb.execute(
            'CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY)',
          );
          // settings uses a non-id primary key column.
          rawDb.execute(
            'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY)',
          );
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

      Future<bool> hasHlc(String table) async {
        final cols = await db.customSelect("PRAGMA table_info('$table')").get();
        return cols.any((c) => c.read<String>('name') == 'hlc');
      }

      expect(await hasHlc('dives'), isTrue);
      expect(await hasHlc('dive_sites'), isTrue);
      expect(await hasHlc('settings'), isTrue);
      expect(
        await hasHlc('sync_metadata'),
        isTrue,
        reason: 'the device clock is persisted in sync_metadata.hlc',
      );
    },
  );

  test('v76 -> v77 upgrade preserves existing rows', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 76');
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute("INSERT INTO dives (id) VALUES ('pre-existing-dive')");
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT id, hlc FROM dives WHERE id = 'pre-existing-dive'",
        )
        .getSingle();
    expect(row.read<String>('id'), 'pre-existing-dive');
    expect(
      row.read<String?>('hlc'),
      isNull,
      reason: 'migrated rows start with a null hlc and fall back to updatedAt',
    );
  });
}
