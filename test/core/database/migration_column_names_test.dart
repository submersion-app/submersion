import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart';

/// Every column a migration adds by a literal name must be one its Drift
/// table declares. Migration helpers type column names by hand, and Drift
/// derives its own from the getters (`ppO2DecoBand1` is `pp_o2_deco_band1`),
/// so a misspelled add leaves an upgraded database without the column Drift
/// reads, and every read of that table fails (issue #3809).
///
/// fresh_schema_declared_columns_test catches a misspelled beforeOpen
/// backstop; this catches one in a rung that runs only on an upgrade, which
/// a fresh database never reaches. Names built at run time (a map of
/// columns looped over) are not seen here.
void main() {
  /// Columns migrations once added that their tables no longer declare,
  /// each retired by a later rung.
  const retired = {
    // Renamed to gas_consumption_display at v170.
    'diver_settings.sac_unit',
    // Dropped at v261 (issue #767).
    'diver_settings.default_ceiling_source',
    // A v275 staging column, renamed to default_start_pressure in place.
    'diver_settings.default_start_pressure_v275',
    // Renamed to import_source and import_id.
    'dives.wearable_source',
    'dives.wearable_id',
  };

  /// Tables migrations once added columns to that this database no longer
  /// declares.
  const retiredTables = {
    // Dropped at v183, its rows moved to dive_profile_samples.
    'dive_profiles',
    // LocalCacheDatabase's, not this database's.
    'recent_queries',
    'swiss_bathy_tile_cache',
  };

  final patterns = [
    RegExp(r"_addColumnIfMissing\(\s*'(\w+)',\s*'(\w+)'"),
    RegExp(r"addColumnIfStillMissing\(\s*\w+,\s*'(\w+)',\s*'(\w+)'"),
    RegExp(r'ALTER TABLE (\w+) ADD COLUMN (\w+)'),
  ];

  /// Joins adjacent single-quoted literals split across lines, so an
  /// `'ALTER TABLE t '` / `'ADD COLUMN c ...'` pair reads as one statement.
  final adjacentLiterals = RegExp(r"'\s*\n\s*'");

  test('every column a migration adds by name is one Drift reads', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final declared = {
      for (final t in db.allTables)
        t.actualTableName: {for (final c in t.$columns) c.name},
    };

    final misspelled = <String>[];
    final sources = Directory(
      p.join('lib', 'core', 'database'),
    ).listSync(recursive: true).whereType<File>();
    for (final file in sources) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('.g.dart')) {
        continue;
      }
      final source = file.readAsStringSync().replaceAll(adjacentLiterals, '');
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(source)) {
          final table = match.group(1)!;
          final column = match.group(2)!;
          if (retiredTables.contains(table)) continue;
          if (retired.contains('$table.$column')) continue;
          if (declared[table]?.contains(column) ?? false) continue;
          misspelled.add('$table.$column in ${p.basename(file.path)}');
        }
      }
    }
    expect(misspelled, isEmpty);
  });
}
