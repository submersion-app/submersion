import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Pre-v189 media shape: no equipment link. Only the columns the rung and
/// its assertions touch, mirroring the other migration fixtures.
const _preV189Media = '''
  CREATE TABLE media (
    id TEXT NOT NULL PRIMARY KEY,
    dive_id TEXT,
    site_id TEXT,
    file_path TEXT NOT NULL,
    file_type TEXT NOT NULL DEFAULT 'photo',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
''';

void main() {
  test('v189 adds media.equipment_id and its index, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 188');
        rawDb.execute(_preV189Media);
        rawDb.execute(
          "INSERT INTO media (id, dive_id, file_path, file_type, "
          "created_at, updated_at) "
          "VALUES ('m1', 'd1', '/tmp/a.jpg', 'photo', 100, 100)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db.customSelect("PRAGMA table_info('media')").get();
    expect(cols.map((c) => c.read<String>('name')), contains('equipment_id'));

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_media_equipment_id'",
        )
        .get();
    expect(indexes, hasLength(1));

    // The rung is column-and-index only: an existing row keeps its dive link
    // and reads back as attached to no equipment.
    final row = await db
        .customSelect("SELECT dive_id, equipment_id FROM media WHERE id = 'm1'")
        .getSingle();
    expect(row.data['dive_id'], 'd1');
    expect(row.data['equipment_id'], isNull);
  });

  test('v189 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact-version tripwire; the rung below has
    // been relaxed to greaterThanOrEqualTo. Move both together when the next
    // rung lands.
    expect(AppDatabase.currentSchemaVersion, 189);
    expect(AppDatabase.migrationVersions, contains(189));
  });

  test('v189 is idempotent when equipment_id already exists', () async {
    // An interrupted upgrade, or a database that reached this version from a
    // parallel branch, leaves the column already added. The PRAGMA guard
    // must skip the ALTER rather than fail on a duplicate column, and the
    // index creation must stay IF NOT EXISTS.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 188');
        rawDb.execute(_preV189Media);
        rawDb.execute('ALTER TABLE media ADD COLUMN equipment_id TEXT');
        rawDb.execute(
          'CREATE INDEX idx_media_equipment_id ON media(equipment_id)',
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db.customSelect("PRAGMA table_info('media')").get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(names.where((n) => n == 'equipment_id'), hasLength(1));
  });

  test('v189 is a no-op when the media table is absent', () async {
    // Minimal migration fixtures build only the tables their rung touches,
    // so the helper must self-guard rather than throw on a missing table.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 188'),
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // Reaching a query at all means the upgrade ran to completion.
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'media'",
        )
        .get();
    expect(tables, isEmpty);
  });
}
