import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v184 (issue #1451): `dive_data_sources.merge_source_slot`, the marker a
/// sequential Combine stamps on the provenance rows it carries so the display
/// collapses the halves of one dive back into a single source.
///
/// Dives combined before the marker existed have to be recognized by shape,
/// and the shape has to exclude a two-computer consolidation: collapsing one
/// of those would put the chart back to drawing the interleaved union of both
/// computers, which is issue #543. The discriminator is time. Combined halves
/// are consecutive slices of one timeline, so their entry/exit spans are
/// disjoint; two computers recording one dive cover the same minutes.
void main() {
  // Stamped at 183 so ONLY the v184 step runs, isolating what is asserted.
  NativeDatabase setupDb(void Function(dynamic rawDb) seed) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 183');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        // The pre-v184 shape: every column the backfill reads, and no
        // merge_source_slot. entry_time/exit_time are drift dateTime
        // columns, stored as unix seconds.
        rawDb.execute('''
          CREATE TABLE dive_data_sources (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            is_primary INTEGER NOT NULL DEFAULT 0,
            imported_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            entry_time INTEGER,
            exit_time INTEGER,
            time_offset_seconds INTEGER
          )
        ''');
        seed(rawDb);
      },
    );
  }

  void insertSource(
    dynamic rawDb,
    String id,
    String diveId, {
    bool isPrimary = false,
    String? computerId,
    int? entry,
    int? exit,
    int? timeOffsetSeconds,
  }) {
    rawDb.execute(
      'INSERT INTO dive_data_sources '
      '(id, dive_id, computer_id, is_primary, imported_at, created_at, '
      'entry_time, exit_time, time_offset_seconds) '
      'VALUES (?, ?, ?, ?, 0, 0, ?, ?, ?)',
      [
        id,
        diveId,
        computerId,
        isPrimary ? 1 : 0,
        entry,
        exit,
        timeOffsetSeconds,
      ],
    );
  }

  Future<Map<String, int?>> slots(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT id, merge_source_slot FROM dive_data_sources ORDER BY id',
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('id'): r.readNullable<int>('merge_source_slot'),
    };
  }

  test('v184 is present in the migration ladder', () {
    // v184 is now a past migration; the latest-version tripwire lives in the
    // newest migration's test (migration_v191_plan_ascent_rates_test.dart),
    // so assert membership rather than equality.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(184));
    expect(AppDatabase.migrationVersions, contains(184));
  });

  test('adds merge_source_slot to dive_data_sources', () async {
    final db = AppDatabase(setupDb((_) {}));
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_data_sources')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      contains('merge_source_slot'),
    );
  });

  test('marks the rows of a dive combined before the marker existed', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('combined')");
        // Two file imports, no computer to collide on, consecutive spans,
        // neither primary: exactly what DiveMergeService.apply left behind.
        insertSource(rawDb, 'src-first', 'combined', entry: 0, exit: 1800);
        insertSource(rawDb, 'src-second', 'combined', entry: 2100, exit: 3600);
      }),
    );
    addTearDown(db.close);

    expect(await slots(db), {'src-first': 0, 'src-second': 0});
  });

  test('leaves a two-computer consolidation alone (#543)', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('consolidated')");
        // Overlapping spans: two recordings of the same minutes. Neither row
        // is primary, so the primary test alone would have collapsed them
        // and sent the chart back to drawing the union of both computers.
        insertSource(
          rawDb,
          'src-a',
          'consolidated',
          computerId: 'dc-a',
          entry: 0,
          exit: 3600,
        );
        insertSource(
          rawDb,
          'src-b',
          'consolidated',
          computerId: 'dc-b',
          entry: 60,
          exit: 3500,
        );
      }),
    );
    addTearDown(db.close);

    expect(await slots(db), {'src-a': null, 'src-b': null});
  });

  test('leaves a consolidation whose clocks disagree alone (#543)', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('shifted')");
        // Two recordings of the same dive, no computer to collide on, and a
        // secondary whose clock was two hours out. Consolidation shifts the
        // SAMPLES by time_offset_seconds but copies entry_time/exit_time
        // verbatim, so the stored spans do not overlap even though the two
        // rows cover the same minutes. The disjointness test alone would
        // read that as a Combine and collapse both to one chip.
        insertSource(rawDb, 'src-a', 'shifted', entry: 0, exit: 3600);
        insertSource(
          rawDb,
          'src-b',
          'shifted',
          entry: 7200,
          exit: 10800,
          timeOffsetSeconds: -7200,
        );
      }),
    );
    addTearDown(db.close);

    expect(await slots(db), {'src-a': null, 'src-b': null});
  });

  test('leaves a dive that still has a primary source alone', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('imported')");
        insertSource(
          rawDb,
          'src-primary',
          'imported',
          isPrimary: true,
          entry: 0,
          exit: 1800,
        );
        insertSource(rawDb, 'src-extra', 'imported', entry: 2100, exit: 3600);
      }),
    );
    addTearDown(db.close);

    expect(await slots(db), {'src-extra': null, 'src-primary': null});
  });

  test('leaves an ordinary single-source dive alone', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('ordinary')");
        insertSource(rawDb, 'src-only', 'ordinary', entry: 0, exit: 1800);
      }),
    );
    addTearDown(db.close);

    expect(await slots(db), {'src-only': null});
  });

  test('leaves rows that cannot be classified alone', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('untimed')");
        // No entry/exit times: nothing says whether these halves are
        // consecutive or competing, so they keep today's behavior.
        insertSource(rawDb, 'src-x', 'untimed');
        insertSource(rawDb, 'src-y', 'untimed', entry: 2100, exit: 3600);
      }),
    );
    addTearDown(db.close);

    expect(await slots(db), {'src-x': null, 'src-y': null});
  });

  test('marks a dive combined from three segments', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('triple')");
        insertSource(rawDb, 'src-1', 'triple', entry: 0, exit: 600);
        insertSource(rawDb, 'src-2', 'triple', entry: 700, exit: 1300);
        insertSource(rawDb, 'src-3', 'triple', entry: 1400, exit: 2000);
      }),
    );
    addTearDown(db.close);

    expect(await slots(db), {'src-1': 0, 'src-2': 0, 'src-3': 0});
  });

  test('leaves a dive where any pair overlaps alone', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('mixed')");
        // Two consecutive halves plus a third source covering the gap
        // between them. One overlap is enough to say this is not a plain
        // sequential combine, so nothing here is marked.
        insertSource(rawDb, 'src-1', 'mixed', entry: 0, exit: 1800);
        insertSource(rawDb, 'src-2', 'mixed', entry: 2100, exit: 3600);
        insertSource(rawDb, 'src-3', 'mixed', entry: 1700, exit: 2200);
      }),
    );
    addTearDown(db.close);

    expect(await slots(db), {'src-1': null, 'src-2': null, 'src-3': null});
  });

  test('treats halves that touch at the boundary as consecutive', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('touching')");
        insertSource(rawDb, 'src-1', 'touching', entry: 0, exit: 1800);
        insertSource(rawDb, 'src-2', 'touching', entry: 1800, exit: 3600);
      }),
    );
    addTearDown(db.close);

    expect(await slots(db), {'src-1': 0, 'src-2': 0});
  });

  test('marks only the qualifying dive when several shapes coexist', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        for (final id in ['combined', 'consolidated']) {
          rawDb.execute('INSERT INTO dives (id) VALUES (?)', [id]);
        }
        insertSource(rawDb, 'src-first', 'combined', entry: 0, exit: 1800);
        insertSource(rawDb, 'src-second', 'combined', entry: 2100, exit: 3600);
        insertSource(rawDb, 'src-a', 'consolidated', entry: 0, exit: 3600);
        insertSource(rawDb, 'src-b', 'consolidated', entry: 60, exit: 3500);
      }),
    );
    addTearDown(db.close);

    expect(await slots(db), {
      'src-a': null,
      'src-b': null,
      'src-first': 0,
      'src-second': 0,
    });
  });
}
