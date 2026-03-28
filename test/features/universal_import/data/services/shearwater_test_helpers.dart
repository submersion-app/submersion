import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

/// Creates a minimal Shearwater Cloud SQLite database as bytes.
///
/// This allows tests to run without the real fixture file (which is not
/// committed to git). The resulting bytes can be passed directly to
/// [ShearwaterDbReader.isShearwaterCloudDb] and [readDives].
Uint8List createShearwaterTestDb({
  List<ShearwaterTestDive> dives = const [],
  bool includeDiveDetails = true,
  bool includeLogData = true,
}) {
  final tempPath =
      '${Directory.systemTemp.path}/sw_test_${DateTime.now().millisecondsSinceEpoch}.db';
  final db = sqlite3.open(tempPath);
  try {
    if (includeDiveDetails) {
      db.execute('''
        CREATE TABLE dive_details (
          DiveId TEXT PRIMARY KEY,
          DiveDate TEXT,
          Depth REAL,
          AverageDepth REAL,
          DiveLengthTime INTEGER,
          DiveNumber TEXT,
          SerialNumber TEXT,
          Location TEXT,
          Site TEXT,
          Buddy TEXT,
          Notes TEXT,
          Environment TEXT,
          Visibility TEXT,
          Weather TEXT,
          Conditions TEXT,
          AirTemperature TEXT,
          Weight TEXT,
          Dress TEXT,
          Apparatus TEXT,
          ThermalComfort TEXT,
          Workload TEXT,
          Problems TEXT,
          Malfunctions TEXT,
          Symptoms TEXT,
          GnssEntryLocation TEXT,
          GnssExitLocation TEXT,
          TankProfileData TEXT,
          GasNotes TEXT,
          GearNotes TEXT,
          IssueNotes TEXT,
          EndGF99 REAL
        )
      ''');
    }

    if (includeLogData) {
      db.execute('''
        CREATE TABLE log_data (
          log_id TEXT PRIMARY KEY,
          file_name TEXT,
          data_bytes_1 BLOB,
          data_bytes_2 BLOB,
          data_bytes_3 BLOB,
          calculated_values_from_samples TEXT
        )
      ''');
    }

    for (final dive in dives) {
      if (includeDiveDetails) {
        db.execute(
          '''INSERT INTO dive_details (
            DiveId, DiveDate, Depth, AverageDepth, DiveLengthTime,
            DiveNumber, SerialNumber, Location, Site, Buddy, Notes,
            Environment, Visibility, Weather, Conditions,
            AirTemperature, Weight, Dress, Apparatus,
            ThermalComfort, Workload, Problems, Malfunctions, Symptoms,
            GnssEntryLocation, GnssExitLocation, TankProfileData,
            GasNotes, GearNotes, IssueNotes, EndGF99
          ) VALUES (
            ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?,
            ?, ?, ?, ?,
            ?, ?, ?, ?, ?,
            ?, ?, ?,
            ?, ?, ?, ?
          )''',
          [
            dive.diveId,
            dive.diveDate,
            dive.depth,
            dive.averageDepth,
            dive.diveLengthTime,
            dive.diveNumber,
            dive.serialNumber,
            dive.location,
            dive.site,
            dive.buddy,
            dive.notes,
            dive.environment,
            dive.visibility,
            dive.weather,
            dive.conditions,
            dive.airTemperature,
            dive.weight,
            dive.dress,
            dive.apparatus,
            dive.thermalComfort,
            dive.workload,
            dive.problems,
            dive.malfunctions,
            dive.symptoms,
            dive.gnssEntryLocation,
            dive.gnssExitLocation,
            dive.tankProfileDataJson,
            dive.gasNotes,
            dive.gearNotes,
            dive.issueNotes,
            dive.endGF99,
          ],
        );
      }

      if (includeLogData) {
        db.execute(
          '''INSERT INTO log_data (
            log_id, file_name, data_bytes_1, data_bytes_2,
            data_bytes_3, calculated_values_from_samples
          ) VALUES (?, ?, ?, ?, ?, ?)''',
          [
            dive.diveId,
            dive.fileName,
            dive.dataBytes1,
            dive.dataBytes2,
            dive.dataBytes3,
            dive.calculatedValuesJson,
          ],
        );
      }
    }
  } finally {
    db.dispose();
  }

  final bytes = File(tempPath).readAsBytesSync();
  File(tempPath).deleteSync();
  return bytes;
}

/// Compresses [rawData] as gzip with the 4-byte LE length prefix that
/// Shearwater Cloud uses for data_bytes_1.
Uint8List createCompressedLogData(Uint8List rawData) {
  final compressed = GZipCodec().encode(rawData);
  final length = ByteData(4)..setUint32(0, rawData.length, Endian.little);
  return Uint8List.fromList([...length.buffer.asUint8List(), ...compressed]);
}

/// Creates gzip data with zeroed CRC32/ISIZE trailer (triggers raw deflate
/// fallback in the reader).
Uint8List createCompressedLogDataWithZeroedCrc(Uint8List rawData) {
  final normal = createCompressedLogData(rawData);
  // Zero out the last 8 bytes (CRC32 + ISIZE) of the gzip stream
  // The 4-byte prefix is not part of gzip, so gzip starts at index 4
  final result = Uint8List.fromList(normal);
  for (var i = result.length - 8; i < result.length; i++) {
    result[i] = 0;
  }
  return result;
}

/// Encodes a JSON map to a UTF-8 BLOB (for data_bytes_2 / data_bytes_3).
Uint8List jsonToBlob(Map<String, dynamic> json) {
  return Uint8List.fromList(utf8.encode(jsonEncode(json)));
}

/// Test data for a single Shearwater dive row.
class ShearwaterTestDive {
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
  final String? tankProfileDataJson;
  final String? gasNotes;
  final String? gearNotes;
  final String? issueNotes;
  final double? endGF99;
  final String? fileName;
  final Uint8List? dataBytes1;
  final Uint8List? dataBytes2;
  final Uint8List? dataBytes3;
  final String? calculatedValuesJson;

  const ShearwaterTestDive({
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
    this.tankProfileDataJson,
    this.gasNotes,
    this.gearNotes,
    this.issueNotes,
    this.endGF99,
    this.fileName,
    this.dataBytes1,
    this.dataBytes2,
    this.dataBytes3,
    this.calculatedValuesJson,
  });
}
