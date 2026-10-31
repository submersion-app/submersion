import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v329: the diver figure goes from opt-in to on by default (issue #3889),
/// so the rung turns it on for every set and diver already stored. It runs
/// once, from the ladder and never the beforeOpen backstop, so a later Hide
/// sticks; and it leaves the sync clocks alone, so an upgrade here cannot
/// outrank a newer change made on another device.
void main() {
  /// A database file holding one set and one diver with the figure off and
  /// known clocks, stamped at [userVersion] and closed, ready to reopen.
  /// [before] runs last, for a test to reshape the file.
  Future<File> databaseAt(
    int userVersion, {
    Future<void> Function(AppDatabase db)? before,
  }) async {
    final dir = Directory.systemTemp.createTempSync('v329_diver_figure');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'submersion.db'));

    final db = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    // Closed below before the reopen; this covers a failure on the way
    // there, so the temp directory is not left with an open handle.
    addTearDown(db.close);
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Diver',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 's1',
            diverId: 'd1',
            createdAt: 0,
            updatedAt: 11,
            showDiveFigure: const Value(false),
            hlc: const Value('hlc-settings'),
          ),
        );
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: 'e1',
            name: 'Reef set',
            createdAt: 0,
            updatedAt: 22,
            showFigure: const Value(false),
            hlc: const Value('hlc-set'),
          ),
        );
    await before?.call(db);
    await db.customStatement('PRAGMA user_version = $userVersion');
    await db.close();
    return file;
  }

  AppDatabase reopen(File file) {
    final db = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    return db;
  }

  Future<Map<String, Object?>> set(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT show_figure, updated_at, hlc FROM equipment_sets '
                "WHERE id = 'e1'",
              )
              .getSingle())
          .data;

  Future<Map<String, Object?>> settings(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT show_dive_figure, updated_at, hlc FROM diver_settings '
                "WHERE id = 's1'",
              )
              .getSingle())
          .data;

  test('v329 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 329);
    expect(AppDatabase.migrationVersions, contains(329));
  });

  test('this data rung did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(329));
  });

  test('a database below v329 turns the figure on everywhere', () async {
    final db = reopen(await databaseAt(328));

    expect((await set(db))['show_figure'], 1);
    expect((await settings(db))['show_dive_figure'], 1);
  });

  test('the rung leaves the sync clocks alone', () async {
    final db = reopen(await databaseAt(328));

    final setRow = await set(db);
    expect(setRow['updated_at'], 22);
    expect(setRow['hlc'], 'hlc-set');
    final settingsRow = await settings(db);
    expect(settingsRow['updated_at'], 11);
    expect(settingsRow['hlc'], 'hlc-settings');
  });

  test('a database already at v329 keeps a stored off', () async {
    final db = reopen(await databaseAt(329));

    expect((await set(db))['show_figure'], 0);
    expect((await settings(db))['show_dive_figure'], 0);
  });

  test('a Hide after the upgrade survives the next open', () async {
    final file = await databaseAt(328);
    final upgraded = reopen(file);
    await upgraded.customStatement(
      "UPDATE equipment_sets SET show_figure = 0 WHERE id = 'e1'",
    );
    await upgraded.customStatement(
      "UPDATE diver_settings SET show_dive_figure = 0 WHERE id = 's1'",
    );
    await upgraded.close();

    final db = reopen(file);

    expect((await set(db))['show_figure'], 0);
    expect((await settings(db))['show_dive_figure'], 0);
  });

  test(
    'a database that skipped the column rungs upgrades instead of failing',
    () async {
      // v229 and v237 each landed below the newest rung, so a device already
      // past them gets the column only from beforeOpen, after onUpgrade has
      // run this rung.
      final file = await databaseAt(
        300,
        before: (db) async {
          await db.customStatement(
            'ALTER TABLE equipment_sets DROP COLUMN show_figure',
          );
          await db.customStatement(
            'ALTER TABLE diver_settings DROP COLUMN show_dive_figure',
          );
        },
      );

      final db = reopen(file);

      expect((await set(db))['show_figure'], 1);
      expect((await settings(db))['show_dive_figure'], 1);
    },
  );
}
