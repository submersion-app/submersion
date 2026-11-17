import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v376 gives the marine life identification tables what a video needs
/// (issue #4675): a scan's progress and length on the run, and on each
/// identification a time range, a packed path, a claimed species and the
/// two label flags. Columns only, never synced, so the floor holds.
Future<List<String>> _columns(AppDatabase db, String table) async => [
  for (final c in await db.customSelect("PRAGMA table_info('$table')").get())
    c.read<String>('name'),
];

const _runColumns = ['scanned_ms', 'video_duration_ms'];
const _identificationColumns = [
  'start_ms',
  'end_ms',
  'best_ms',
  'track_path',
  'claimed_species_id',
  'confident',
  'specific',
];

/// Both tables exactly as v375 created them, with one row in each.
NativeDatabase _at375() => NativeDatabase.memory(
  setup: (raw) {
    registerAppSqlFunctions(raw);
    raw.execute('PRAGMA user_version = 375');
    raw.execute('CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY)');
    raw.execute(
      'CREATE TABLE media_identification_runs ('
      'media_id TEXT NOT NULL PRIMARY KEY, pack_version TEXT NOT NULL, '
      'detector_id TEXT NOT NULL, classifier_id TEXT NOT NULL, '
      'location_cell INTEGER NULL, analysed_at INTEGER NOT NULL, '
      'image_width INTEGER NOT NULL, image_height INTEGER NOT NULL, '
      'detection_count INTEGER NOT NULL)',
    );
    raw.execute(
      'CREATE TABLE media_identifications ('
      'id TEXT NOT NULL PRIMARY KEY, media_id TEXT NOT NULL, '
      'box_x REAL NOT NULL, box_y REAL NOT NULL, box_width REAL NOT NULL, '
      'box_height REAL NOT NULL, box_pixel_width INTEGER NOT NULL, '
      'box_pixel_height INTEGER NOT NULL, detector_score REAL NOT NULL, '
      'open_score REAL NOT NULL, candidates_json TEXT NOT NULL, '
      'location_limited INTEGER NOT NULL, suggestable INTEGER NOT NULL, '
      'decision TEXT NOT NULL, decided_species_id TEXT NULL, '
      'decided_at INTEGER NULL, created_at INTEGER NOT NULL)',
    );
    raw.execute(
      "INSERT INTO media_identification_runs VALUES "
      "('m1', 'p', 'd', 'c', NULL, 1, 10, 10, 1)",
    );
    raw.execute(
      "INSERT INTO media_identifications VALUES ('i1', 'm1', 0.1, 0.1, 0.2, "
      "0.2, 80, 60, 0.9, 0.5, '[]', 0, 1, 'undecided', NULL, NULL, 1)",
    );
  },
);

void main() {
  test('v376 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(376));
    expect(AppDatabase.migrationVersions, contains(376));
  });

  test('the floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(376));
  });

  test('a fresh database has the video columns, still with no hlc', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    final runs = await _columns(db, 'media_identification_runs');
    final identifications = await _columns(db, 'media_identifications');
    expect(runs, containsAll(_runColumns));
    expect(identifications, containsAll(_identificationColumns));
    expect(runs, isNot(contains('hlc')));
    expect(identifications, isNot(contains('hlc')));
  });

  test('upgrading from 375 adds them empty', () async {
    final db = AppDatabase(_at375());
    addTearDown(db.close);
    final run =
        (await db
                .customSelect(
                  'SELECT scanned_ms, video_duration_ms '
                  'FROM media_identification_runs',
                )
                .getSingle())
            .data;
    expect(run['scanned_ms'], isNull);
    expect(run['video_duration_ms'], isNull);
    final row =
        (await db
                .customSelect(
                  'SELECT start_ms, end_ms, best_ms, track_path, claimed_species_id, '
                  'confident, specific FROM media_identifications',
                )
                .getSingle())
            .data;
    expect(row['start_ms'], isNull);
    expect(row['end_ms'], isNull);
    expect(row['best_ms'], isNull);
    expect(row['track_path'], isNull);
    expect(row['claimed_species_id'], isNull);
    expect(row['confident'], 0);
    expect(row['specific'], 0);
  });

  test('a database already at the current version gains them', () async {
    // Only the beforeOpen backstop reaches a restore or a sync-adopt.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          registerAppSqlFunctions(raw);
          raw.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          raw.execute('CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY)');
          raw.execute(
            'CREATE TABLE media_identifications (id TEXT NOT NULL PRIMARY KEY, '
            'media_id TEXT NOT NULL)',
          );
        },
      ),
    );
    addTearDown(db.close);
    expect(
      await _columns(db, 'media_identifications'),
      containsAll(_identificationColumns),
    );
  });
}
