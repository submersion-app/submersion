import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v375 adds media_identification_runs and media_identifications: what the
/// on-device model found on a photo and what the diver made of it (#4668).
Future<Set<String>> _tables(AppDatabase db) async => {
  for (final r
      in await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get())
    r.read<String>('name'),
};

Future<Set<String>> _indexes(AppDatabase db) async => {
  for (final r
      in await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get())
    r.read<String>('name'),
};

Future<List<String>> _columns(AppDatabase db, String table) async => [
  for (final c in await db.customSelect("PRAGMA table_info('$table')").get())
    c.read<String>('name'),
];

void main() {
  test('v375 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(375));
    expect(AppDatabase.migrationVersions, contains(375));
    expect(AppDatabase.migrationStepCount(374), greaterThanOrEqualTo(1));
  });

  test(
    'a fresh database has both tables, neither with an hlc column',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);
      final tables = await _tables(db);
      expect(tables, contains('media_identification_runs'));
      expect(tables, contains('media_identifications'));
      // Never synced: sync reads and writes only tables with an hlc.
      expect(
        await _columns(db, 'media_identification_runs'),
        isNot(contains('hlc')),
      );
      expect(
        await _columns(db, 'media_identifications'),
        isNot(contains('hlc')),
      );
    },
  );

  test('the identification columns are the spec\'s', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(
      await _columns(db, 'media_identification_runs'),
      containsAll([
        'media_id',
        'pack_version',
        'detector_id',
        'classifier_id',
        'location_cell',
        'analysed_at',
        'image_width',
        'image_height',
        'detection_count',
      ]),
    );
    expect(
      await _columns(db, 'media_identifications'),
      containsAll([
        'id',
        'media_id',
        'box_x',
        'box_y',
        'box_width',
        'box_height',
        'box_pixel_width',
        'box_pixel_height',
        'detector_score',
        'open_score',
        'candidates_json',
        'location_limited',
        'suggestable',
        'decision',
        'decided_species_id',
        'decided_at',
        'created_at',
      ]),
    );
  });

  test('media_id is not a foreign key, so a delete held for undo keeps the '
      'rows', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    for (final table in [
      'media_identification_runs',
      'media_identifications',
    ]) {
      final keys = await db
          .customSelect("PRAGMA foreign_key_list('$table')")
          .get();
      expect(keys, isEmpty, reason: table);
    }
  });

  test('a fresh database has the media_id index', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(await _indexes(db), contains('idx_media_identifications_media'));
  });

  test('a database already at the current version gains the tables', () async {
    // Only the beforeOpen backstop can add them there (a restore or a
    // sync-adopt never runs onUpgrade).
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          raw.execute('CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY)');
        },
      ),
    );
    addTearDown(db.close);
    final tables = await _tables(db);
    expect(tables, contains('media_identification_runs'));
    expect(tables, contains('media_identifications'));
  });
}
