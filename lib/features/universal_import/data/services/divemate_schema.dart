import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'package:submersion/features/universal_import/data/services/divinglog_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/sqlite_temp_copy.dart';

/// Tells a DiveMate `.ddb` apart from the Diving Log logbook whose schema it
/// reuses (#3110).
///
/// One test for both callers: format detection, which labels the file, and
/// `DivingLogDbReader`, which applies DiveMate's meanings (the `Status`
/// discard flag, the `Profile3` transmitter pressures, the extra columns).
/// Were they to disagree, a file shown as DiveMate could be read as Diving
/// Log.
abstract final class DiveMateSchema {
  /// Whether the open [db], described by [caps], is DiveMate's.
  ///
  /// `DBInfo.PrgName` names the program that wrote the file, and a file
  /// that names one is taken at its word. Only a file that names none falls
  /// back to the `Logbook.TypeOfDive` column, which only DiveMate writes.
  static bool matches(Database db, DivingLogCapabilities caps) {
    final programs = _programNames(db, caps);
    if (programs.isNotEmpty) {
      return programs.any((p) => p.toLowerCase().contains('divemate'));
    }
    return caps.hasColumn('Logbook', 'TypeOfDive');
  }

  /// The non-blank `DBInfo.PrgName` values, empty when the file has none.
  static List<String> _programNames(Database db, DivingLogCapabilities caps) {
    final table = caps.actualTable('DBInfo');
    final column = caps.actualColumn('DBInfo', 'PrgName');
    if (table == null || column == null) return const [];
    try {
      final rows = db.select(
        'SELECT ${quoteSqlIdentifier(column)} AS name '
        'FROM ${quoteSqlIdentifier(table)}',
      );
      return [
        for (final r in rows)
          if (r['name']?.toString().trim() case final String name
              when name.isNotEmpty)
            name,
      ];
    } on SqliteException {
      return const [];
    }
  }

  /// [matches] for raw file bytes. False, not a throw, for anything that is
  /// not a readable SQLite logbook.
  static Future<bool> isDiveMateDb(Uint8List bytes) async {
    try {
      return await withTempSqliteCopy(
        bytes,
        prefix: 'divemate_probe_',
        body: (db) {
          final caps = DivingLogDbReader.probeCapabilities(db);
          return DivingLogDbReader.matchesTables(caps.tables) &&
              matches(db, caps);
        },
      );
    } catch (_) {
      return false;
    }
  }
}
