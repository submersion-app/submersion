import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v379: the default visibility and the palette colour of the three
/// Avelo profile lines (issue #4664): `default_show_avelo_buoyancy`,
/// `default_show_avelo_gas_remaining`, `default_show_computer_rmv` and the
/// matching `profile_color_*` columns. Defaulted off or null, no backfill,
/// so the sync floor holds.
void main() {
  const showColumns = [
    'default_show_avelo_buoyancy',
    'default_show_avelo_gas_remaining',
    'default_show_computer_rmv',
  ];
  const colorColumns = [
    'profile_color_avelo_buoyancy',
    'profile_color_avelo_gas_remaining',
    'profile_color_computer_rmv',
  ];

  NativeDatabase dbAt(
    int version, {
    bool withColumns = false,
  }) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      final extra = withColumns
          ? [
              for (final c in showColumns) ', $c INTEGER NOT NULL DEFAULT 0',
              for (final c in colorColumns) ', $c INTEGER',
            ].join()
          : '';
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL$extra)',
      );
      rawDb.execute(
        withColumns
            ? 'INSERT INTO diver_settings (id, diver_id, '
                  '${showColumns.join(', ')}, ${colorColumns.join(', ')}) '
                  "VALUES ('s1', 'd1', 1, 0, 1, 4278190080, NULL, 255)"
            : "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  Future<Map<String, Object?>> stored(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT ${[...showColumns, ...colorColumns].join(', ')} '
                'FROM diver_settings',
              )
              .getSingle())
          .data;

  test('v379 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(379));
    expect(AppDatabase.migrationVersions, contains(379));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(379));
  });

  test('upgrading from v378 adds the columns off and uncoloured', () async {
    final db = AppDatabase(dbAt(378));
    addTearDown(db.close);
    expect(await stored(db), {
      for (final c in showColumns) c: 0,
      for (final c in colorColumns) c: null,
    });
  });

  test('the upgraded visibility columns are booleans', () async {
    final db = AppDatabase(dbAt(378));
    addTearDown(db.close);
    await stored(db);
    for (final c in showColumns) {
      await expectLater(
        db.customStatement('UPDATE diver_settings SET $c = 2'),
        throwsA(anything),
        reason: c,
      );
    }
  });

  test('a database already carrying the columns keeps its values', () async {
    final db = AppDatabase(dbAt(378, withColumns: true));
    addTearDown(db.close);
    expect(await stored(db), {
      'default_show_avelo_buoyancy': 1,
      'default_show_avelo_gas_remaining': 0,
      'default_show_computer_rmv': 1,
      'profile_color_avelo_buoyancy': 4278190080,
      'profile_color_avelo_gas_remaining': null,
      'profile_color_computer_rmv': 255,
    });
  });
}
