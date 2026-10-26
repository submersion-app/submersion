import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v315: diver_settings gains omit_unused_oc_gases (issue #3668), off
/// for every existing diver so downloads keep every gas the computer reports
/// until the diver turns the switch on.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v315 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(315));
    expect(AppDatabase.migrationVersions, contains(315));
    expect(
      AppDatabase.migrationStepCount(314),
      AppDatabase.migrationStepCount(315) + 1,
    );
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(315));
  });

  test(
    'upgrading from v314 leaves the switch off for an existing diver',
    () async {
      final db = AppDatabase(dbAt(314));
      addTearDown(db.close);
      final row = await db
          .customSelect('SELECT omit_unused_oc_gases FROM diver_settings')
          .getSingle();
      expect(row.read<bool>('omit_unused_oc_gases'), isFalse);
    },
  );

  test('beforeOpen heals a database already at v315 that lacks it', () async {
    final db = AppDatabase(dbAt(315));
    addTearDown(db.close);
    final columns =
        (await db.customSelect("PRAGMA table_info('diver_settings')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(columns, contains('omit_unused_oc_gases'));
  });
}
