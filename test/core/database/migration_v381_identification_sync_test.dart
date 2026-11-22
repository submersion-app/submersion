import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v381 lets marine life results sync (issue #4876): a clock on both
/// identification tables, where each run came from and which analysis made
/// it, the pack's naming bars, the clock of the diver's decisions, and a
/// table for the crops of named identifications. The floor rises to 381 so
/// a device that updates later still reads the results published before.
Future<List<String>> _columns(AppDatabase db, String table) async => [
  for (final c in await db.customSelect("PRAGMA table_info('$table')").get())
    c.read<String>('name'),
];

const _runColumns = ['hlc', 'analysed_by', 'run_id', 'naming_bars'];
const _identificationColumns = ['hlc', 'run_id', 'decision_hlc'];
const _cropColumns = ['id', 'media_id', 'jpeg', 'hlc'];

/// Both tables as v380 left them, two runs, three identifications.
NativeDatabase _at380() => NativeDatabase.memory(setup: _seed380);

NativeDatabase _at380File(File file) => NativeDatabase(file, setup: _seed380);

void _seed380(Database raw) {
  registerAppSqlFunctions(raw);
  raw.execute('PRAGMA user_version = 380');
  raw.execute('CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY)');
  raw.execute(
    'CREATE TABLE media_identification_runs ('
    'media_id TEXT NOT NULL PRIMARY KEY, pack_version TEXT NOT NULL, '
    'detector_id TEXT NOT NULL, classifier_id TEXT NOT NULL, '
    'location_cell INTEGER NULL, analysed_at INTEGER NOT NULL, '
    'image_width INTEGER NOT NULL, image_height INTEGER NOT NULL, '
    'detection_count INTEGER NOT NULL, scanned_ms INTEGER NULL, '
    'video_duration_ms INTEGER NULL, scanned_ranges BLOB NULL)',
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
    'decided_at INTEGER NULL, created_at INTEGER NOT NULL, '
    'start_ms INTEGER NULL, end_ms INTEGER NULL, best_ms INTEGER NULL, '
    'track_path BLOB NULL, claimed_species_id TEXT NULL, '
    'confident INTEGER NOT NULL DEFAULT 0, '
    'specific INTEGER NOT NULL DEFAULT 0)',
  );
  for (final media in ['m1', 'm2']) {
    raw.execute(
      "INSERT INTO media_identification_runs (media_id, pack_version, "
      "detector_id, classifier_id, analysed_at, image_width, image_height, "
      "detection_count) VALUES ('$media', 'p', 'd', 'c', 1, 10, 10, 1)",
    );
  }
  for (final (id, media) in [('i1', 'm1'), ('i2', 'm1'), ('i3', 'm2')]) {
    raw.execute(
      "INSERT INTO media_identifications (id, media_id, box_x, box_y, "
      "box_width, box_height, box_pixel_width, box_pixel_height, "
      "detector_score, open_score, candidates_json, location_limited, "
      "suggestable, decision, created_at) VALUES ('$id', '$media', 0.1, "
      "0.1, 0.2, 0.2, 80, 60, 0.9, 0.5, '[]', 0, 1, 'undecided', 1)",
    );
  }
}

void main() {
  test('v381 is in the ladder and is the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(381));
    expect(AppDatabase.migrationVersions, contains(381));
    expect(AppDatabase.minimumCompatibleSchemaVersion, 381);
  });

  test('a fresh database has the sync columns and the crops table', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(
      await _columns(db, 'media_identification_runs'),
      containsAll(_runColumns),
    );
    expect(
      await _columns(db, 'media_identifications'),
      containsAll(_identificationColumns),
    );
    expect(
      await _columns(db, 'media_identification_crops'),
      containsAll(_cropColumns),
    );
  });

  group('upgrading from 380', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(_at380());
      addTearDown(db.close);
    });

    test('gives each run its own id, shared by its rows', () async {
      final runs = {
        for (final r
            in await db
                .customSelect(
                  'SELECT media_id, run_id FROM media_identification_runs',
                )
                .get())
          r.read<String>('media_id'): r.read<String?>('run_id'),
      };
      expect(runs['m1'], isNotNull);
      expect(runs['m2'], isNotNull);
      expect(runs['m1'], isNot(runs['m2']));
      final rows = {
        for (final r
            in await db
                .customSelect('SELECT id, run_id FROM media_identifications')
                .get())
          r.read<String>('id'): r.read<String?>('run_id'),
      };
      expect(rows, {'i1': runs['m1'], 'i2': runs['m1'], 'i3': runs['m2']});
    });

    test('leaves the clocks, origin and bars empty', () async {
      final run =
          (await db
                  .customSelect(
                    'SELECT hlc, analysed_by, naming_bars '
                    "FROM media_identification_runs WHERE media_id = 'm1'",
                  )
                  .getSingle())
              .data;
      expect(run, {'hlc': null, 'analysed_by': null, 'naming_bars': null});
      final row =
          (await db
                  .customSelect(
                    'SELECT hlc, decision_hlc FROM media_identifications '
                    "WHERE id = 'i1'",
                  )
                  .getSingle())
              .data;
      expect(row, {'hlc': null, 'decision_hlc': null});
    });

    test('creates the crops table empty', () async {
      final count = await db
          .customSelect('SELECT COUNT(*) AS n FROM media_identification_crops')
          .getSingle();
      expect(count.read<int>('n'), 0);
    });
  });

  test('reopening runs the backstop again and keeps the run ids', () async {
    final dir = Directory.systemTemp.createTempSync('v381_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'log.db'));
    // Build the v380 shape in the file, then migrate it.
    final seeded = _at380File(file);
    var db = AppDatabase(seeded);
    Future<Map<String, String?>> runIds() async => {
      for (final r
          in await db
              .customSelect(
                'SELECT media_id, run_id FROM media_identification_runs',
              )
              .get())
        r.read<String>('media_id'): r.read<String?>('run_id'),
    };
    final first = await runIds();
    await db.close();
    db = AppDatabase(NativeDatabase(file, setup: registerAppSqlFunctions));
    addTearDown(db.close);
    expect(await runIds(), first);
  });
}
