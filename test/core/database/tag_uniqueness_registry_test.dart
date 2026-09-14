import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_uniqueness.dart';

/// A connection with no schema of its own and no migrations, so a test can
/// hand [collapseDuplicateTags] exactly the tables the v149 rung sees.
class _BareDb extends GeneratedDatabase {
  _BareDb(super.e);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

/// The duplicate-tag repair runs over the tag scope registry (issue #1942).
/// It runs from the v149 rung, long before v217 created `site_tags` and the
/// scope columns, so it must use only the schema that exists.
void main() {
  Future<List<String>> pairs(
    DatabaseConnectionUser db,
    String table,
    String parent,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT $parent AS p, tag_id FROM $table ORDER BY $parent, tag_id',
        )
        .get();
    return [
      for (final row in rows)
        '${row.read<String>('p')}|${row.read<String>('tag_id')}',
    ];
  }

  test('a v148 schema (no scope columns, no site_tags) collapses '
      'without error', () async {
    final db = _BareDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('''
      CREATE TABLE tags (
        id TEXT NOT NULL PRIMARY KEY,
        diver_id TEXT,
        name TEXT NOT NULL,
        color TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await db.customStatement('''
      CREATE TABLE dive_tags (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at) '
      "VALUES ('a', 'Wreck', 0, 0), ('b', ' wreck', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) VALUES '
      "('dt1', 'd1', 'b', 0), ('dt2', 'd1', 'a', 0), ('dt3', 'd2', 'b', 0), "
      "('orphan', 'd3', 'gone', 0)",
    );

    await collapseDuplicateTags(db);

    final tags = await db.customSelect('SELECT id, name FROM tags').get();
    expect(tags.map((r) => r.read<String>('id')), ['a']);
    expect(await pairs(db, 'dive_tags', 'dive_id'), [
      'd1|a',
      'd2|a',
      'd3|gone',
    ], reason: 'a link whose tag is already gone is left as it was');
  });

  test('a dive holding a loser and its survivor keeps one link while the '
      'dive_tags index stands', () async {
    // Before the registry the dive junction was repointed with a plain
    // UPDATE, which threw here on idx_dive_tags_dive_tag_unique.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at) '
      "VALUES ('a', 'Night', 0, 0), ('b', 'night', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
      "VALUES ('x', 'd1', 'a', 0), ('y', 'd1', 'b', 0)",
    );

    await collapseDuplicateTags(db);

    final links = await db
        .customSelect('SELECT id, tag_id FROM dive_tags')
        .get();
    expect(links.map((r) => (r.read<String>('id'), r.read<String>('tag_id'))), [
      ('x', 'a'),
    ]);
  });

  test('orphaned site and equipment links are swept while an orphaned dive '
      'link is kept', () async {
    // The repair has always swept site_tags rows whose tag is gone (#1849),
    // while dive_tags rows in that state survive untouched (v149). The
    // equipment junction follows its site twin.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('e1', 'Reg', 'regulator', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
      "VALUES ('dt', 'd1', 'gone', 0)",
    );
    await db.customStatement(
      'INSERT INTO site_tags (id, site_id, tag_id, created_at) '
      "VALUES ('st', 's1', 'gone', 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) '
      "VALUES ('et', 'e1', 'gone', 0)",
    );

    await collapseDuplicateTags(db);

    expect(await pairs(db, 'dive_tags', 'dive_id'), ['d1|gone']);
    expect(await pairs(db, 'site_tags', 'site_id'), isEmpty);
    expect(await pairs(db, 'equipment_tags', 'equipment_id'), isEmpty);
  });

  test('links on a losing tag move in every registry junction', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites) '
      "VALUES ('a', 'To try', 0, 0, 1, 0), ('b', 'to try', 0, 0, 0, 1)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
      "VALUES ('dt', 'd1', 'b', 0)",
    );
    await db.customStatement(
      'INSERT INTO site_tags (id, site_id, tag_id, created_at) '
      "VALUES ('st', 's1', 'b', 0)",
    );

    await collapseDuplicateTags(db);

    expect(await pairs(db, 'dive_tags', 'dive_id'), ['d1|a']);
    expect(await pairs(db, 'site_tags', 'site_id'), ['s1|a']);
    final survivor = await db
        .customSelect(
          'SELECT applies_to_dives AS d, applies_to_sites AS s FROM tags',
        )
        .getSingle();
    expect((survivor.read<int>('d'), survivor.read<int>('s')), (1, 1));
  });
}
