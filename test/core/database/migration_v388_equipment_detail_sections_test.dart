import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v388: `diver_settings.equipment_detail_sections` (TEXT, nullable),
/// the gear item page's card order and visibility, issue #4975. No backfill,
/// so the sync floor holds.
void main() {
  NativeDatabase dbAt(int version, {String? sections}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $version');
        final extra = sections != null
            ? ', equipment_detail_sections TEXT'
            : '';
        rawDb.execute(
          'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
          'diver_id TEXT NOT NULL$extra)',
        );
        if (sections != null) {
          rawDb.execute(
            'INSERT INTO diver_settings '
            "(id, diver_id, equipment_detail_sections) VALUES ('s1', 'd1', "
            "'$sections')",
          );
        } else {
          rawDb.execute(
            "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
          );
        }
      },
    );
  }

  Future<Map<String, Object?>> stored(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT equipment_detail_sections FROM diver_settings',
              )
              .getSingle())
          .data;

  test('v388 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(388));
    expect(AppDatabase.migrationVersions, contains(388));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(388));
  });

  test(
    'upgrading from v387 leaves an existing diver on the defaults',
    () async {
      final db = AppDatabase(dbAt(387));
      addTearDown(db.close);
      expect(await stored(db), {'equipment_detail_sections': null});
    },
  );

  test('a database already carrying the column keeps its value', () async {
    const saved = '[{"id":"notes","visible":false}]';
    final db = AppDatabase(dbAt(387, sections: saved));
    addTearDown(db.close);
    expect(await stored(db), {'equipment_detail_sections': saved});
  });
}
