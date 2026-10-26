import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v318: the computer tissue snapshot keeps only what has no dive column
/// (issue #2555). Snapshots stored since v256 also held the deco model, the
/// CNS at dive start and end, and the OTU, which the dive and its primary
/// source already have columns for. The rung moves each into its column
/// where that column is empty, and strips the four from the stored JSON.
/// The sync stamp does not move: every device runs the same rewrite.
void main() {
  /// Snapshot JSON keyed by dive id, with the dive's own columns.
  final seeded = <String, ({String? json, double cnsStart, double? cnsEnd})>{
    // A Suunto dive: CNS and OTU lived only in the snapshot.
    'd-suunto': (
      json: jsonEncode({
        'algorithm': 'Suunto Fused2 RGBM',
        'start': {
          'n2_bar': [0.79, 0.8],
          'cns_percent': 3.0,
          'otu': 0.0,
        },
        'end': {
          'n2_bar': [1.4, 1.2],
          'cns_percent': 13.2,
          'otu': 35.57,
          'rgbm_nitrogen': 0.98,
        },
      }),
      cnsStart: 0,
      cnsEnd: null,
    ),
    // A download that already filled the columns: they win.
    'd-filled': (
      json: jsonEncode({
        'algorithm': 'zhl_16c',
        'start': {'cns_percent': 1.0},
        'end': {'n2_load_percent': 86, 'cns_percent': 23.0, 'otu': 40.0},
      }),
      cnsStart: 2,
      cnsEnd: 25,
    ),
    // Nothing but the dive-level values: no snapshot is left.
    'd-only-scalars': (
      json: jsonEncode({
        'algorithm': 'VPM-B/GFS',
        'end': {'cns_percent': 21.0},
      }),
      cnsStart: 0,
      cnsEnd: null,
    ),
    // Already in the new shape.
    'd-clean': (
      json: jsonEncode({
        'end': {'gf99_percent': 42.0},
      }),
      cnsStart: 0,
      cnsEnd: null,
    ),
    'd-corrupt': (json: '{not json', cnsStart: 0, cnsEnd: null),
    // Valid JSON naming a key, but not an object.
    'd-array': (json: '[{"otu": 1.0}]', cnsStart: 0, cnsEnd: null),
    'd-none': (json: null, cnsStart: 0, cnsEnd: null),
  };

  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          dive_date_time INTEGER NOT NULL,
          cns_start REAL NOT NULL DEFAULT 0,
          cns_end REAL,
          otu REAL,
          deco_algorithm TEXT,
          computer_tissue_json TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          hlc TEXT
        )
      ''');
      rawDb.execute('''
        CREATE TABLE dive_data_sources (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          is_primary INTEGER NOT NULL DEFAULT 0,
          cns REAL,
          otu REAL,
          deco_algorithm TEXT,
          imported_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      final dive = rawDb.prepare(
        'INSERT INTO dives (id, dive_date_time, cns_start, cns_end, otu, '
        'deco_algorithm, computer_tissue_json, created_at, updated_at, hlc) '
        'VALUES (?, 0, ?, ?, ?, ?, ?, 1000, 2000, ?)',
      );
      for (final MapEntry(key: id, value: row) in seeded.entries) {
        final filled = id == 'd-filled';
        dive.execute([
          id,
          row.cnsStart,
          row.cnsEnd,
          filled ? 41.0 : null,
          filled ? 'buhlmann' : null,
          row.json,
          'hlc-$id',
        ]);
      }
      dive.close();
      final source = rawDb.prepare(
        'INSERT INTO dive_data_sources (id, dive_id, is_primary, cns, otu, '
        'imported_at, created_at) VALUES (?, ?, ?, ?, ?, 0, 0)',
      );
      source.execute(['s-suunto', 'd-suunto', 1, null, null]);
      source.execute(['s-suunto-2nd', 'd-suunto', 0, null, null]);
      source.execute(['s-filled', 'd-filled', 1, 24.0, 39.0]);
      source.close();
    },
  );

  Future<Map<String, Map<String, Object?>>> dives(AppDatabase db) async {
    final result = await db
        .customSelect(
          'SELECT id, cns_start, cns_end, otu, deco_algorithm, '
          'computer_tissue_json, updated_at, hlc FROM dives',
        )
        .get();
    return {for (final r in result) r.read<String>('id'): r.data};
  }

  Future<Map<String, Map<String, Object?>>> sources(AppDatabase db) async {
    final result = await db
        .customSelect(
          'SELECT id, cns, otu, deco_algorithm FROM dive_data_sources',
        )
        .get();
    return {for (final r in result) r.read<String>('id'): r.data};
  }

  Object? jsonOf(Map<String, Object?> row) {
    final text = row['computer_tissue_json'] as String?;
    return text == null ? null : jsonDecode(text);
  }

  test('v318 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(318));
    expect(AppDatabase.migrationVersions, contains(318));
    // Measured from the rung below, which a later merge may renumber.
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(318) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(318) + 1,
    );
  });

  test('a data-only rung, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(318));
  });

  test('moves the CNS, OTU and deco model into the empty dive columns and '
      'strips them from the snapshot', () async {
    final db = AppDatabase(strandedAt(315));
    addTearDown(db.close);
    final after = await dives(db);

    final suunto = after['d-suunto']!;
    expect(suunto['cns_start'], 3.0);
    expect(suunto['cns_end'], 13.2);
    expect(suunto['otu'], 35.57);
    expect(suunto['deco_algorithm'], 'Suunto Fused2 RGBM');
    expect(jsonOf(suunto), {
      'start': {
        'n2_bar': [0.79, 0.8],
      },
      'end': {
        'n2_bar': [1.4, 1.2],
        'rgbm_nitrogen': 0.98,
      },
    });
  });

  test('keeps the values the columns already held', () async {
    final db = AppDatabase(strandedAt(315));
    addTearDown(db.close);
    final filled = (await dives(db))['d-filled']!;

    expect(filled['cns_start'], 2.0);
    expect(filled['cns_end'], 25.0);
    expect(filled['otu'], 41.0);
    expect(filled['deco_algorithm'], 'buhlmann');
    expect(jsonOf(filled), {
      'end': {'n2_load_percent': 86},
    });
  });

  test('clears a snapshot that held only the dive-level values', () async {
    final db = AppDatabase(strandedAt(315));
    addTearDown(db.close);
    final row = (await dives(db))['d-only-scalars']!;

    expect(row['computer_tissue_json'], isNull);
    expect(row['cns_end'], 21.0);
    expect(row['deco_algorithm'], 'VPM-B/GFS');
  });

  test(
    'fills the primary source row where it is empty, and no other',
    () async {
      final db = AppDatabase(strandedAt(315));
      addTearDown(db.close);
      final after = await sources(db);

      expect(after['s-suunto']!['cns'], 13.2);
      expect(after['s-suunto']!['otu'], 35.57);
      expect(after['s-suunto']!['deco_algorithm'], 'Suunto Fused2 RGBM');
      expect(after['s-suunto-2nd']!['cns'], isNull);
      expect(after['s-suunto-2nd']!['otu'], isNull);
      expect(after['s-filled']!['cns'], 24.0);
      expect(after['s-filled']!['otu'], 39.0);
    },
  );

  test('leaves the sync stamp alone and steps over what it cannot '
      'read', () async {
    final db = AppDatabase(strandedAt(315));
    addTearDown(db.close);
    final after = await dives(db);

    for (final id in seeded.keys) {
      expect(after[id]!['updated_at'], 2000, reason: id);
      expect(after[id]!['hlc'], 'hlc-$id', reason: id);
    }
    expect(after['d-corrupt']!['computer_tissue_json'], '{not json');
    expect(after['d-array']!['computer_tissue_json'], '[{"otu": 1.0}]');
    expect(after['d-array']!['otu'], isNull);
    expect(after['d-clean']!['computer_tissue_json'], seeded['d-clean']!.json);
    expect(after['d-none']!['computer_tissue_json'], isNull);
  });

  test(
    'still moves the dive values when the sources table is missing',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA user_version = 315');
            rawDb.execute('''
            CREATE TABLE dives (
              id TEXT NOT NULL PRIMARY KEY,
              dive_date_time INTEGER NOT NULL,
              cns_start REAL NOT NULL DEFAULT 0,
              cns_end REAL,
              otu REAL,
              deco_algorithm TEXT,
              computer_tissue_json TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
            rawDb.execute(
              'INSERT INTO dives (id, dive_date_time, computer_tissue_json, '
              "created_at, updated_at) VALUES ('d', 0, "
              '\'{"end":{"cns_percent":9.0,"gf99_percent":30.0}}\', 0, 0)',
            );
          },
        ),
      );
      addTearDown(db.close);
      final row = (await dives(db))['d']!;

      expect(row['cns_end'], 9.0);
      expect(jsonOf(row), {
        'end': {'gf99_percent': 30.0},
      });
    },
  );

  test('a database already at v318 is not rewritten again', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    final suunto = (await dives(db))['d-suunto']!;

    expect(suunto['cns_end'], isNull);
    expect(suunto['computer_tissue_json'], seeded['d-suunto']!.json);
  });
}
