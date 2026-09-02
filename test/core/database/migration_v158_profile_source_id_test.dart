import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

/// Pre-v158 dive_profiles shape: samples are correlated to a data source only
/// through computer_id, which is null for every file import and manual entry.
const _preV158DiveProfiles = '''
  CREATE TABLE dive_profiles (
    id TEXT NOT NULL PRIMARY KEY,
    dive_id TEXT NOT NULL,
    computer_id TEXT,
    is_primary INTEGER NOT NULL DEFAULT 1,
    timestamp INTEGER NOT NULL,
    depth REAL NOT NULL
  )
''';

const _preV158DiveDataSources = '''
  CREATE TABLE dive_data_sources (
    id TEXT NOT NULL PRIMARY KEY,
    dive_id TEXT NOT NULL,
    computer_id TEXT,
    is_primary INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER
  )
''';

/// FK parents the v182/v183 rungs' series tables need to exist at all
/// (_assertProfileSeriesSchema), same as a real database has carried since
/// long before v157. comp-99 is deliberately never registered here: it is
/// the "computer_id matching no source" case _seedMixedDive sets up.
void _seedFkParents(dynamic rawDb) {
  rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
  rawDb.execute('CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)');
  rawDb.execute("INSERT INTO dives (id) VALUES ('d1'), ('d2')");
  rawDb.execute("INSERT INTO dive_computers (id) VALUES ('comp-1')");
}

/// A dive with one computer source and one file-imported source, plus the
/// four profile shapes the backfill has to sort out.
void _seedMixedDive(dynamic rawDb) {
  rawDb.execute(
    "INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, "
    "created_at) VALUES ('src-computer', 'd1', 'comp-1', 0, 100)",
  );
  rawDb.execute(
    "INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, "
    "created_at) VALUES ('src-file', 'd1', NULL, 1, 200)",
  );

  void profile(String id, String diveId, String? computerId) {
    final computer = computerId == null ? 'NULL' : "'$computerId'";
    rawDb.execute(
      "INSERT INTO dive_profiles (id, dive_id, computer_id, timestamp, depth) "
      "VALUES ('$id', '$diveId', $computer, 60, 20.0)",
    );
  }

  profile('p-computer', 'd1', 'comp-1');
  profile('p-null', 'd1', null);
  profile('p-unmatched', 'd1', 'comp-99');
  // A dive with no data-source rows at all: nothing to attribute to.
  profile('p-orphan', 'd2', null);
}

/// The packed dive_profile_series rows for [diveId] (v182/v183 pack the
/// legacy dive_profiles rows into these and drop the legacy table). Each
/// group of profile rows that shared a (computer_id, source_id, is_primary)
/// key becomes one series, so tests look a group up by that key rather than
/// by any one profile row's id.
Future<List<Map<String, Object?>>> _seriesRowsFor(
  AppDatabase db,
  String diveId,
) async {
  final rows = await db
      .customSelect(
        'SELECT * FROM dive_profile_series WHERE dive_id = ?',
        variables: [Variable<String>(diveId)],
      )
      .get();
  return rows.map((r) => r.data).toList();
}

Map<String, Object?> _seriesWhere(
  List<Map<String, Object?>> rows, {
  String? computerId,
  String? sourceId,
}) => rows.singleWhere(
  (r) => r['computer_id'] == computerId && r['source_id'] == sourceId,
);

void main() {
  const codec = ProfileSeriesCodec();

  test('v158 adds the owning-source column, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 157');
        _seedFkParents(rawDb);
        rawDb.execute(_preV158DiveProfiles);
        rawDb.execute(_preV158DiveDataSources);
        _seedMixedDive(rawDb);
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // dive_profiles is gone by the time this resolves; the ladder drops it
    // once v183 has packed everything into dive_profile_series, which
    // carries source_id as a series-level column.
    final rows = await _seriesRowsFor(db, 'd1');
    final computerSeries = _seriesWhere(
      rows,
      computerId: 'comp-1',
      sourceId: 'src-computer',
    );
    final samples = codec.decode(computerSeries['samples'] as dynamic);
    expect(samples, [const ProfileSample(timestamp: 60, depth: 20.0)]);
  });

  test('v158 attributes rows the way the pre-v158 read path did', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 157');
        _seedFkParents(rawDb);
        rawDb.execute(_preV158DiveProfiles);
        rawDb.execute(_preV158DiveDataSources);
        _seedMixedDive(rawDb);
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final rows = await _seriesRowsFor(db, 'd1');

    // A matching computer_id names the owner outright.
    expect(
      _seriesWhere(rows, computerId: 'comp-1', sourceId: 'src-computer'),
      isNotNull,
    );

    // Null computer_id (p-null) and a computer_id matching no source
    // (p-unmatched, comp-99 is never registered) both resolve to a null
    // computer at pack time and land on the primary source: the convention
    // getProfilesByDataSource has always implemented.
    // Reproducing it here is what keeps the upgrade from moving anyone's
    // samples between sources; it also merges them into one series, since
    // they now share both key components.
    expect(
      rows.where((r) => r['computer_id'] == null),
      hasLength(1),
      reason:
          'p-null and p-unmatched resolve to the same null computer_id and '
          'must land on the same source_id, or they would be two series '
          'instead of one',
    );
    final nullComputerSeries = _seriesWhere(
      rows,
      computerId: null,
      sourceId: 'src-file',
    );
    expect(
      codec.decode(nullComputerSeries['samples'] as dynamic),
      hasLength(1),
      reason:
          'p-null and p-unmatched merge into one series, and their samples '
          'are identical (both timestamp 60, depth 20.0), so the exact-'
          'duplicate dedupe collapses them to one',
    );

    // Nothing to attribute to: left null, and the code falls back to the
    // legacy convention for these.
    final orphanRows = await _seriesRowsFor(db, 'd2');
    expect(
      _seriesWhere(orphanRows, computerId: null, sourceId: null),
      isNotNull,
    );
  });

  test('migration list includes v158 and schema is at least 158', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(158));
    expect(AppDatabase.migrationVersions, contains(158));
  });

  test('v158 is idempotent when source_id already exists', () async {
    // An interrupted upgrade, or a database that reached this version number
    // from a parallel branch, leaves the column already added. The PRAGMA
    // guard must skip the ALTER rather than fail on a duplicate column, and
    // the backfill must not move a row that already has an owner.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 157');
        _seedFkParents(rawDb);
        rawDb.execute(_preV158DiveProfiles);
        rawDb.execute(_preV158DiveDataSources);
        rawDb.execute('ALTER TABLE dive_profiles ADD COLUMN source_id TEXT');
        _seedMixedDive(rawDb);
        rawDb.execute(
          "UPDATE dive_profiles SET source_id = 'src-computer' "
          "WHERE id = 'p-null'",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final rows = await _seriesRowsFor(db, 'd1');

    // Already attributed: the backfill only fills nulls, so p-null's series
    // (still keyed on its null computer_id) keeps 'src-computer' even though
    // the convention would have chosen src-file, and it does not merge with
    // p-unmatched's series (which the backfill DID assign 'src-file' to,
    // since only p-null had a pre-existing value) despite sharing a null
    // computer_id: the two series differ by source_id.
    final pNullSeries = _seriesWhere(
      rows,
      computerId: null,
      sourceId: 'src-computer',
    );
    expect(codec.decode(pNullSeries['samples'] as dynamic), hasLength(1));
    expect(
      _seriesWhere(rows, computerId: null, sourceId: 'src-file'),
      isNotNull,
      reason: 'p-unmatched still gets backfilled on its own series',
    );
    expect(
      _seriesWhere(rows, computerId: 'comp-1', sourceId: 'src-computer'),
      isNotNull,
    );
  });

  test('the helper no-ops when dive_profiles is absent', () async {
    // Partial-schema case: migration tests instantiate databases without
    // unrelated tables, and unguarded DDL would fail with "no such table".
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 157');
        // Deliberately no dive_profiles table at all.
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final result = await db.customSelect('SELECT 1 AS ok').getSingle();
    expect(result.data['ok'], 1);
  });
}
