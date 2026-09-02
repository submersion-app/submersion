import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_type_uniqueness.dart';

/// v178 (duplicate dive types, issue #1360): collapses `dive_dive_types` rows
/// that share a (dive, dive type) pair, then creates the unique index that
/// stops the producers coming back.
///
/// This is the same repair `dive_tags` got in v149 for issue #1032. The two
/// junctions are structural twins -- surrogate uuid primary key, no constraint
/// on the pair the row actually means -- and only one of them was ever fixed.
///
/// The ordering is the point: creating a unique index while ties still exist
/// aborts the whole migration and leaves the database unopenable (the v148
/// lesson). Every case below therefore asserts the surviving rows AND that the
/// database opened at all.
void main() {
  // Stamped at 177 so ONLY the v178 step runs, isolating what is asserted.
  NativeDatabase setupDb(void Function(dynamic rawDb) seed) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 177');
        // `dives` is required, not decorative: dive_dive_types.dive_id is a
        // foreign key into it, and under PRAGMA foreign_keys = ON any DML on a
        // table whose FK parent is missing fails outright.
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE dive_dive_types (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            dive_type_id TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        seed(rawDb);
      },
    );
  }

  void insertRow(
    dynamic rawDb,
    String id,
    String diveId,
    String diveTypeId, {
    int createdAt = 1000,
  }) {
    rawDb.execute(
      'INSERT INTO dive_dive_types (id, dive_id, dive_type_id, created_at) '
      'VALUES (?, ?, ?, ?)',
      [id, diveId, diveTypeId, createdAt],
    );
  }

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  Future<List<String>> pairs(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT dive_id, dive_type_id FROM dive_dive_types '
          'ORDER BY dive_id, dive_type_id',
        )
        .get();
    return rows
        .map(
          (r) =>
              '${r.read<String>('dive_id')}|${r.read<String>('dive_type_id')}',
        )
        .toList();
  }

  Future<List<String>> rowIds(AppDatabase db) async {
    final rows = await db
        .customSelect('SELECT id FROM dive_dive_types ORDER BY id')
        .get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  test('creates the dive-type junction uniqueness index', () async {
    final db = AppDatabase(setupDb((_) {}));
    addTearDown(db.close);

    expect(await indexNames(db), contains(kDiveDiveTypesUniqueIndexName));
  });

  test('collapses duplicate rows for the same dive and type', () async {
    // The #1360 shape: two devices each ran the v92 seed, which mints a fresh
    // random id per row, so the same (dive, type) pair landed twice.
    final db = AppDatabase(
      setupDb((rawDb) {
        insertRow(rawDb, 'seed-a', 'dive-1', 'shore', createdAt: 1782360179000);
        insertRow(rawDb, 'seed-b', 'dive-1', 'shore', createdAt: 1782536310000);
      }),
    );
    addTearDown(db.close);

    expect(await pairs(db), ['dive-1|shore']);
  });

  test('rows tied on created_at still collapse to exactly one', () async {
    // The tie trap. `created_at` is epoch MILLISECONDS and the v92 seed writes
    // every row inside one `strftime('now')` second, so ties are the norm here
    // rather than an edge case. A `created_at > MIN(created_at)` dedupe leaves
    // every tied row in place and the index below then aborts the migration.
    final db = AppDatabase(
      setupDb((rawDb) {
        insertRow(rawDb, 'row-a', 'dive-1', 'wreck', createdAt: 1000);
        insertRow(rawDb, 'row-b', 'dive-1', 'wreck', createdAt: 1000);
        insertRow(rawDb, 'row-c', 'dive-1', 'wreck', createdAt: 1000);
      }),
    );
    addTearDown(db.close);

    expect(await pairs(db), ['dive-1|wreck']);
    expect(
      await indexNames(db),
      contains(kDiveDiveTypesUniqueIndexName),
      reason: 'an aborted CREATE UNIQUE INDEX is invisible in a row count',
    );
  });

  test('keeps the oldest row of a duplicated pair', () async {
    // Order matters downstream: the representative type is whichever junction
    // row reads back first, so the survivor must be the one already showing.
    final db = AppDatabase(
      setupDb((rawDb) {
        insertRow(rawDb, 'newer', 'dive-1', 'shore', createdAt: 2000);
        insertRow(rawDb, 'older', 'dive-1', 'shore', createdAt: 1000);
      }),
    );
    addTearDown(db.close);

    expect(await rowIds(db), ['older']);
  });

  test('the survivor does not depend on local insertion order', () async {
    // Convergence, not cosmetics. `rowid` is device-local: two devices that
    // hold the SAME two rows can have inserted them in opposite orders, so a
    // rowid tie-break leaves each keeping a different id. Both would then
    // display one badge and look fixed -- but sync deletions are keyed on id,
    // so a later "remove this type" tombstones an id the peer does not have
    // and the removal never propagates. The tie-break must be a property of
    // the rows themselves.
    Future<String> survivorFor(List<String> insertionOrder) async {
      final db = AppDatabase(
        setupDb((rawDb) {
          for (final id in insertionOrder) {
            insertRow(rawDb, id, 'dive-1', 'shore', createdAt: 1000);
          }
        }),
      );
      addTearDown(db.close);
      return (await rowIds(db)).single;
    }

    expect(
      await survivorFor(['id-aaa', 'id-zzz']),
      await survivorFor(['id-zzz', 'id-aaa']),
    );
  });

  test('different types on one dive all survive', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertRow(rawDb, 'row-a', 'dive-1', 'recreational');
        insertRow(rawDb, 'row-b', 'dive-1', 'shore');
        insertRow(rawDb, 'row-c', 'dive-1', 'night');
      }),
    );
    addTearDown(db.close);

    expect(await pairs(db), [
      'dive-1|night',
      'dive-1|recreational',
      'dive-1|shore',
    ]);
  });

  test('the same type on different dives stays distinct', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertRow(rawDb, 'row-a', 'dive-1', 'shore');
        insertRow(rawDb, 'row-b', 'dive-2', 'shore');
      }),
    );
    addTearDown(db.close);

    expect(await pairs(db), ['dive-1|shore', 'dive-2|shore']);
  });

  test('is idempotent when the database is already clean', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertRow(rawDb, 'row-a', 'dive-1', 'shore');
      }),
    );
    addTearDown(db.close);

    expect(await rowIds(db), ['row-a']);
    expect(await indexNames(db), contains(kDiveDiveTypesUniqueIndexName));
  });

  test('rebuilds an index left over from an earlier keying', () async {
    // CREATE UNIQUE INDEX IF NOT EXISTS is a no-op against an index of the
    // same NAME whatever its definition, so a database that ran a pre-release
    // build of this version would silently keep the older keying forever.
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute(
          'CREATE UNIQUE INDEX $kDiveDiveTypesUniqueIndexName '
          'ON dive_dive_types(id)',
        );
        insertRow(rawDb, 'row-a', 'dive-1', 'shore');
        insertRow(rawDb, 'row-b', 'dive-1', 'shore');
      }),
    );
    addTearDown(db.close);

    final sql = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE name = '"
          "$kDiveDiveTypesUniqueIndexName'",
        )
        .getSingle();
    expect(sql.read<String>('sql'), contains('dive_type_id'));
    expect(await pairs(db), [
      'dive-1|shore',
    ], reason: 'the rows the old index allowed must still be collapsed');
  });

  test('the v178 migration is registered in the migration list', () {
    expect(AppDatabase.migrationVersions, contains(178));
  });
}
