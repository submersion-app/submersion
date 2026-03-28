import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

/// Raw dive data read directly from a Shearwater Cloud SQLite database.
///
/// Fields map 1:1 to columns from the dive_details and log_data tables.
/// Binary log data is decompressed; JSON string columns are pre-parsed.
/// Empty strings from the database are normalized to null.
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
        db.dispose();
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
        final rows = db.select(_query);
        return rows.map(_rowToRawDive).toList();
      } finally {
        db.dispose();
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

  static ShearwaterRawDive _rowToRawDive(Row row) {
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
    );
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
