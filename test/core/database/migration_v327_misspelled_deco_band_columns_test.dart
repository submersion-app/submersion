import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v327: drops the deco band columns the v319 and v321 rungs first added
/// spelled `ppo2_*`, where Drift reads `pp_o2_*` (issue #3809). Every
/// database that carries them is at v326 or below, so the rung runs once;
/// the beforeOpen backstop still adds the `pp_o2_*` columns, which is what
/// lets an upgraded database read its settings and plans again.
void main() {
  Future<Set<String>> columns(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return {for (final r in rows) r.read<String>('name')};
  }

  /// What the misspelled rungs left on an upgraded database, keyed by the
  /// Drift column each stands in for: the `ppo2_*` columns, and none of the
  /// `pp_o2_*` ones Drift reads.
  const misspelled = {
    'diver_settings': {
      'pp_o2_deco_bands_enabled':
          'ppo2_deco_bands_enabled INTEGER NOT NULL '
          'DEFAULT 0 CHECK (ppo2_deco_bands_enabled IN (0, 1))',
      'pp_o2_deco_band1': 'ppo2_deco_band1 REAL NOT NULL DEFAULT 1.6',
      'pp_o2_deco_band2': 'ppo2_deco_band2 REAL NOT NULL DEFAULT 1.6',
      'pp_o2_deco_band3': 'ppo2_deco_band3 REAL NOT NULL DEFAULT 1.6',
    },
    'dive_plans': {
      'pp_o2_deco_band1': 'ppo2_deco_band1 REAL',
      'pp_o2_deco_band2': 'ppo2_deco_band2 REAL',
      'pp_o2_deco_band3': 'ppo2_deco_band3 REAL',
      'pp_o2_deco_bands_explicitly_off':
          'ppo2_deco_bands_explicitly_off INTEGER NOT NULL DEFAULT 0 '
          'CHECK (ppo2_deco_bands_explicitly_off IN (0, 1))',
    },
  };

  /// A database file holding a diver with stored settings and a plan, its
  /// band columns misspelled as an upgrade through the old rungs left them,
  /// stamped at [userVersion] and closed, ready to reopen.
  Future<File> misspelledDatabaseAt(int userVersion) async {
    final dir = Directory.systemTemp.createTempSync('v327_misspelled');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'submersion.db'));

    final before = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    // Closed below before the reopen; this covers a failure on the way
    // there, so the temp directory is not left with an open handle.
    addTearDown(before.close);
    await before
        .into(before.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Diver',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await before
        .into(before.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 's1',
            diverId: 'd1',
            createdAt: 0,
            updatedAt: 0,
            depthUnit: const Value('feet'),
          ),
        );
    await before
        .into(before.divePlans)
        .insert(
          DivePlansCompanion.insert(
            id: 'p1',
            name: 'Plan',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    for (final table in misspelled.entries) {
      for (final column in table.value.entries) {
        await before.customStatement(
          'ALTER TABLE ${table.key} DROP COLUMN ${column.key}',
        );
        // The explicitly-off flag arrived with v321, so a database stamped
        // below that has it under neither spelling: the v321 rung adds it.
        if (userVersion < 321 &&
            column.key == 'pp_o2_deco_bands_explicitly_off') {
          continue;
        }
        await before.customStatement(
          'ALTER TABLE ${table.key} ADD COLUMN ${column.value}',
        );
      }
    }
    await before.customStatement('PRAGMA user_version = $userVersion');
    await before.close();
    return file;
  }

  test('v327 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(327));
    expect(AppDatabase.migrationVersions, contains(327));
    expect(
      AppDatabase.migrationStepCount(326),
      AppDatabase.migrationStepCount(327) + 1,
    );
  });

  test('the v327 rung only removes columns, so the sync floor stays', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(327));
  });

  for (final from in [320, 326]) {
    test(
      'a v$from database the misspelled columns reached reads through Drift '
      'again, keeping its settings, and loses the misspelled columns',
      () async {
        final file = await misspelledDatabaseAt(from);

        final after = AppDatabase(
          NativeDatabase(file, setup: registerAppSqlFunctions),
        );
        addTearDown(after.close);
        final row = await after.select(after.diverSettings).getSingle();
        expect(row.depthUnit, 'feet');
        expect(row.ppO2DecoBandsEnabled, isFalse);
        expect(row.ppO2DecoBand1, 1.6);
        final plan = await after.select(after.divePlans).getSingle();
        expect(plan.ppO2DecoBand1, isNull);
        expect(plan.ppO2DecoBandsExplicitlyOff, isFalse);
        for (final table in misspelled.keys) {
          expect(
            (await columns(after, table)).where((c) => c.startsWith('ppo2_')),
            isEmpty,
            reason: '$table keeps a misspelled column',
          );
        }
      },
    );
  }

  test('a database already at v327 is not checked again: the drop is a '
      'one-time rung, not a backstop', () async {
    final file = await misspelledDatabaseAt(327);

    final after = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    addTearDown(after.close);
    // The beforeOpen backstop still restores what Drift reads.
    final row = await after.select(after.diverSettings).getSingle();
    expect(row.depthUnit, 'feet');
    expect(
      (await columns(
        after,
        'diver_settings',
      )).where((c) => c.startsWith('ppo2_')),
      hasLength(4),
    );
  });
}
