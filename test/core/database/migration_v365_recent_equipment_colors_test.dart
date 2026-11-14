import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v365: diver_settings.recent_equipment_colors, the custom colours
/// the diver picked for their gear (issue #4537). Nullable, no backfill:
/// null means none remembered.
void main() {
  NativeDatabase dbAt(int version, {String? stored}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL'
        "${stored != null ? ', recent_equipment_colors TEXT' : ''})",
      );
      rawDb.execute(
        stored != null
            ? 'INSERT INTO diver_settings '
                  '(id, diver_id, recent_equipment_colors) '
                  "VALUES ('s1', 'd1', '$stored')"
            : "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  Future<String?> stored(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT recent_equipment_colors AS v FROM diver_settings',
              )
              .getSingle())
          .read<String?>('v');

  test('v365 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(365));
    expect(AppDatabase.migrationVersions, contains(365));
    expect(
      AppDatabase.migrationStepCount(364),
      AppDatabase.migrationStepCount(365) + 1,
    );
  });

  test('the new column is additive and kept the floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(365));
  });

  test('upgrading from v364 adds a null column', () async {
    final db = AppDatabase(dbAt(364));
    addTearDown(db.close);
    expect(await stored(db), isNull);
  });

  test('a database already carrying the column keeps its value', () async {
    final db = AppDatabase(dbAt(364, stored: '["#FF6A00"]'));
    addTearDown(db.close);
    expect(await stored(db), '["#FF6A00"]');
  });

  test('a database stamped current without the column is healed', () async {
    // A colliding branch that took this version number first.
    final db = AppDatabase(dbAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect(await stored(db), isNull);
  });
}
