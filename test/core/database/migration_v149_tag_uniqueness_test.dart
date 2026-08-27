import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v149 (duplicate tags, issue #1032): collapses `tags` rows that share a
/// (diver scope, case-folded name), repoints `dive_tags` at the survivor,
/// collapses duplicate (dive_id, tag_id) junction rows, and only then creates
/// the two unique indexes that stop both producers coming back.
///
/// The ordering is the point: creating a unique index while ties still exist
/// aborts the whole migration and leaves the database unopenable (the v148
/// lesson). Every case below therefore asserts the surviving rows AND that the
/// database opened at all.
void main() {
  // Stamped at 148 so ONLY the v149 step runs, isolating what is asserted.
  NativeDatabase setupDb(void Function(dynamic rawDb) seed) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 148');
        rawDb.execute('''
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
        rawDb.execute('''
          CREATE TABLE dive_tags (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        seed(rawDb);
      },
    );
  }

  void insertTag(
    dynamic rawDb,
    String id,
    String name, {
    String? diverId,
    int createdAt = 1000,
  }) {
    rawDb.execute(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [id, diverId, name, createdAt, createdAt],
    );
  }

  void insertDiveTag(dynamic rawDb, String id, String diveId, String tagId) {
    rawDb.execute(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
      'VALUES (?, ?, ?, ?)',
      [id, diveId, tagId, 1000],
    );
  }

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  Future<List<String>> tagIds(AppDatabase db) async {
    final rows = await db.customSelect('SELECT id FROM tags ORDER BY id').get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  Future<List<String>> diveTagPairs(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT dive_id, tag_id FROM dive_tags ORDER BY dive_id, tag_id',
        )
        .get();
    return rows
        .map((r) => '${r.read<String>('dive_id')}|${r.read<String>('tag_id')}')
        .toList();
  }

  test('creates both tag uniqueness indexes', () async {
    final db = AppDatabase(setupDb((_) {}));
    addTearDown(db.close);

    final names = await indexNames(db);
    expect(names, contains('idx_tags_diver_name_unique'));
    expect(names, contains('idx_dive_tags_dive_tag_unique'));
  });

  test('collapses same-name tags onto the lexically lowest id', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        // The #1032 shape: two devices each minted their own uuid for the
        // same auto-generated import tag name.
        insertTag(rawDb, 'tag-b', 'Perdix Import 2026-08-13', diverId: 'd1');
        insertTag(rawDb, 'tag-a', 'Perdix Import 2026-08-13', diverId: 'd1');
        insertDiveTag(rawDb, 'dt-1', 'dive-1', 'tag-b');
        insertDiveTag(rawDb, 'dt-2', 'dive-2', 'tag-a');
      }),
    );
    addTearDown(db.close);

    expect(await tagIds(db), ['tag-a']);
    expect(await diveTagPairs(db), ['dive-1|tag-a', 'dive-2|tag-a']);
  });

  test('collapse is case-insensitive', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertTag(rawDb, 'tag-a', 'Wreck', diverId: 'd1');
        insertTag(rawDb, 'tag-b', 'wreck', diverId: 'd1');
        insertDiveTag(rawDb, 'dt-1', 'dive-1', 'tag-b');
      }),
    );
    addTearDown(db.close);

    expect(await tagIds(db), ['tag-a']);
    expect(await diveTagPairs(db), ['dive-1|tag-a']);
  });

  test('collapse ignores surrounding whitespace', () async {
    // Legacy rows can carry padding: writers matched on a trimmed name but
    // stored the raw one, so " Wreck" and "Wreck" were two rows every lookup
    // treated as one (PR #1033 review).
    final db = AppDatabase(
      setupDb((rawDb) {
        insertTag(rawDb, 'tag-a', ' Wreck ', diverId: 'd1');
        insertTag(rawDb, 'tag-b', 'wreck', diverId: 'd1');
        insertDiveTag(rawDb, 'dt-1', 'dive-1', 'tag-b');
      }),
    );
    addTearDown(db.close);

    expect(await tagIds(db), ['tag-a']);
    expect(await diveTagPairs(db), ['dive-1|tag-a']);
  });

  test('the surviving name is stored trimmed', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertTag(rawDb, 'tag-a', '  Wreck  ', diverId: 'd1');
      }),
    );
    addTearDown(db.close);

    final rows = await db.customSelect('SELECT name FROM tags').get();
    expect(
      rows.single.read<String>('name'),
      'Wreck',
      reason: 'what is stored must match what every lookup compares against',
    );
  });

  test('NULL diver_id is one scope, not one scope per row', () async {
    // A plain UNIQUE(diver_id, name) index would leave these two alone --
    // SQLite treats NULLs as distinct inside a unique index -- so the
    // unassigned-diver rows would keep duplicating forever.
    final db = AppDatabase(
      setupDb((rawDb) {
        insertTag(rawDb, 'tag-a', 'Night');
        insertTag(rawDb, 'tag-b', 'Night');
      }),
    );
    addTearDown(db.close);

    expect(await tagIds(db), ['tag-a']);
  });

  test('same name under different divers stays distinct', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertTag(rawDb, 'tag-a', 'Wreck', diverId: 'd1');
        insertTag(rawDb, 'tag-b', 'Wreck', diverId: 'd2');
        insertTag(rawDb, 'tag-c', 'Wreck');
      }),
    );
    addTearDown(db.close);

    expect(await tagIds(db), ['tag-a', 'tag-b', 'tag-c']);
  });

  test('collapses duplicate junction rows for the same dive and tag', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertTag(rawDb, 'tag-a', 'Wreck', diverId: 'd1');
        // Re-running an import blind-inserted a fresh uuid every time.
        insertDiveTag(rawDb, 'dt-1', 'dive-1', 'tag-a');
        insertDiveTag(rawDb, 'dt-2', 'dive-1', 'tag-a');
        insertDiveTag(rawDb, 'dt-3', 'dive-1', 'tag-a');
      }),
    );
    addTearDown(db.close);

    expect(await diveTagPairs(db), ['dive-1|tag-a']);
  });

  test('repointing that collides collapses instead of aborting', () async {
    // The tie trap: dive-1 carries BOTH duplicate tags, so repointing the
    // loser produces two identical (dive-1, tag-a) rows. A dedupe that ran
    // before the repoint -- or not at all -- would leave that tie in place
    // and the unique index below would abort the whole migration.
    final db = AppDatabase(
      setupDb((rawDb) {
        insertTag(rawDb, 'tag-a', 'Wreck', diverId: 'd1');
        insertTag(rawDb, 'tag-b', 'Wreck', diverId: 'd1');
        insertDiveTag(rawDb, 'dt-1', 'dive-1', 'tag-a');
        insertDiveTag(rawDb, 'dt-2', 'dive-1', 'tag-b');
      }),
    );
    addTearDown(db.close);

    expect(await tagIds(db), ['tag-a']);
    expect(await diveTagPairs(db), ['dive-1|tag-a']);
    expect(await indexNames(db), contains('idx_dive_tags_dive_tag_unique'));
  });

  test('a junction row whose tag is already gone survives untouched', () async {
    // The repoint must never resolve to NULL: dive_tags.tag_id is NOT NULL,
    // so a blanket UPDATE ... SET tag_id = (subquery) would abort here.
    final db = AppDatabase(
      setupDb((rawDb) {
        insertDiveTag(rawDb, 'dt-orphan', 'dive-1', 'tag-missing');
      }),
    );
    addTearDown(db.close);

    expect(await diveTagPairs(db), ['dive-1|tag-missing']);
  });

  test('rebuilds an index left over from an earlier keying', () async {
    // CREATE UNIQUE INDEX IF NOT EXISTS is a no-op against an index of the
    // same NAME whatever its definition, so a database that ran a pre-release
    // build of v149 would silently keep the older keying forever.
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute(
          'CREATE UNIQUE INDEX idx_tags_diver_name_unique '
          "ON tags(COALESCE(diver_id, ''), lower(name))",
        );
        insertTag(rawDb, 'tag-a', ' Wreck ', diverId: 'd1');
        insertTag(rawDb, 'tag-b', 'wreck', diverId: 'd1');
      }),
    );
    addTearDown(db.close);

    final sql = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE name = 'idx_tags_diver_name_unique'",
        )
        .getSingle();
    expect(sql.read<String>('sql'), contains('trim'));
    expect(await tagIds(db), [
      'tag-a',
    ], reason: 'the rows the old index allowed must still be collapsed');
  });

  test('is idempotent when the database is already clean', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertTag(rawDb, 'tag-a', 'Wreck', diverId: 'd1');
        insertDiveTag(rawDb, 'dt-1', 'dive-1', 'tag-a');
      }),
    );
    addTearDown(db.close);

    expect(await tagIds(db), ['tag-a']);
    expect(await diveTagPairs(db), ['dive-1|tag-a']);
  });
}
