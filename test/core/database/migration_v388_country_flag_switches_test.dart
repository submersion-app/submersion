import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v388 (issue #5001): a country flags switch for dives, buddies and
/// trips beside the existing one, which now covers sites only. The rung
/// copies the existing switch into the new ones, so a diver who turned flags
/// off keeps them off everywhere. The sync floor holds.
void main() {
  const newColumns = [
    'show_dive_country_flags',
    'show_buddy_country_flags',
    'show_trip_country_flags',
  ];

  NativeDatabase dbAt(
    int version, {
    bool? flags,
    Map<String, int> carried = const {},
  }) {
    final columns = [
      'id TEXT NOT NULL PRIMARY KEY',
      'diver_id TEXT NOT NULL',
      if (flags != null) 'show_country_flags INTEGER NOT NULL DEFAULT 1',
      for (final column in carried.keys) '$column INTEGER NOT NULL DEFAULT 1',
    ];
    final names = [
      'id',
      'diver_id',
      if (flags != null) 'show_country_flags',
      ...carried.keys,
    ];
    final values = [
      "'s1'",
      "'d1'",
      if (flags != null) flags ? '1' : '0',
      for (final value in carried.values) '$value',
    ];
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $version');
        rawDb.execute('CREATE TABLE diver_settings (${columns.join(', ')})');
        rawDb.execute(
          'INSERT INTO diver_settings (${names.join(', ')}) '
          'VALUES (${values.join(', ')})',
        );
      },
    );
  }

  Future<Map<String, Object?>> stored(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT ${newColumns.join(', ')} FROM diver_settings',
              )
              .getSingle())
          .data;

  test('v388 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(388));
    expect(AppDatabase.migrationVersions, contains(388));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(388));
  });

  test('upgrading copies flags off into every new switch', () async {
    final db = AppDatabase(dbAt(387, flags: false));
    addTearDown(db.close);
    expect(await stored(db), {for (final c in newColumns) c: 0});
  });

  test('upgrading copies flags on into every new switch', () async {
    final db = AppDatabase(dbAt(387, flags: true));
    addTearDown(db.close);
    expect(await stored(db), {for (final c in newColumns) c: 1});
  });

  test('a database already carrying a new column keeps its value', () async {
    final db = AppDatabase(
      dbAt(387, flags: true, carried: {'show_dive_country_flags': 0}),
    );
    addTearDown(db.close);
    expect(await stored(db), {
      'show_dive_country_flags': 0,
      'show_buddy_country_flags': 1,
      'show_trip_country_flags': 1,
    });
  });

  test(
    'a fixture with no show_country_flags column upgrades without throwing',
    () async {
      final db = AppDatabase(dbAt(387));
      addTearDown(db.close);
      expect(await stored(db), {for (final c in newColumns) c: 1});
    },
  );

  test(
    'the beforeOpen backstop adds missing columns without copying',
    () async {
      // Already at v388, so only the backstop runs: a copy here would rewrite
      // the section switches from the sites switch on every open.
      final db = AppDatabase(dbAt(388, flags: false));
      addTearDown(db.close);
      expect(await stored(db), {for (final c in newColumns) c: 1});
    },
  );

  test('the new columns are booleans', () async {
    final db = AppDatabase(dbAt(387, flags: true));
    addTearDown(db.close);
    await stored(db);
    for (final column in newColumns) {
      await expectLater(
        db.customStatement('UPDATE diver_settings SET $column = 2'),
        throwsA(anything),
        reason: column,
      );
    }
  });
}
