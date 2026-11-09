import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v351: diver_settings.equipment_collapsed_groups, the Equipment
/// page's folded group keys (issue #4184). Nullable, no backfill: null
/// means every group open.
void main() {
  NativeDatabase dbAt(int version, {String? stored}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL'
        "${stored != null ? ', equipment_collapsed_groups TEXT' : ''})",
      );
      rawDb.execute(
        stored != null
            ? 'INSERT INTO diver_settings '
                  '(id, diver_id, equipment_collapsed_groups) '
                  "VALUES ('s1', 'd1', '$stored')"
            : "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v351 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(351));
    expect(AppDatabase.migrationVersions, contains(351));
    expect(
      AppDatabase.migrationStepCount(350),
      AppDatabase.migrationStepCount(351) + 1,
    );
  });

  test('the new column is additive and kept the floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(351));
  });

  test('upgrading from v350 adds a null column', () async {
    final db = AppDatabase(dbAt(350));
    addTearDown(db.close);
    final row = await db
        .customSelect(
          'SELECT equipment_collapsed_groups AS v FROM diver_settings',
        )
        .getSingle();
    expect(row.read<String?>('v'), isNull);
  });

  test('a database already carrying the column keeps its value', () async {
    final db = AppDatabase(dbAt(350, stored: '["loc:a"]'));
    addTearDown(db.close);
    final row = await db
        .customSelect(
          'SELECT equipment_collapsed_groups AS v FROM diver_settings',
        )
        .getSingle();
    expect(row.read<String?>('v'), '["loc:a"]');
  });
}
