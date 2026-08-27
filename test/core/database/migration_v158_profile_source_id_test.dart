import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

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

Future<String?> _sourceIdOf(AppDatabase db, String profileId) async {
  final row = await db
      .customSelect(
        "SELECT source_id FROM dive_profiles WHERE id = '$profileId'",
      )
      .getSingle();
  return row.data['source_id'] as String?;
}

void main() {
  test('v158 adds the owning-source column, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 157');
        rawDb.execute(_preV158DiveProfiles);
        rawDb.execute(_preV158DiveDataSources);
        _seedMixedDive(rawDb);
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('dive_profiles')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), contains('source_id'));

    final row = await db
        .customSelect(
          "SELECT depth, timestamp FROM dive_profiles WHERE id = 'p-computer'",
        )
        .getSingle();
    expect(row.data['depth'], 20.0);
    expect(row.data['timestamp'], 60);
  });

  test('v158 attributes rows the way the pre-v158 read path did', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 157');
        rawDb.execute(_preV158DiveProfiles);
        rawDb.execute(_preV158DiveDataSources);
        _seedMixedDive(rawDb);
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // A matching computer_id names the owner outright.
    expect(await _sourceIdOf(db, 'p-computer'), 'src-computer');

    // Null computer_id belongs to the primary source -- the convention
    // getProfilesByDataSource has always implemented. Reproducing it here is
    // what keeps the upgrade from moving anyone's samples between sources.
    expect(await _sourceIdOf(db, 'p-null'), 'src-file');

    // A computer_id matching no source falls back the same way.
    expect(await _sourceIdOf(db, 'p-unmatched'), 'src-file');

    // Nothing to attribute to: left null, and the code falls back to the
    // legacy convention for these.
    expect(await _sourceIdOf(db, 'p-orphan'), isNull);
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

    final cols = await db
        .customSelect("PRAGMA table_info('dive_profiles')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')).where((n) => n == 'source_id'),
      hasLength(1),
    );

    // Already attributed: the backfill only fills nulls, so this stays put
    // even though the convention would have chosen src-file.
    expect(await _sourceIdOf(db, 'p-null'), 'src-computer');
    expect(await _sourceIdOf(db, 'p-computer'), 'src-computer');
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
