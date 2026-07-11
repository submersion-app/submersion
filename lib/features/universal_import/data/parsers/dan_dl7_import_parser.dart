import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/dl7/aqualung_zar_dialect.dart';
import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_document.dart';
import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_reader.dart';
import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_units.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

/// Parser for DAN DL7 (.zxu/.zxl) dive log files.
///
/// Handles any spec-conformant DL7 file via the standard segments and
/// enriches the result with the proprietary `ZAR{<AQUALUNG>...}` block that
/// DiverLog+/DiveCloud exports carry (site, GPS, tanks, dive stats, rating,
/// computer identity). Foreign ZAR dialects are ignored.
///
/// Known real-file quirks handled here: the ZDH recording-interval field
/// lies (interval is derived from the time column), the ZDT min-temperature
/// field is written as 0.000000 (min temp comes from ZAR stats or the
/// profile), and the ZRH model code is often empty (model comes from ZAR).
class DanDl7Parser implements ImportParser {
  const DanDl7Parser();

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.danDl7];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final warnings = <ImportWarning>[];
    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};

    if (fileBytes.isEmpty) {
      return ImportPayload(
        entities: entities,
        warnings: const [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Empty file',
          ),
        ],
        metadata: const {'source': 'dan_dl7'},
      );
    }

    final content = utf8.decode(fileBytes, allowMalformed: true);
    final doc = const Dl7Reader().read(content);

    for (final readerWarning in doc.readerWarnings) {
      warnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message: readerWarning,
        ),
      );
    }

    if (doc.dives.isEmpty) {
      warnings.add(
        const ImportWarning(
          severity: ImportWarningSeverity.error,
          message: 'No dives found in DL7 file',
        ),
      );
      return ImportPayload(
        entities: entities,
        warnings: warnings,
        metadata: const {'source': 'dan_dl7'},
      );
    }

    final units = Dl7Units.fromZrh(doc.zrhFields);
    final zar = AqualungZarDialect.parse(doc.zarContent, units: units);

    final dives = <Map<String, dynamic>>[];
    final sitesByUddfId = <String, Map<String, dynamic>>{};

    for (var i = 0; i < doc.dives.length; i++) {
      try {
        final dive = _parseDive(
          doc.dives[i],
          units: units,
          // A ZAR block describes the dive it was exported with. DiveCloud
          // files are single-dive; for multi-dive files only apply ZAR
          // enrichment when the file holds exactly one dive.
          zar: doc.dives.length == 1 ? zar : null,
          zrhFields: doc.zrhFields,
          sitesByUddfId: sitesByUddfId,
        );
        if (dive != null) dives.add(dive);
      } catch (e) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.warning,
            message: 'Skipped dive ${i + 1}: $e',
            entityType: ImportEntityType.dives,
            itemIndex: i,
          ),
        );
      }
    }

    if (dives.isNotEmpty) entities[ImportEntityType.dives] = dives;
    if (sitesByUddfId.isNotEmpty) {
      entities[ImportEntityType.sites] = sitesByUddfId.values.toList();
    }

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: {'source': 'dan_dl7', if (zar?.app != null) 'app': zar!.app},
    );
  }

  Map<String, dynamic>? _parseDive(
    Dl7DiveRecord record, {
    required Dl7Units units,
    required AqualungZarData? zar,
    required List<String> zrhFields,
    required Map<String, Map<String, dynamic>> sitesByUddfId,
  }) {
    String? zdh(int field) =>
        field < record.zdhFields.length &&
            record.zdhFields[field].trim().isNotEmpty
        ? record.zdhFields[field].trim()
        : null;
    String? zdt(int field) =>
        field < record.zdtFields.length &&
            record.zdtFields[field].trim().isNotEmpty
        ? record.zdtFields[field].trim()
        : null;
    String? zrh(int field) =>
        field < zrhFields.length && zrhFields[field].trim().isNotEmpty
        ? zrhFields[field].trim()
        : null;

    final start = _parseDl7Timestamp(zdh(5));
    if (start == null) return null;

    final result = <String, dynamic>{'dateTime': start};

    final airTemp = double.tryParse(zdh(6) ?? '');
    if (airTemp != null) result['airTemp'] = units.tempToCelsius(airTemp);

    final profile = _parseProfile(record.zdpRows, units, zar);
    if (profile.isNotEmpty) result['profile'] = profile;

    final events = _parseViolationEvents(record.zdpRows, profile);
    if (events.isNotEmpty) result['events'] = events;

    final end = _parseDl7Timestamp(zdt(4));
    Duration? runtime = zar?.elapsedDiveTime;
    if (runtime == null && end != null && end.isAfter(start)) {
      runtime = end.difference(start);
    }
    if (runtime == null && profile.isNotEmpty) {
      runtime = Duration(seconds: profile.last['timestamp'] as int);
    }
    if (runtime != null) {
      result['runtime'] = runtime;
      // With a profile, bottom time is derived from the profile by the
      // entity importer; without one, use the runtime directly.
      if (profile.isEmpty) result['duration'] = runtime;
    }

    final zdtMaxDepth = double.tryParse(zdt(3) ?? '');
    final maxDepth =
        zar?.maxDepthMeters ??
        (zdtMaxDepth != null ? units.depthToMeters(zdtMaxDepth) : null);
    if (maxDepth != null) result['maxDepth'] = maxDepth;
    if (zar?.avgDepthMeters != null) result['avgDepth'] = zar!.avgDepthMeters;

    // Water temp preference: ZAR stats, profile minimum, then a positive ZDT
    // value (real DiverLog files write a bogus 0.000000 there).
    double? waterTemp = zar?.minTempCelsius;
    if (waterTemp == null && profile.isNotEmpty) {
      for (final point in profile) {
        final temp = point['temperature'] as double?;
        if (temp != null && (waterTemp == null || temp < waterTemp)) {
          waterTemp = temp;
        }
      }
    }
    if (waterTemp == null) {
      final zdtMinTemp = double.tryParse(zdt(5) ?? '');
      if (zdtMinTemp != null && zdtMinTemp > 0) {
        waterTemp = units.tempToCelsius(zdtMinTemp);
      }
    }
    if (waterTemp != null) result['waterTemp'] = waterTemp;

    final diveNumber = zar?.diveNumber ?? int.tryParse(zdh(2) ?? '');
    if (diveNumber != null) result['diveNumber'] = diveNumber;

    final tanks = _buildTanks(record.zdpRows, zar);
    if (tanks.isNotEmpty) result['tanks'] = tanks;
    final gasSwitches = _parseGasSwitches(record.zdpRows, profile, tanks);
    if (gasSwitches.isNotEmpty) result['gasSwitches'] = gasSwitches;

    if (zar != null) {
      if (zar.duid != null) result['sourceUuid'] = zar.duid;
      if (zar.rating != null) result['rating'] = zar.rating;
      if (zar.surfaceInterval != null) {
        result['surfaceInterval'] = zar.surfaceInterval;
      }
      final title = zar.title?.trim();
      if (title != null && title.isNotEmpty) result['name'] = title;
      if (zar.diveMode == 0) result['diveMode'] = 'oc';
      if (zar.latitude != null && zar.longitude != null) {
        result['latitude'] = zar.latitude;
        result['longitude'] = zar.longitude;
      }
      final siteName = zar.locationName;
      if (siteName != null) {
        final siteId = 'dl7_site_${siteName.toLowerCase()}';
        sitesByUddfId.putIfAbsent(siteId, () {
          final site = <String, dynamic>{'uddfId': siteId, 'name': siteName};
          if (zar.latitude != null) site['latitude'] = zar.latitude;
          if (zar.longitude != null) site['longitude'] = zar.longitude;
          if (zar.country != null) site['country'] = zar.country;
          if (zar.stateProvince != null) site['region'] = zar.stateProvince;
          if (zar.city != null) site['notes'] = 'City: ${zar.city}';
          return site;
        });
        result['site'] = {'uddfId': siteId};
      }
    }

    // Computer identity: ZAR wins, ZRH header fields are the fallback
    // (field 2 model code, field 3 serial).
    final model = zar?.pdcModel ?? zrh(2);
    if (model != null) result['diveComputerModel'] = model;
    final serial = zar?.pdcSerial ?? zrh(3);
    if (serial != null) result['diveComputerSerial'] = serial;
    if (zar?.pdcFirmware != null) {
      result['diveComputerFirmware'] = zar!.pdcFirmware;
    }

    return result;
  }

  /// ZDP columns after the reader drops the leading empty token:
  /// index 0 time, 1 depth, 2 gas switch, 3 PO2, 4 ascent-violation,
  /// 5 deco-violation, 6 ceiling, 7 temperature, 8 warnings,
  /// 9 main tank pressure, 12 CNS.
  List<Map<String, dynamic>> _parseProfile(
    List<List<String>> rows,
    Dl7Units units,
    AqualungZarData? zar,
  ) {
    if (rows.isEmpty) return const [];
    final timesAreDecimalMinutes = rows.any(
      (row) => row.isNotEmpty && row[0].contains('.'),
    );

    final points = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      String? cell(int index) =>
          index < row.length && row[index].trim().isNotEmpty
          ? row[index].trim()
          : null;

      final rawTime = double.tryParse(cell(0) ?? '');
      final rawDepth = double.tryParse(cell(1) ?? '');
      if (rawTime == null || rawDepth == null) continue;

      final timestamp = timesAreDecimalMinutes
          ? (rawTime * 60).round()
          : rawTime.round();
      final point = <String, dynamic>{
        'timestamp': timestamp,
        'depth': units.depthToMeters(rawDepth),
      };

      final temp = double.tryParse(cell(7) ?? '');
      if (temp != null) point['temperature'] = units.tempToCelsius(temp);

      final ceiling = double.tryParse(cell(6) ?? '');
      if (ceiling != null) point['ceiling'] = units.depthToMeters(ceiling);

      final cns = double.tryParse(cell(12) ?? '');
      if (cns != null) point['cns'] = cns;

      final pressure = double.tryParse(cell(9) ?? '');
      if (pressure != null) {
        point['allTankPressures'] = [
          {'pressure': units.pressureToBar(pressure), 'tankIndex': 0},
        ];
      }

      // ZAR DECOTIME array is index-aligned with ZDP samples; a positive
      // value means the diver is in deco at that sample.
      final decoTimes = zar?.decoTimePerSample ?? const [];
      if (i < decoTimes.length && decoTimes[i] > 0) point['decoType'] = 2;

      points.add(point);
    }
    return points;
  }

  /// Column 5 ascent-violation and column 6 deco-violation flags ('T')
  /// become profile events at the sample's timestamp.
  List<Map<String, dynamic>> _parseViolationEvents(
    List<List<String>> rows,
    List<Map<String, dynamic>> profile,
  ) {
    if (rows.isEmpty || profile.isEmpty) return const [];
    final events = <Map<String, dynamic>>[];
    var pointIndex = 0;
    for (final row in rows) {
      final rawTime = row.isNotEmpty ? double.tryParse(row[0].trim()) : null;
      final rawDepth = row.length > 1 ? double.tryParse(row[1].trim()) : null;
      if (rawTime == null || rawDepth == null) continue;
      final timestamp = profile[pointIndex]['timestamp'] as int;
      String flag(int index) =>
          index < row.length ? row[index].trim().toUpperCase() : '';
      if (flag(4) == 'T') {
        events.add({'eventType': 'ascentRateWarning', 'timestamp': timestamp});
      }
      if (flag(5) == 'T') {
        events.add({'eventType': 'decoViolation', 'timestamp': timestamp});
      }
      pointIndex++;
    }
    return events;
  }

  /// Tanks come from the ZAR TANK entries when present; otherwise one tank
  /// is synthesized per distinct gas value in ZDP column 3 (`1` = air,
  /// `2.xy` = nitrox with xy% O2).
  List<Map<String, dynamic>> _buildTanks(
    List<List<String>> rows,
    AqualungZarData? zar,
  ) {
    if (zar != null && zar.tanks.isNotEmpty) {
      final tanks = <Map<String, dynamic>>[];
      for (var i = 0; i < zar.tanks.length; i++) {
        final zarTank = zar.tanks[i];
        final o2 = zarTank.o2Percent ?? 21.0;
        final tank = <String, dynamic>{
          'gasMix': GasMix(o2: o2, he: 0.0),
          'order': i,
          'uddfTankId': _tankRef(i, o2),
        };
        if (zarTank.name != null) tank['name'] = zarTank.name;
        if (zarTank.startPressureBar != null) {
          tank['startPressure'] = zarTank.startPressureBar;
        }
        if (zarTank.endPressureBar != null) {
          tank['endPressure'] = zarTank.endPressureBar;
        }
        if (zarTank.workingPressureBar != null) {
          tank['workingPressure'] = zarTank.workingPressureBar;
        }
        if (zarTank.volumeLiters != null) {
          tank['volume'] = zarTank.volumeLiters;
        }
        tanks.add(tank);
      }
      return tanks;
    }

    final o2Values = <double>[];
    for (final row in rows) {
      final o2 = _gasCellToO2Percent(row.length > 2 ? row[2].trim() : '');
      if (o2 != null && !o2Values.contains(o2)) o2Values.add(o2);
    }
    return [
      for (var i = 0; i < o2Values.length; i++)
        {
          'gasMix': GasMix(o2: o2Values[i], he: 0.0),
          'order': i,
          'uddfTankId': _tankRef(i, o2Values[i]),
        },
    ];
  }

  /// Gas-switch events: a non-empty gas cell after t=0 that differs from the
  /// previous gas becomes a switch referencing the matching tank.
  List<Map<String, dynamic>> _parseGasSwitches(
    List<List<String>> rows,
    List<Map<String, dynamic>> profile,
    List<Map<String, dynamic>> tanks,
  ) {
    if (rows.isEmpty || profile.isEmpty || tanks.isEmpty) return const [];
    final switches = <Map<String, dynamic>>[];
    double? currentO2;
    var pointIndex = 0;
    for (final row in rows) {
      final rawTime = row.isNotEmpty ? double.tryParse(row[0].trim()) : null;
      final rawDepth = row.length > 1 ? double.tryParse(row[1].trim()) : null;
      if (rawTime == null || rawDepth == null) continue;
      final o2 = _gasCellToO2Percent(row.length > 2 ? row[2].trim() : '');
      if (o2 != null) {
        final timestamp = profile[pointIndex]['timestamp'] as int;
        if (currentO2 != null && o2 != currentO2 && timestamp > 0) {
          final tankIndex = tanks.indexWhere(
            (t) => (t['gasMix'] as GasMix).o2 == o2,
          );
          if (tankIndex >= 0) {
            switches.add({
              'timestamp': timestamp,
              'tankRef': tanks[tankIndex]['uddfTankId'],
            });
          }
        }
        currentO2 = o2;
      }
      pointIndex++;
    }
    return switches;
  }

  static String _tankRef(int index, double o2) => 'dl7:$index:o2_${o2.round()}';

  /// `1` (or `1.00`) = air (21% O2); `2.xy` = nitrox with xy% O2.
  static double? _gasCellToO2Percent(String cell) {
    if (cell.isEmpty) return null;
    final value = double.tryParse(cell);
    if (value == null) return null;
    if (value >= 1.0 && value < 2.0) return 21.0;
    if (value >= 2.0 && value < 3.0) {
      final o2 = ((value - 2.0) * 100).round().toDouble();
      return o2 > 0 ? o2 : 21.0;
    }
    return null;
  }

  /// Parses YYYYMMDDHHMMSS (seconds optional) as wall-clock UTC, ignoring
  /// any timezone suffix per the house dive-time convention.
  static DateTime? _parseDl7Timestamp(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 12) return null;
    final year = int.tryParse(digits.substring(0, 4));
    final month = int.tryParse(digits.substring(4, 6));
    final day = int.tryParse(digits.substring(6, 8));
    final hour = int.tryParse(digits.substring(8, 10));
    final minute = int.tryParse(digits.substring(10, 12));
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }
    final second = digits.length >= 14
        ? int.tryParse(digits.substring(12, 14)) ?? 0
        : 0;
    return DateTime.utc(year, month, day, hour, minute, second);
  }
}
