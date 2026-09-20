import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'package:submersion/features/universal_import/data/services/divinglog_profile_codec.dart';
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
    final lower = tables.map((t) => t.toLowerCase()).toSet();
    const foreignMarkers = ['zdive', 'dive_details'];
    if (foreignMarkers.any(lower.contains)) return false;
    return _requiredTables.every((t) => lower.contains(t.toLowerCase()));
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

  /// Every `Logbook` column phase 1 wants. Any the file lacks is dropped
  /// from the SELECT and read as null.
  static const _logbookColumns = [
    'ID',
    'UUID',
    'Number',
    'Divedate',
    'Entrytime',
    'Country',
    'City',
    'Place',
    'Buddy',
    'Divemaster',
    'Comments',
    'Depth',
    'Divetime',
    'Airtemp',
    'Watertemp',
    'Weight',
    'Divesuit',
    'Computer',
    'Visibility',
    'SupplyType',
    'ProfileInt',
    'Profile',
    'Profile2',
    'Profile3',
    'Profile4',
    'Profile5',
    'TankSize',
    'PresS',
    'PresE',
    'PresW',
    'O2',
    'He',
    'DblTank',
  ];

  static const _tankColumns = [
    'LogID',
    'TankID',
    'TankSize',
    'PresS',
    'PresE',
    'PresW',
    'O2',
    'He',
    'DblTank',
  ];

  /// Reads every dive, its cylinders and its decoded profile.
  ///
  /// Throws [FormatException] when there is no `Logbook` table, which the
  /// parser turns into a fatal import warning. Everything else degrades.
  static Future<DivingLogLogbook> readAll(Uint8List bytes) async {
    return _withDb(bytes, (db) {
      final caps = probeCapabilities(db);
      if (!caps.hasTable('Logbook')) {
        throw const FormatException('No Logbook table');
      }

      final notes = <String>[];
      final missing = caps.missingColumns('Logbook', _logbookColumns);
      if (missing.isNotEmpty) {
        notes.add('Logbook is missing: ${missing.join(', ')}');
      }

      final tombstones = _readTombstones(db, caps);
      final tanksByLogId = _readTanks(db, caps);
      final selectList = caps.selectList('Logbook', _logbookColumns);
      final table = caps.actualTable('Logbook')!;
      final rows = db.select('SELECT $selectList FROM "$table"');

      final dives = <DivingLogRawDive>[];
      for (final row in rows) {
        final uuid = _str(row, 'UUID');
        if (uuid != null && tombstones.contains(uuid)) continue;
        final id = _int(row, 'ID');
        if (id == null) continue;

        final inline = _inlineTank(row);
        dives.add(
          DivingLogRawDive(
            id: id,
            uuid: uuid,
            number: _int(row, 'Number'),
            diveDate: _str(row, 'Divedate'),
            entryTime: _str(row, 'Entrytime'),
            country: _str(row, 'Country'),
            city: _str(row, 'City'),
            place: _str(row, 'Place'),
            buddy: _str(row, 'Buddy'),
            divemaster: _str(row, 'Divemaster'),
            comments: _str(row, 'Comments'),
            depthMeters: _double(row, 'Depth'),
            diveTimeMinutes: _double(row, 'Divetime'),
            airTempCelsius: _double(row, 'Airtemp'),
            waterTempCelsius: _double(row, 'Watertemp'),
            weightKg: _double(row, 'Weight'),
            divesuit: _str(row, 'Divesuit'),
            computer: _str(row, 'Computer'),
            visibilityCode: _int(row, 'Visibility'),
            supplyType: _str(row, 'SupplyType'),
            tanks: tanksByLogId[id] ?? (inline == null ? const [] : [inline]),
            samples: DivingLogProfileCodec.decode(
              intervalSeconds: _int(row, 'ProfileInt') ?? 0,
              profile: _str(row, 'Profile'),
              profile2: _str(row, 'Profile2'),
              profile3: _str(row, 'Profile3'),
              profile4: _str(row, 'Profile4'),
              profile5: _str(row, 'Profile5'),
            ),
          ),
        );
      }

      return DivingLogLogbook(
        dives: dives,
        capabilities: caps,
        missingColumnNotes: notes,
      );
    });
  }

  static Set<String> _readTombstones(Database db, DivingLogCapabilities caps) {
    if (!caps.hasTable('DeletedRecords') ||
        !caps.hasColumn('DeletedRecords', 'UUID')) {
      return const {};
    }
    final table = caps.actualTable('DeletedRecords')!;
    final column = caps.actualColumn('DeletedRecords', 'UUID')!;
    final rows = db.select('SELECT "$column" AS "UUID" FROM "$table"');
    return {
      for (final r in rows)
        if (_str(r, 'UUID') case final String u) u,
    };
  }

  static Map<int, List<DivingLogRawTank>> _readTanks(
    Database db,
    DivingLogCapabilities caps,
  ) {
    if (!caps.hasTable('Tank') || !caps.hasColumn('Tank', 'LogID')) {
      return const {};
    }
    final selectList = caps.selectList('Tank', _tankColumns);
    final table = caps.actualTable('Tank')!;
    final tankId = caps.actualColumn('Tank', 'TankID');
    final order = tankId == null ? '' : ' ORDER BY "$tankId"';
    final rows = db.select('SELECT $selectList FROM "$table"$order');

    final out = <int, List<DivingLogRawTank>>{};
    for (final row in rows) {
      final logId = _int(row, 'LogID');
      if (logId == null) continue;
      out[logId] = [
        ...?out[logId],
        DivingLogRawTank(
          tankId: _int(row, 'TankID') ?? out[logId]?.length ?? 0,
          sizeLiters: _double(row, 'TankSize'),
          startPressureBar: _double(row, 'PresS'),
          endPressureBar: _double(row, 'PresE'),
          workingPressureBar: _double(row, 'PresW'),
          o2Percent: _double(row, 'O2'),
          hePercent: _double(row, 'He'),
          isDouble: (_int(row, 'DblTank') ?? 0) > 0,
        ),
      ];
    }
    return out;
  }

  /// The cylinder carried on the `Logbook` row itself, used when the `Tank`
  /// table is absent or holds no row for this dive. Null when the row has
  /// no cylinder data at all, so a dive without gas does not gain an empty
  /// tank.
  static DivingLogRawTank? _inlineTank(Row row) {
    final size = _double(row, 'TankSize');
    final start = _double(row, 'PresS');
    final end = _double(row, 'PresE');
    final o2 = _double(row, 'O2');
    if (size == null && start == null && end == null && o2 == null) {
      return null;
    }
    return DivingLogRawTank(
      tankId: 0,
      sizeLiters: size,
      startPressureBar: start,
      endPressureBar: end,
      workingPressureBar: _double(row, 'PresW'),
      o2Percent: o2,
      hePercent: _double(row, 'He'),
      isDouble: (_int(row, 'DblTank') ?? 0) > 0,
    );
  }

  /// Reads a column that the SELECT may not have included at all, so a
  /// missing column and a null value are the same thing to callers.
  static Object? _cell(Row row, String column) {
    try {
      return row[column];
    } catch (_) {
      return null;
    }
  }

  static String? _str(Row row, String column) {
    final v = _cell(row, column);
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(Row row, String column) {
    final v = _cell(row, column);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return v == null ? null : int.tryParse(v.toString().trim());
  }

  static double? _double(Row row, String column) {
    final v = _cell(row, column);
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return v == null ? null : double.tryParse(v.toString().trim());
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
