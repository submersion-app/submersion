import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v377 keeps the stretches of a video already scanned on its run (issue
/// #4709), so the scan can follow the playhead. A column on a table that
/// never syncs, no backfill: a null reads as one stretch from the start to
/// scanned_ms. The floor holds.
Future<List<String>> _columns(AppDatabase db, String table) async => [
  for (final c in await db.customSelect("PRAGMA table_info('$table')").get())
    c.read<String>('name'),
];

/// The runs table exactly as v376 left it, with a video's run part-way.
NativeDatabase _at376() => NativeDatabase.memory(
  setup: (raw) {
    registerAppSqlFunctions(raw);
    raw.execute('PRAGMA user_version = 376');
    raw.execute('CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY)');
    raw.execute(
      'CREATE TABLE media_identification_runs ('
      'media_id TEXT NOT NULL PRIMARY KEY, pack_version TEXT NOT NULL, '
      'detector_id TEXT NOT NULL, classifier_id TEXT NOT NULL, '
      'location_cell INTEGER NULL, analysed_at INTEGER NOT NULL, '
      'image_width INTEGER NOT NULL, image_height INTEGER NOT NULL, '
      'detection_count INTEGER NOT NULL, scanned_ms INTEGER NULL, '
      'video_duration_ms INTEGER NULL)',
    );
    raw.execute(
      "INSERT INTO media_identification_runs VALUES "
      "('v1', 'p', 'd', 'c', NULL, 1, 1920, 1080, 3, 12000, 30000)",
    );
  },
);

void main() {
  test('v377 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(377));
    expect(AppDatabase.migrationVersions, contains(377));
  });

  test('the floor does not move', () {
    // A later rung (v378, the marks on app-applied species tags) raised the
    // floor; v377 itself did not set it.
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(377));
  });

  test('a fresh database has scanned_ranges', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(
      await _columns(db, 'media_identification_runs'),
      contains('scanned_ranges'),
    );
  });

  test(
    'upgrading from 376 adds it empty and leaves the row as it was',
    () async {
      final db = AppDatabase(_at376());
      addTearDown(db.close);
      final run =
          (await db
                  .customSelect(
                    'SELECT media_id, detection_count, scanned_ms, '
                    'video_duration_ms, scanned_ranges '
                    'FROM media_identification_runs',
                  )
                  .getSingle())
              .data;
      expect(run['media_id'], 'v1');
      expect(run['detection_count'], 3);
      expect(run['scanned_ms'], 12000);
      expect(run['video_duration_ms'], 30000);
      expect(run['scanned_ranges'], isNull);
    },
  );

  test('a database already at the current version gains it', () async {
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
            'CREATE TABLE media_identification_runs ('
            'media_id TEXT NOT NULL PRIMARY KEY)',
          );
        },
      ),
    );
    addTearDown(db.close);
    expect(
      await _columns(db, 'media_identification_runs'),
      contains('scanned_ranges'),
    );
  });
}
