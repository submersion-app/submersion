import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v359: diver_settings gains pin_profile_on_scroll, on for every
/// existing diver, so dive details pins a thin profile strip once the
/// profile card scrolls away (issue #4423).
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

  test('v359 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(359));
    expect(AppDatabase.migrationVersions, contains(359));
    expect(
      AppDatabase.migrationStepCount(358),
      AppDatabase.migrationStepCount(359) + 1,
    );
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(359));
  });

  test(
    'upgrading from v358 turns the strip on for an existing diver',
    () async {
      final db = AppDatabase(dbAt(358));
      addTearDown(db.close);
      final row = await db
          .customSelect('SELECT pin_profile_on_scroll FROM diver_settings')
          .getSingle();
      expect(row.read<bool>('pin_profile_on_scroll'), isTrue);
    },
  );

  test('beforeOpen heals a database already at v359 that lacks it', () async {
    final db = AppDatabase(dbAt(359));
    addTearDown(db.close);
    final columns =
        (await db.customSelect("PRAGMA table_info('diver_settings')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(columns, contains('pin_profile_on_scroll'));
  });
}
