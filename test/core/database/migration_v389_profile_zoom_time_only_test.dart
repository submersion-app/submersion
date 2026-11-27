import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v389: diver_settings gains profile_zoom_time_only, the profile
/// chart's Time only zoom choice (issue #5069). Nullable with no backfill:
/// null means the diver has never chosen, and reads as false.
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

  test('v389 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(389));
    expect(AppDatabase.migrationVersions, contains(389));
    expect(
      AppDatabase.migrationStepCount(388),
      AppDatabase.migrationStepCount(389) + 1,
    );
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(389));
  });

  test('upgrading from v386 adds the column, unset', () async {
    final db = AppDatabase(dbAt(386));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT profile_zoom_time_only FROM diver_settings')
        .getSingle();
    expect(row.read<bool?>('profile_zoom_time_only'), isNull);
  });

  test('beforeOpen heals a database already at v389 that lacks it', () async {
    final db = AppDatabase(dbAt(389));
    addTearDown(db.close);
    final columns =
        (await db.customSelect("PRAGMA table_info('diver_settings')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(columns, contains('profile_zoom_time_only'));
  });
}
