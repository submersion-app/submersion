import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

/// One GF99 reading from `dive_log_records`, in seconds from the start of
/// the dive and whole percent as the computer logged it.
class ShearwaterGf99Sample {
  final int timeSeconds;
  final int gf99;

  const ShearwaterGf99Sample({required this.timeSeconds, required this.gf99});

  @override
  bool operator ==(Object other) =>
      other is ShearwaterGf99Sample &&
      other.timeSeconds == timeSeconds &&
      other.gf99 == gf99;

  @override
  int get hashCode => Object.hash(timeSeconds, gf99);

  @override
  String toString() => 'ShearwaterGf99Sample($timeSeconds s, $gf99%)';
}

/// Raw dive data read directly from a Shearwater Cloud SQLite database.
///
/// Fields map 1:1 to columns from the dive_details and log_data tables.
/// Binary log data is decompressed; JSON string columns are pre-parsed.
/// Empty strings from the database are normalized to null.
///
/// The computer-tissue fields ([gf99Samples], [startGFS], [gfMin], [gfMax],
/// [decoModel], [startCNS], [endCNS]) come from the optional `dive_logs` and
/// `dive_log_records` tables; older exports lack them and read as empty/null.
class ShearwaterRawDive {
  final String diveId;
  final String? diveDate;
  final double? depth;
  final double? averageDepth;
  final int? diveLengthTime;
  final String? diveNumber;
  final String? serialNumber;
  final String? location;
  final String? site;
  final String? buddy;
  final String? notes;
  final String? environment;
  final String? visibility;
  final String? weather;
  final String? conditions;
  final String? airTemperature;
  final String? weight;
  final String? dress;
  final String? apparatus;
  final String? thermalComfort;
  final String? workload;
  final String? problems;
  final String? malfunctions;
  final String? symptoms;
  final String? gnssEntryLocation;
  final String? gnssExitLocation;
  final String? gasNotes;
  final String? gearNotes;
  final String? issueNotes;
  final double? endGF99;
  final String? fileName;
  final Uint8List? decompressedLogData;
  final Map<String, dynamic>? tankProfileData;
  final Map<String, dynamic>? calculatedValues;
  final Map<String, dynamic>? headerJson;
  final Map<String, dynamic>? footerJson;

  /// Per-sample GF99 from `dive_log_records`, ordered by time.
  final List<ShearwaterGf99Sample> gf99Samples;

  /// Surface GF at the start of the dive (`dive_logs.startGFS`), percent.
  final double? startGFS;

  /// Gradient factors (`dive_logs.gfMin` / `gfMax`), percent.
  final int? gfMin;
  final int? gfMax;

  /// Deco model as Shearwater spells it ('GF', 'VPM-B', 'VPM-B/GFS',
  /// 'DCIEM'); null when absent or unrecognised.
  final String? decoModel;

  /// CNS at the start and end of the dive (`dive_logs.startCNS` / `endCNS`),
  /// percent.
  final double? startCNS;
  final double? endCNS;

  const ShearwaterRawDive({
    required this.diveId,
    this.diveDate,
    this.depth,
    this.averageDepth,
    this.diveLengthTime,
    this.diveNumber,
    this.serialNumber,
    this.location,
    this.site,
    this.buddy,
    this.notes,
    this.environment,
    this.visibility,
    this.weather,
    this.conditions,
    this.airTemperature,
    this.weight,
    this.dress,
    this.apparatus,
    this.thermalComfort,
    this.workload,
    this.problems,
    this.malfunctions,
    this.symptoms,
    this.gnssEntryLocation,
    this.gnssExitLocation,
    this.gasNotes,
    this.gearNotes,
    this.issueNotes,
    this.endGF99,
    this.fileName,
    this.decompressedLogData,
    this.tankProfileData,
    this.calculatedValues,
    this.headerJson,
    this.footerJson,
    this.gf99Samples = const [],
    this.startGFS,
    this.gfMin,
    this.gfMax,
    this.decoModel,
    this.startCNS,
    this.endCNS,
  });
}

/// Reads dives from a Shearwater Cloud SQLite database.
///
/// The Shearwater Cloud app exports its dive log as a SQLite database
/// with two primary tables: dive_details (metadata) and log_data (binary
/// dive profile data). This reader validates the database structure,
/// queries both tables, decompresses the binary BLOBs, and parses the
/// embedded JSON fields.
class ShearwaterDbReader {
  static const _requiredTables = ['dive_details', 'log_data'];

  static const _query = '''
SELECT dd.DiveId, dd.DiveDate, dd.Depth, dd.AverageDepth,
  dd.DiveLengthTime, dd.DiveNumber, dd.SerialNumber,
  dd.Location, dd.Site, dd.Buddy, dd.Notes,
  dd.Environment, dd.Visibility, dd.Weather, dd.Conditions,
  dd.AirTemperature, dd.Weight, dd.Dress, dd.Apparatus,
  dd.ThermalComfort, dd.Workload, dd.Problems,
  dd.Malfunctions, dd.Symptoms,
  dd.GnssEntryLocation, dd.GnssExitLocation,
  dd.TankProfileData,
  dd.GasNotes, dd.GearNotes, dd.IssueNotes, dd.EndGF99,
  ld.file_name, ld.data_bytes_1, ld.data_bytes_2,
  ld.data_bytes_3, ld.calculated_values_from_samples
FROM dive_details dd
LEFT JOIN log_data ld ON dd.DiveId = ld.log_id
ORDER BY dd.DiveDate
''';

  // The header table keys on the same id as dive_details.DiveId, and the
  // sample table refers to it through diveLogId (Shearwater Cloud's own
  // index, dive_log_records_diveLogId). Both tables are optional.
  static const _diveLogsTable = 'dive_logs';
  static const _diveLogRecordsTable = 'dive_log_records';
  static const _diveLogColumns = [
    'startGFS',
    'gfMin',
    'gfMax',
    'decoModel',
    'startCNS',
    'endCNS',
  ];
  static const _gf99RecordColumns = ['diveLogId', 'currentTime', 'gf99'];
  static const _gf99Query = '''
SELECT currentTime, gf99 FROM dive_log_records
WHERE diveLogId = ? AND currentTime IS NOT NULL AND gf99 IS NOT NULL
ORDER BY currentTime
''';

  /// Shearwater's deco model codes, as `dive_logs.decoModel` stores them.
  static const _decoModelNames = {
    0: 'GF',
    1: 'VPM-B',
    2: 'VPM-B/GFS',
    3: 'DCIEM',
  };

  /// Synchronous companion to [isShearwaterCloudDb] for callers that
  /// have already probed the SQLite table set (e.g. the format detector
  /// runs every DB-flavor check against one probe to avoid doubling
  /// temp-file I/O).
  static bool matchesTables(Set<String> tables) =>
      _requiredTables.every(tables.contains);

  /// Writes [bytes] to a temp SQLite file, opens it read-only, and
  /// returns the set of table names. Returns an empty set (doesn't
  /// throw) for non-SQLite inputs. Shared by the format detector so
  /// multiple DB-flavor checks can run against one probe.
  static Future<Set<String>> probeSqliteTableNames(Uint8List bytes) async {
    final tempPath = _tempPath();
    final tempFile = File(tempPath);
    try {
      await tempFile.writeAsBytes(bytes);
      final db = sqlite3.open(tempPath, mode: OpenMode.readOnly);
      try {
        return _listTables(db);
      } finally {
        db.close();
      }
    } catch (_) {
      return const <String>{};
    } finally {
      _deleteTempFile(tempFile);
    }
  }

  /// Returns true if the given bytes represent a Shearwater Cloud database.
  ///
  /// Writes the bytes to a temporary file and opens it as SQLite. Checks
  /// for the presence of the required tables (dive_details, log_data).
  /// Returns false for any non-SQLite file or database missing those tables.
  static Future<bool> isShearwaterCloudDb(Uint8List bytes) async {
    final tempPath = _tempPath();
    final tempFile = File(tempPath);
    try {
      await tempFile.writeAsBytes(bytes);
      final db = sqlite3.open(tempPath, mode: OpenMode.readOnly);
      try {
        final tables = _listTables(db);
        return _requiredTables.every((t) => tables.contains(t));
      } finally {
        db.close();
      }
    } catch (_) {
      return false;
    } finally {
      _deleteTempFile(tempFile);
    }
  }

  /// Reads all dives from the Shearwater Cloud database.
  ///
  /// Joins dive_details with log_data, decompresses binary profile data,
  /// and parses embedded JSON fields. Empty strings are normalized to null.
  static Future<List<ShearwaterRawDive>> readDives(Uint8List bytes) async {
    final tempPath = _tempPath();
    final tempFile = File(tempPath);
    try {
      await tempFile.writeAsBytes(bytes);
      final db = sqlite3.open(tempPath, mode: OpenMode.readOnly);
      try {
        final tables = _listTables(db);
        final diveLogColumns = tables.contains(_diveLogsTable)
            ? _listColumns(db, _diveLogsTable)
            : const <String>{};
        final hasGf99Records =
            tables.contains(_diveLogRecordsTable) &&
            _gf99RecordColumns.every(
              _listColumns(db, _diveLogRecordsTable).contains,
            );
        final rows = db.select(_query);
        return rows.map((row) {
          final diveId = row['DiveId'].toString();
          return _rowToRawDive(
            row,
            header: _readDiveLogHeader(db, diveId, diveLogColumns),
            gf99Samples: hasGf99Records
                ? _readGf99Samples(db, diveId)
                : const [],
          );
        }).toList();
      } finally {
        db.close();
      }
    } finally {
      _deleteTempFile(tempFile);
    }
  }

  // ======================== Internal helpers ========================

  static String _tempPath() {
    return '${Directory.systemTemp.path}'
        '/sw_import_${DateTime.now().millisecondsSinceEpoch}.db';
  }

  static void _deleteTempFile(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Best-effort cleanup; ignore errors.
    }
  }

  static Set<String> _listTables(Database db) {
    final rows = db.select("SELECT name FROM sqlite_master WHERE type='table'");
    return rows.map<String>((r) => r['name'] as String).toSet();
  }

  /// Column names of [table]. PRAGMA takes no bind parameters; [table] is
  /// always one of this class's constants, never user input.
  static Set<String> _listColumns(Database db, String table) {
    final rows = db.select('PRAGMA table_info($table)');
    return rows.map<String>((r) => r['name'] as String).toSet();
  }

  /// The dive's `dive_logs` row, restricted to the tissue columns the export
  /// actually has. Null when the table, all of those columns, or the row is
  /// missing.
  static Row? _readDiveLogHeader(
    Database db,
    String diveId,
    Set<String> availableColumns,
  ) {
    final columns = _diveLogColumns.where(availableColumns.contains).toList();
    if (columns.isEmpty) return null;
    final rows = db.select(
      'SELECT ${columns.join(', ')} FROM dive_logs WHERE diveId = ? LIMIT 1',
      [diveId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// The dive's GF99 series from `dive_log_records`, ordered by time.
  static List<ShearwaterGf99Sample> _readGf99Samples(
    Database db,
    String diveId,
  ) {
    final rows = db.select(_gf99Query, [diveId]);
    final times = <int>[];
    final values = <int>[];
    for (final row in rows) {
      final time = _int(row['currentTime']);
      final gf99 = _int(row['gf99']);
      if (time == null || gf99 == null) continue;
      times.add(time);
      values.add(gf99);
    }
    if (times.isEmpty) return const [];
    final divisor = _currentTimeDivisor(times);
    return List.unmodifiable([
      for (var i = 0; i < times.length; i++)
        ShearwaterGf99Sample(
          timeSeconds: (times[i] / divisor).round(),
          gf99: values[i],
        ),
    ]);
  }

  /// Shearwater Cloud writes `currentTime` in milliseconds (Shearwater
  /// Desktop wrote seconds). Rather than trust one or the other, read the
  /// spacing of the rows: the computers log every 10 s (a few every 5 s or
  /// 2 s), so a median gap of 1000 or more can only be milliseconds.
  static int _currentTimeDivisor(List<int> sortedTimes) {
    final deltas = <int>[];
    for (var i = 1; i < sortedTimes.length; i++) {
      final delta = sortedTimes[i] - sortedTimes[i - 1];
      if (delta > 0) deltas.add(delta);
    }
    if (deltas.isEmpty) return 1000;
    deltas.sort();
    return deltas[deltas.length ~/ 2] >= 1000 ? 1000 : 1;
  }

  /// Spells `dive_logs.decoModel`: an integer code in every export seen so
  /// far, passed through when an export already stores a name.
  @visibleForTesting
  static String? decoModelName(dynamic value) {
    if (value == null) return null;
    if (value is int) return _decoModelNames[value];
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final code = int.tryParse(text);
    return code == null ? text : _decoModelNames[code];
  }

  static ShearwaterRawDive _rowToRawDive(
    Row row, {
    Row? header,
    List<ShearwaterGf99Sample> gf99Samples = const [],
  }) {
    return ShearwaterRawDive(
      diveId: row['DiveId'].toString(),
      diveDate: _str(row['DiveDate']),
      depth: _double(row['Depth']),
      averageDepth: _double(row['AverageDepth']),
      diveLengthTime: _int(row['DiveLengthTime']),
      diveNumber: _str(row['DiveNumber']),
      serialNumber: _str(row['SerialNumber']),
      location: _str(row['Location']),
      site: _str(row['Site']),
      buddy: _str(row['Buddy']),
      notes: _str(row['Notes']),
      environment: _str(row['Environment']),
      visibility: _str(row['Visibility']),
      weather: _str(row['Weather']),
      conditions: _str(row['Conditions']),
      airTemperature: _str(row['AirTemperature']),
      weight: _str(row['Weight']),
      dress: _str(row['Dress']),
      apparatus: _str(row['Apparatus']),
      thermalComfort: _str(row['ThermalComfort']),
      workload: _str(row['Workload']),
      problems: _str(row['Problems']),
      malfunctions: _str(row['Malfunctions']),
      symptoms: _str(row['Symptoms']),
      gnssEntryLocation: _str(row['GnssEntryLocation']),
      gnssExitLocation: _str(row['GnssExitLocation']),
      gasNotes: _str(row['GasNotes']),
      gearNotes: _str(row['GearNotes']),
      issueNotes: _str(row['IssueNotes']),
      endGF99: _double(row['EndGF99']),
      fileName: _str(row['file_name']),
      decompressedLogData: _decompressDataBytes1(row['data_bytes_1']),
      headerJson: _decodeJsonBlob(row['data_bytes_2']),
      footerJson: _decodeJsonBlob(row['data_bytes_3']),
      tankProfileData: _decodeJsonString(row['TankProfileData']),
      calculatedValues: _decodeJsonString(
        row['calculated_values_from_samples'],
      ),
      gf99Samples: gf99Samples,
      startGFS: _double(_headerValue(header, 'startGFS')),
      gfMin: _int(_headerValue(header, 'gfMin')),
      gfMax: _int(_headerValue(header, 'gfMax')),
      decoModel: decoModelName(_headerValue(header, 'decoModel')),
      startCNS: _double(_headerValue(header, 'startCNS')),
      endCNS: _double(_headerValue(header, 'endCNS')),
    );
  }

  /// A `dive_logs` value, or null when the row or the column is missing.
  static dynamic _headerValue(Row? header, String column) {
    if (header == null || !header.keys.contains(column)) return null;
    return header[column];
  }

  /// Normalizes a value to a non-empty String or null.
  static String? _str(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    return s.isEmpty ? null : s;
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  /// Decompresses data_bytes_1: skip 4-byte length prefix, then decompress.
  ///
  /// Shearwater Cloud stores binary dive data as:
  ///   [4-byte LE decompressed size] [gzip stream]
  ///
  /// Some Shearwater Cloud databases produce gzip streams with zeroed-out
  /// CRC32/ISIZE trailers, which Dart's strict [GZipCodec] rejects. We
  /// try [GZipCodec] first, then fall back to raw deflate decompression
  /// (skipping the 10-byte gzip header) which ignores the trailer.
  static Uint8List? _decompressDataBytes1(dynamic value) {
    if (value == null) return null;
    final Uint8List raw;
    if (value is Uint8List) {
      raw = value;
    } else if (value is List<int>) {
      raw = Uint8List.fromList(value);
    } else {
      return null;
    }
    if (raw.length <= 14) return null; // 4 prefix + 10 gzip header minimum

    final gzipBytes = raw.sublist(4);

    // Fast path: standard GZipCodec (works when CRC/trailer are valid).
    try {
      return Uint8List.fromList(GZipCodec().decode(gzipBytes));
    } catch (_) {
      // Fall through to raw deflate.
    }

    // Fallback: skip gzip header and decompress as raw deflate.
    // This handles streams with zeroed-out CRC32/ISIZE trailers.
    try {
      final deflateStart = _gzipHeaderLength(gzipBytes);
      if (deflateStart == null) return null;
      final deflateData = gzipBytes.sublist(deflateStart);
      final decoded = ZLibDecoder(raw: true).convert(deflateData);
      return Uint8List.fromList(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Returns the byte offset where the deflate data starts in a gzip stream.
  /// Returns null if the stream doesn't look like valid gzip.
  static int? _gzipHeaderLength(Uint8List gz) {
    if (gz.length < 10) return null;
    if (gz[0] != 0x1F || gz[1] != 0x8B) return null; // not gzip magic
    if (gz[2] != 0x08) return null; // not deflate method

    final flags = gz[3];
    var offset = 10; // minimum gzip header

    // FEXTRA
    if (flags & 0x04 != 0) {
      if (gz.length < offset + 2) return null;
      final xlen = gz[offset] | (gz[offset + 1] << 8);
      offset += 2 + xlen;
    }
    // FNAME
    if (flags & 0x08 != 0) {
      while (offset < gz.length && gz[offset] != 0) {
        offset++;
      }
      offset++; // skip null terminator
    }
    // FCOMMENT
    if (flags & 0x10 != 0) {
      while (offset < gz.length && gz[offset] != 0) {
        offset++;
      }
      offset++;
    }
    // FHCRC
    if (flags & 0x02 != 0) {
      offset += 2;
    }

    return offset < gz.length ? offset : null;
  }

  /// Decodes data_bytes_2 and data_bytes_3: UTF-8 decode the BLOB, then JSON
  /// parse.
  static Map<String, dynamic>? _decodeJsonBlob(dynamic value) {
    if (value == null) return null;
    try {
      final String text;
      if (value is Uint8List) {
        text = utf8.decode(value);
      } else if (value is List<int>) {
        text = utf8.decode(value);
      } else {
        text = value.toString();
      }
      if (text.isEmpty) return null;
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parses a JSON string column (TankProfileData, calculated_values_from_samples).
  static Map<String, dynamic>? _decodeJsonString(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    if (s.isEmpty) return null;
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}
