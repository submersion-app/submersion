import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v343: diver_settings.first_day_of_week, the day a week starts on
/// (issue #4232). Every existing diver starts on 'auto', which follows the
/// device's region.
void main() {
  NativeDatabase dbAt(int version, {String? stored}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL'
        "${stored != null ? ", first_day_of_week TEXT NOT NULL DEFAULT 'auto'" : ''})",
      );
      rawDb.execute(
        stored != null
            ? 'INSERT INTO diver_settings (id, diver_id, first_day_of_week) '
                  "VALUES ('s1', 'd1', '$stored')"
            : "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v343 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(343));
    expect(AppDatabase.migrationVersions, contains(343));
    expect(
      AppDatabase.migrationStepCount(342),
      AppDatabase.migrationStepCount(343) + 1,
    );
  });

  test('the new column is additive and kept the floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(343));
  });

  test('upgrading from v342 starts every diver on automatic', () async {
    final db = AppDatabase(dbAt(342));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT first_day_of_week AS v FROM diver_settings')
        .getSingle();
    expect(row.read<String>('v'), 'auto');
  });

  test('a database already carrying the column keeps its value', () async {
    final db = AppDatabase(dbAt(342, stored: 'monday'));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT first_day_of_week AS v FROM diver_settings')
        .getSingle();
    expect(row.read<String>('v'), 'monday');
  });
}
