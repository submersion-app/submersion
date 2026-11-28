import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v395 (issue #4713): `documents.diver_id` nullable (a shared library
/// document belongs to no diver), `documents.shared_library_id`,
/// `document_pages.library_file_id` and the device-local
/// `shared_document_states` table. The floor does not move.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute('CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute(
        'CREATE TABLE documents (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL REFERENCES divers (id), '
        'site_id TEXT NULL REFERENCES dive_sites (id) ON DELETE SET NULL, '
        'type TEXT NOT NULL, title TEXT NOT NULL DEFAULT \'\', '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
        'hlc TEXT NULL)',
      );
      rawDb.execute(
        'CREATE TABLE document_pages (id TEXT NOT NULL PRIMARY KEY, '
        'document_id TEXT NOT NULL REFERENCES documents (id) '
        'ON DELETE CASCADE, page_index INTEGER NOT NULL, '
        'side TEXT NULL, file_name TEXT NOT NULL, mime_type TEXT NOT NULL, '
        'size_bytes INTEGER NOT NULL, bytes BLOB NOT NULL, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
        'hlc TEXT NULL)',
      );
      rawDb.execute(
        'CREATE TABLE document_tags (id TEXT NOT NULL PRIMARY KEY, '
        'document_id TEXT NOT NULL REFERENCES documents (id) '
        'ON DELETE CASCADE, tag_id TEXT NOT NULL, '
        'created_at INTEGER NOT NULL, hlc TEXT NULL)',
      );
      rawDb.execute("INSERT INTO divers (id) VALUES ('d1')");
      rawDb.execute("INSERT INTO dive_sites (id) VALUES ('s1')");
      rawDb.execute(
        'INSERT INTO documents (id, diver_id, site_id, type, title, '
        "created_at, updated_at, hlc) VALUES ('doc1', 'd1', 's1', 'map', "
        "'Access', 1, 2, 'h1')",
      );
      for (final (id, index) in [('p1', 0), ('p2', 1)]) {
        rawDb.execute(
          'INSERT INTO document_pages (id, document_id, page_index, '
          'file_name, mime_type, size_bytes, bytes, created_at, updated_at) '
          "VALUES ('$id', 'doc1', $index, '$id.pdf', 'application/pdf', 3, "
          "x'010203', 1, 2)",
        );
      }
      rawDb.execute(
        'INSERT INTO document_tags (id, document_id, tag_id, created_at) '
        "VALUES ('dt1', 'doc1', 't1', 1)",
      );
    },
  );

  Future<Map<String, int>> notNullOf(AppDatabase db, String table) async => {
    for (final r in await db.customSelect("PRAGMA table_info('$table')").get())
      r.read<String>('name'): r.read<int>('notnull'),
  };

  test('v395 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(395));
    expect(AppDatabase.migrationVersions, contains(395));
    expect(AppDatabase.minimumCompatibleSchemaVersion, 386);
  });

  test('v395 makes documents.diver_id nullable and keeps every row', () async {
    final db = AppDatabase(dbAt(387));
    addTearDown(db.close);
    final docs = await notNullOf(db, 'documents');
    expect(docs['diver_id'], 0);
    expect(docs.containsKey('shared_library_id'), isTrue);
    expect(
      (await notNullOf(db, 'document_pages')).containsKey('library_file_id'),
      isTrue,
    );
    final doc =
        (await db
                .customSelect(
                  'SELECT id, diver_id, site_id, type, title, created_at, '
                  'updated_at, hlc, shared_library_id FROM documents',
                )
                .getSingle())
            .data;
    expect(doc, {
      'id': 'doc1',
      'diver_id': 'd1',
      'site_id': 's1',
      'type': 'map',
      'title': 'Access',
      'created_at': 1,
      'updated_at': 2,
      'hlc': 'h1',
      'shared_library_id': null,
    });
    final pages = await db
        .customSelect('SELECT id, bytes FROM document_pages ORDER BY id')
        .get();
    expect(pages.map((r) => r.read<String>('id')), ['p1', 'p2']);
    expect(pages.first.data['bytes'], [1, 2, 3]);
    expect(
      await db.customSelect('SELECT id FROM document_tags').get(),
      hasLength(1),
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    expect(
      await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name = "
            "'shared_document_states'",
          )
          .get(),
      hasLength(1),
    );
  });

  test('a library document with no diver can be stored after v395', () async {
    final db = AppDatabase(dbAt(387));
    addTearDown(db.close);
    await db.customStatement(
      'INSERT INTO documents (id, diver_id, type, created_at, updated_at, '
      "shared_library_id) VALUES ('doc2', NULL, 'map', 1, 1, 'L')",
    );
    expect(
      (await db
              .customSelect("SELECT diver_id FROM documents WHERE id = 'doc2'")
              .getSingle())
          .data,
      {'diver_id': null},
    );
  });

  test('deleting a document still cascades to its pages after v395', () async {
    final db = AppDatabase(dbAt(387));
    addTearDown(db.close);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement("DELETE FROM documents WHERE id = 'doc1'");
    expect(
      await db.customSelect('SELECT id FROM document_pages').get(),
      isEmpty,
    );
  });
}
