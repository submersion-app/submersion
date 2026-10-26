import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v296: media.color_adjustment (a photo or video's hand colour
/// adjustment) and diver_settings.auto_color_correction (issue #3520).
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY, '
        "file_path TEXT NOT NULL DEFAULT '', original_filename TEXT)",
      );
      rawDb.execute(
        "INSERT INTO media (id, original_filename) VALUES ('m1', 'reef.jpg')",
      );
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v296 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(296));
    expect(AppDatabase.migrationVersions, contains(296));
    expect(
      AppDatabase.migrationStepCount(295),
      AppDatabase.migrationStepCount(296) + 1,
    );
  });

  // The floor itself moved later (checklist sections, #3360); what this
  // rung pins is that it did not move it.
  test('the columns are additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(296));
  });

  test('upgrading from v295 adds both columns and keeps the rows', () async {
    final db = AppDatabase(dbAt(295));
    addTearDown(db.close);
    final media = await db
        .customSelect('SELECT original_filename, color_adjustment FROM media')
        .getSingle();
    expect(media.read<String>('original_filename'), 'reef.jpg');
    expect(media.read<String?>('color_adjustment'), isNull);
    final settings = await db
        .customSelect('SELECT auto_color_correction AS v FROM diver_settings')
        .getSingle();
    // Off for existing divers: their photos must not change on upgrade.
    expect(settings.read<int>('v'), 0);
  });

  test('beforeOpen heals a database already at v296 that lacks them', () async {
    final db = AppDatabase(dbAt(296));
    addTearDown(db.close);
    Future<Set<String>> columns(String table) async =>
        (await db.customSelect("PRAGMA table_info('$table')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(await columns('media'), contains('color_adjustment'));
    expect(await columns('diver_settings'), contains('auto_color_correction'));
  });
}
