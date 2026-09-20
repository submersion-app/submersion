import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Reads a Diving Log 5.0 / DiveLogDT SQLite logbook.
///
/// Mirrors the `MacDiveDbReader` pattern: writes the input bytes to a temp
/// file, opens read-only, queries, and deletes the temp file on exit. Safe
/// for concurrent calls (each invocation uses a unique microsecond-suffixed
/// temp path).
///
/// Unlike the MacDive reader this probes the schema before querying.
/// DiveLogDT on macOS and iOS and Diving Log on Windows share a format but
/// have drifted, so a hard-coded column list would throw on a file we have
/// never seen. See the design doc for the reasoning.
class DivingLogDbReader {
  /// `Logbook` alone identifies the format. `Tank` and `DeletedRecords` are
  /// optional: an old or trimmed logbook may have neither, and requiring
  /// them would reject files we can read perfectly well.
  static const _requiredTables = ['Logbook'];

  /// Synchronous companion to [isDivingLogDb] for callers that have already
  /// probed the SQLite table set, matching `MacDiveDbReader.matchesTables`.
  ///
  /// Guards against claiming another flavour's file: MacDive and Shearwater
  /// are checked first at the call site, but a Core Data export could in
  /// principle carry a `Logbook` table, so those markers are excluded here
  /// too.
  static bool matchesTables(Set<String> tables) {
    const foreignMarkers = ['ZDIVE', 'dive_details'];
    if (foreignMarkers.any(tables.contains)) return false;
    return _requiredTables.every(tables.contains);
  }

  /// True when [bytes] is a SQLite database shaped like a Diving Log
  /// logbook. Returns false (does not throw) for non-SQLite input.
  static Future<bool> isDivingLogDb(Uint8List bytes) async {
    try {
      final caps = await readCapabilities(bytes);
      return matchesTables(caps.tables);
    } catch (_) {
      return false;
    }
  }

  /// Opens [bytes] and reports which tables and columns exist.
  static Future<DivingLogCapabilities> readCapabilities(Uint8List bytes) async {
    return _withDb(bytes, probeCapabilities);
  }

  /// Probes an already-open [db]. Split out so reads that already hold a
  /// handle do not reopen the file.
  static DivingLogCapabilities probeCapabilities(Database db) {
    final tableRows = db.select(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final tables = tableRows.map<String>((r) => r['name'] as String).toSet();

    final columns = <String, Set<String>>{};
    for (final table in tables) {
      try {
        final info = db.select('PRAGMA table_info("$table")');
        columns[table] = info.map<String>((r) => r['name'] as String).toSet();
      } catch (_) {
        columns[table] = const <String>{};
      }
    }
    return DivingLogCapabilities(tables: tables, columns: columns);
  }

  /// Writes [bytes] to a temp file, opens read-only, runs [body], and
  /// always deletes the temp file.
  static Future<T> _withDb<T>(
    Uint8List bytes,
    T Function(Database db) body,
  ) async {
    final tmpFile = File(_tmpPath());
    try {
      await tmpFile.writeAsBytes(bytes);
      final db = sqlite3.open(tmpFile.path, mode: OpenMode.readOnly);
      try {
        return body(db);
      } finally {
        db.close();
      }
    } finally {
      _deleteTempFile(tmpFile);
    }
  }

  static String _tmpPath() =>
      '${Directory.systemTemp.path}/divinglog_import_'
      '${DateTime.now().microsecondsSinceEpoch}.sqlite';

  static void _deleteTempFile(File f) {
    try {
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
