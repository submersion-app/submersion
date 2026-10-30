import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v310 (renumbered from 309 as #3605 shipped 309 first):
/// diver_settings gains downloads_follow_computer_owner (issue #2050), on for
/// every existing diver so a download from a computer that belongs to another
/// profile goes to that profile by default.
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

  test('v310 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(310));
    expect(AppDatabase.migrationVersions, contains(310));
    expect(
      AppDatabase.migrationStepCount(309),
      AppDatabase.migrationStepCount(310) + 1,
    );
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(310));
  });

  test(
    'upgrading from v309 turns the switch on for an existing diver',
    () async {
      final db = AppDatabase(dbAt(309));
      addTearDown(db.close);
      final row = await db
          .customSelect(
            'SELECT downloads_follow_computer_owner FROM diver_settings',
          )
          .getSingle();
      expect(row.read<bool>('downloads_follow_computer_owner'), isTrue);
    },
  );

  test('beforeOpen heals a database already at v310 that lacks it', () async {
    final db = AppDatabase(dbAt(310));
    addTearDown(db.close);
    final columns =
        (await db.customSelect("PRAGMA table_info('diver_settings')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(columns, contains('downloads_follow_computer_owner'));
  });
}
