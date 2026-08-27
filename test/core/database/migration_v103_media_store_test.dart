import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('fresh v103 schema has media store columns and media_stores '
      'table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final mediaCols = await db.customSelect("PRAGMA table_info('media')").get();
    final mediaColNames = mediaCols.map((c) => c.read<String>('name')).toSet();
    expect(
      mediaColNames,
      containsAll([
        'content_hash',
        'content_size_bytes',
        'remote_uploaded_at',
        'remote_thumb_uploaded_at',
      ]),
    );

    final storeCols = await db
        .customSelect("PRAGMA table_info('media_stores')")
        .get();
    final storeColNames = storeCols.map((c) => c.read<String>('name')).toSet();
    expect(
      storeColNames,
      containsAll([
        'id',
        'provider_type',
        'display_hint',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('real onUpgrade from v102 adds columns and table, preserving '
      'rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 102');
        // Minimal pre-v103 media shape: enough columns for the row to
        // survive and prove the ALTERs are additive.
        rawDb.execute('''
          CREATE TABLE media (
            id TEXT NOT NULL PRIMARY KEY,
            file_path TEXT NOT NULL,
            file_type TEXT NOT NULL DEFAULT 'photo',
            source_type TEXT NOT NULL DEFAULT 'platformGallery',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO media (id, file_path, created_at, updated_at) "
          "VALUES ('m1', '', 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final mediaCols = await db.customSelect("PRAGMA table_info('media')").get();
    expect(
      mediaCols.map((c) => c.read<String>('name')),
      containsAll(['content_hash', 'remote_uploaded_at']),
    );

    final storeCols = await db
        .customSelect("PRAGMA table_info('media_stores')")
        .get();
    expect(storeCols, isNotEmpty);

    final row = await db
        .customSelect(
          "SELECT file_path, content_hash FROM media WHERE id = 'm1'",
        )
        .getSingle();
    expect(row.data['file_path'], '');
    expect(row.data['content_hash'], isNull);
  });

  test('schema version is 103 and the migration list includes it', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(103));
    expect(AppDatabase.migrationVersions, contains(103));
  });

  test('backstop heals a database stranded past v103 by a parallel-branch '
      'version collision', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('''
          CREATE TABLE media (
            id TEXT NOT NULL PRIMARY KEY,
            file_path TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // No migration runs (user_version == currentSchemaVersion); only the
    // beforeOpen backstop can create the missing objects.
    final mediaCols = await db.customSelect("PRAGMA table_info('media')").get();
    expect(
      mediaCols.map((c) => c.read<String>('name')),
      contains('content_hash'),
      reason: 'media store columns must be re-asserted by beforeOpen',
    );
    final storeCols = await db
        .customSelect("PRAGMA table_info('media_stores')")
        .get();
    expect(storeCols, isNotEmpty, reason: 'media_stores must be re-asserted');
  });
}
