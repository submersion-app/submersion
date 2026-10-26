import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_uniqueness.dart';

/// Schema v309: media and document tags (issue #1970).
void main() {
  /// A v308 database: `tags` with the dive, site and equipment scope flags,
  /// and neither `media_tags` nor `document_tags`.
  NativeDatabase setupDb({int userVersion = 308, bool withParents = true}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        if (withParents) {
          rawDb.execute('CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY)');
          rawDb.execute(
            'CREATE TABLE documents (id TEXT NOT NULL PRIMARY KEY)',
          );
        }
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT,
            applies_to_dives INTEGER NOT NULL DEFAULT 1
              CHECK (applies_to_dives IN (0, 1)),
            applies_to_sites INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_sites IN (0, 1)),
            applies_to_equipment INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_equipment IN (0, 1))
          )
        ''');
        rawDb.execute(
          "INSERT INTO tags (id, name, created_at, updated_at, "
          "applies_to_dives, applies_to_sites, applies_to_equipment) "
          "VALUES ('t1', 'Wreck', 0, 0, 1, 1, 1)",
        );
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<List<Map<String, Object?>>> tableInfo(
    AppDatabase db,
    String table,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return [
      for (final c in cols)
        {
          'name': c.data['name'],
          'type': c.data['type'],
          'notnull': c.data['notnull'],
          'dflt_value': c.data['dflt_value'],
          'pk': c.data['pk'],
        },
    ];
  }

  Future<String?> ddlOf(AppDatabase db, String type, String name) async {
    final rows = await db
        .customSelect(
          'SELECT sql FROM sqlite_master WHERE type = ? AND name = ?',
          variables: [Variable<String>(type), Variable<String>(name)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String?>('sql');
  }

  test('v309 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(309));
    expect(AppDatabase.migrationVersions, contains(309));
    expect(
      AppDatabase.migrationStepCount(308),
      AppDatabase.migrationStepCount(309) + 1,
    );
    // Additive rung: the sync compatibility floor does not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 308);
  });

  test('adds both junctions', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'media_tags'),
      containsAll(<String>['id', 'media_id', 'tag_id', 'created_at', 'hlc']),
    );
    expect(
      await columnsOf(db, 'document_tags'),
      containsAll(<String>['id', 'document_id', 'tag_id', 'created_at', 'hlc']),
    );
  });

  test('existing tags keep their scopes and gain neither new one', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          'SELECT applies_to_dives, applies_to_sites, applies_to_equipment, '
          "applies_to_media, applies_to_documents FROM tags WHERE id = 't1'",
        )
        .getSingle();
    expect(row.read<int>('applies_to_dives'), 1);
    expect(row.read<int>('applies_to_sites'), 1);
    expect(row.read<int>('applies_to_equipment'), 1);
    expect(row.read<int>('applies_to_media'), 0);
    expect(row.read<int>('applies_to_documents'), 0);
  });

  test('creates both unique indexes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(await ddlOf(db, 'index', kMediaTagsUniqueIndexName), isNotNull);
    expect(await ddlOf(db, 'index', kDocumentTagsUniqueIndexName), isNotNull);
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(fresh.close);

    for (final table in const ['media_tags', 'document_tags']) {
      expect(
        await tableInfo(upgraded, table),
        await tableInfo(fresh, table),
        reason: table,
      );
      expect(
        await ddlOf(upgraded, 'table', table),
        await ddlOf(fresh, 'table', table),
        reason: table,
      );
    }
    for (final index in const [
      kMediaTagsUniqueIndexName,
      kDocumentTagsUniqueIndexName,
    ]) {
      expect(
        await ddlOf(upgraded, 'index', index),
        await ddlOf(fresh, 'index', index),
        reason: index,
      );
    }
    Map<String, Object?> flag(List<Map<String, Object?>> cols, String name) =>
        cols.singleWhere((c) => c['name'] == name);
    for (final column in const ['applies_to_media', 'applies_to_documents']) {
      expect(
        flag(await tableInfo(upgraded, 'tags'), column),
        flag(await tableInfo(fresh, 'tags'), column),
        reason: column,
      );
    }
  });

  test(
    'a database stamped v309 without the schema heals in beforeOpen',
    () async {
      final db = AppDatabase(setupDb(userVersion: 309));
      addTearDown(db.close);

      expect(
        await columnsOf(db, 'tags'),
        containsAll(<String>['applies_to_media', 'applies_to_documents']),
      );
      expect(await columnsOf(db, 'media_tags'), contains('media_id'));
      expect(await columnsOf(db, 'document_tags'), contains('document_id'));
      expect(await ddlOf(db, 'index', kMediaTagsUniqueIndexName), isNotNull);
      expect(await ddlOf(db, 'index', kDocumentTagsUniqueIndexName), isNotNull);
    },
  );

  test('a fixture without the parent tables skips the junctions', () async {
    final db = AppDatabase(setupDb(withParents: false));
    addTearDown(db.close);

    expect(await columnsOf(db, 'media_tags'), isEmpty);
    expect(await columnsOf(db, 'document_tags'), isEmpty);
    expect(await columnsOf(db, 'tags'), contains('applies_to_media'));
  });

  test('a duplicate pair is rejected by each index', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'Ana', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO media (id, file_path, file_type, taken_at, created_at, "
      "updated_at) VALUES ('m1', '', 'photo', 0, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO documents (id, diver_id, type, created_at, updated_at) "
      "VALUES ('doc1', 'd1', 'other', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('t1', 'Wreck', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO media_tags (id, media_id, tag_id, created_at) "
      "VALUES ('a', 'm1', 't1', 0)",
    );
    await db.customStatement(
      "INSERT INTO document_tags (id, document_id, tag_id, created_at) "
      "VALUES ('a', 'doc1', 't1', 0)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO media_tags (id, media_id, tag_id, created_at) "
        "VALUES ('b', 'm1', 't1', 0)",
      ),
      throwsA(anything),
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO document_tags (id, document_id, tag_id, created_at) "
        "VALUES ('b', 'doc1', 't1', 0)",
      ),
      throwsA(anything),
    );
  });

  test(
    'assertions collapse duplicates on a database that lost the index',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);
      await db.customStatement('DROP INDEX $kMediaTagsUniqueIndexName');
      await db.customStatement(
        "INSERT INTO media (id, file_path, file_type, taken_at, created_at, "
        "updated_at) VALUES ('m1', '', 'photo', 0, 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at) "
        "VALUES ('t1', 'Wreck', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO media_tags (id, media_id, tag_id, created_at) "
        "VALUES ('b', 'm1', 't1', 5), ('a', 'm1', 't1', 1)",
      );

      await assertMediaAndDocumentTagUniqueness(db);

      final rows = await db.customSelect('SELECT id FROM media_tags').get();
      expect(rows.map((r) => r.read<String>('id')), ['a']);
      expect(await ddlOf(db, 'index', kMediaTagsUniqueIndexName), isNotNull);
    },
  );
}
