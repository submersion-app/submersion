import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

import 'test_fixtures.dart';

/// A diver's stored per-metric data-source preferences must survive every
/// rung of the ladder (#2554). A MetricDataSource index: 0 = computer,
/// 1 = calculated. Since #1860 a new diver defaults to computer, but stored
/// rows are left alone because a 0/1 column cannot tell a chosen Calculated
/// from an untouched default, so no rung may rewrite them.
///
/// Six columns have existed: NDL, ceiling, TTS and CNS (v42), deco stop
/// (v133) and GTR (v177). Ceiling lost its toggle at v137 (#755) and its
/// column at v261 (#767), so five survive to the current version.
const _v42Sources = [
  'default_ndl_source',
  'default_ceiling_source',
  'default_tts_source',
  'default_cns_source',
];

const _v177Sources = [
  ..._v42Sources,
  'default_deco_stop_source',
  'default_gtr_source',
];

/// The earliest version the ladder climbs from with only diver_settings and
/// the shared fixture tables. Below it, rungs alter trips, dives, dive
/// computers, dive tanks and view configs, whose period shapes no fixture
/// recreates; rungs 43 to 64 only add columns to diver_settings.
const _earlyVersion = 65;

/// The first version that carries all six source columns.
const _allSourcesVersion = 177;

/// An existing library at [version] whose diver_settings row holds [stored]
/// in every one of [sources]. use_dive_computer_cns_data is on: v42 turned
/// that toggle into default_cns_source = 0, so a rung that re-ran the
/// conversion would move a diver who later chose Calculated back to computer.
NativeDatabase _libraryAt(
  int version, {
  required List<String> sources,
  required int stored,
}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      registerAppSqlFunctions(rawDb);
      rawDb.execute('PRAGMA user_version = $version');
      // Real libraries this old always have both; v66 and v72 alter them.
      createPreV66DiveDataSourcesTableRaw(rawDb);
      createV71MediaTableRaw(rawDb);
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT NOT NULL,
          use_dive_computer_cns_data INTEGER NOT NULL DEFAULT 0,
          ${sources.map((c) => '$c INTEGER NOT NULL DEFAULT 1').join(',\n          ')}
        )
      ''');
      rawDb.execute(
        'INSERT INTO diver_settings '
        '(id, diver_id, use_dive_computer_cns_data, ${sources.join(', ')}) '
        "VALUES ('s1', 'd1', 1, ${List.filled(sources.length, stored).join(', ')})",
      );
    },
  );
}

Future<Map<String, Object?>> _settingsRow(AppDatabase db) async {
  final row = await db
      .customSelect("SELECT * FROM diver_settings WHERE id = 's1'")
      .getSingle();
  return row.data;
}

void main() {
  test('both starting versions climb the rest of the ladder', () {
    // Each start must run every later rung, or the survival checks below
    // would pass without exercising anything.
    expect(AppDatabase.currentSchemaVersion, greaterThan(_allSourcesVersion));
    expect(
      AppDatabase.migrationStepCount(_earlyVersion),
      greaterThan(AppDatabase.migrationStepCount(_allSourcesVersion)),
    );
    expect(AppDatabase.migrationStepCount(_allSourcesVersion), greaterThan(1));
  });

  for (final stored in [0, 1]) {
    final label = stored == 0 ? 'computer (0)' : 'calculated (1)';

    test('NDL, TTS and CNS stored as $label at v$_earlyVersion survive the '
        'ladder', () async {
      final db = AppDatabase(
        _libraryAt(_earlyVersion, sources: _v42Sources, stored: stored),
      );
      addTearDown(db.close);

      final row = await _settingsRow(db);
      expect(row['default_ndl_source'], stored);
      expect(row['default_tts_source'], stored);
      expect(row['default_cns_source'], stored);
      // Added later by their own rungs, so they take the column default.
      expect(row['default_deco_stop_source'], 1);
      expect(row['default_gtr_source'], 1);
      expect(row, isNot(contains('default_ceiling_source')));
    });

    test('every source stored as $label at v$_allSourcesVersion survives the '
        'ladder', () async {
      final db = AppDatabase(
        _libraryAt(_allSourcesVersion, sources: _v177Sources, stored: stored),
      );
      addTearDown(db.close);

      final row = await _settingsRow(db);
      for (final column in _v177Sources) {
        if (column == 'default_ceiling_source') continue;
        expect(row[column], stored, reason: '$column was rewritten');
      }
      expect(row, isNot(contains('default_ceiling_source')));
    });
  }
}
