import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_filename_parser.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_value_mapper.dart';

/// Converts [ShearwaterRawDive] objects into `Map<String, dynamic>` entity maps
/// matching the field conventions used by the existing import system
/// ([UddfEntityImporter] / [IncomingDiveData.fromImportMap]).
class ShearwaterDiveMapper {
  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Produces a dive entity map from metadata only (no profile data).
  ///
  /// This is the fallback when FFI parsing fails or binary log data is absent.
  static Map<String, dynamic> mapDiveMetadata(ShearwaterRawDive rawDive) {
    final isImperial = _isImperial(rawDive);
    final filenameInfo = rawDive.fileName != null
        ? ShearwaterFilenameParser.parse(rawDive.fileName!)
        : const ShearwaterFilenameInfo();

    final tanks = mapTanks(rawDive);
    final surfacePressure = _extractSurfacePressure(rawDive);

    return {
      'importSource': 'shearwater_cloud',
      'importId': rawDive.diveId,
      'dateTime': _parseDateTime(rawDive.diveDate),
      'maxDepth': isImperial && rawDive.depth != null
          ? ShearwaterValueMapper.feetToMeters(rawDive.depth!)
          : rawDive.depth,
      'avgDepth': isImperial && rawDive.averageDepth != null
          ? ShearwaterValueMapper.feetToMeters(rawDive.averageDepth!)
          : rawDive.averageDepth,
      'runtime': rawDive.diveLengthTime != null
          ? Duration(seconds: rawDive.diveLengthTime!)
          : null,
      'diveNumber': _parseInt(rawDive.diveNumber),
      if (rawDive.buddy != null) 'buddyRefs': [rawDive.buddy!],
      'notes': _buildNotes(rawDive),
      'siteName': rawDive.site,
      if (rawDive.site != null)
        'site': <String, dynamic>{'uddfId': rawDive.site, 'name': rawDive.site},
      'diveComputerModel': filenameInfo.model,
      'diveComputerSerial': filenameInfo.serial,
      'waterType': ShearwaterValueMapper.mapWaterType(rawDive.environment),
      'visibility': ShearwaterValueMapper.mapVisibility(
        rawDive.visibility,
        isImperial: isImperial,
      ),
      'cloudCover': ShearwaterValueMapper.mapCloudCover(rawDive.weather),
      'currentStrength': ShearwaterValueMapper.mapCurrentStrength(
        rawDive.conditions,
      ),
      'airTemp': _convertTemperature(rawDive.airTemperature, isImperial),
      'weightAmount': _convertWeight(rawDive.weight, isImperial),
      'surfacePressure': surfacePressure,
      'diveMode': _mapDiveMode(rawDive.apparatus),
      'tanks': tanks,
      'profile': const <Map<String, dynamic>>[],
    };
  }

  /// Attempts FFI parsing for profile data, falls back to metadata-only.
  ///
  /// If [rawDive.decompressedLogData] is available, tries to call
  /// [DiveComputerHostApi().parseRawDiveData()] to get rich profile data.
  ///
  /// Platform-level errors ([MissingPluginException], [PlatformException]
  /// with code `UNSUPPORTED`) are rethrown so the caller can detect that
  /// FFI is unavailable and skip it for remaining dives. Data-level errors
  /// (corrupt dive data) are caught and added to [warnings].
  static Future<Map<String, dynamic>> mapDive(
    ShearwaterRawDive rawDive, {
    List<ImportWarning>? warnings,
  }) async {
    final baseMap = mapDiveMetadata(rawDive);

    final logData = rawDive.decompressedLogData;
    if (logData == null || logData.isEmpty) {
      return baseMap;
    }

    final filenameInfo = rawDive.fileName != null
        ? ShearwaterFilenameParser.parse(rawDive.fileName!)
        : const ShearwaterFilenameInfo();

    final vendorProduct = filenameInfo.model != null
        ? ShearwaterFilenameParser.vendorProduct(filenameInfo.model!)
        : null;

    if (vendorProduct == null) {
      warnings?.add(
        const ImportWarning(
          severity: ImportWarningSeverity.warning,
          message:
              'Could not determine dive computer model for profile parsing',
          entityType: ImportEntityType.dives,
        ),
      );
      return baseMap;
    }

    try {
      final parsed = await _parseWithFfi(
        vendor: vendorProduct.$1,
        product: vendorProduct.$2,
        data: logData,
      );
      return mergeWithParsedDive(baseMap, parsed);
    } on MissingPluginException {
      rethrow;
    } on PlatformException catch (e) {
      if (e.code == 'UNSUPPORTED' || e.code == 'channel-error') rethrow;
      warnings?.add(
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message: 'Profile parsing failed for dive ${rawDive.diveId}: $e',
          entityType: ImportEntityType.dives,
        ),
      );
      return baseMap;
    } catch (e) {
      warnings?.add(
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message: 'Profile parsing failed for dive ${rawDive.diveId}: $e',
          entityType: ImportEntityType.dives,
        ),
      );
      return baseMap;
    }
  }

  /// Parse [TankProfileData] JSON into tank entity maps.
  ///
  /// Only active tanks (where `DiveTransmitter.IsOn == true`) are included.
  /// Pressures are converted from PSI to bar (rounded to int).
  static List<Map<String, dynamic>> mapTanks(ShearwaterRawDive rawDive) {
    final tankData =
        rawDive.tankProfileData?['TankData'] as List<dynamic>? ?? [];
    if (tankData.isEmpty) return const [];

    final results = <Map<String, dynamic>>[];

    for (final raw in tankData) {
      final tank = raw as Map<String, dynamic>;
      final transmitter = tank['DiveTransmitter'] as Map<String, dynamic>?;

      if (transmitter == null || transmitter['IsOn'] != true) continue;

      final gasProfile = tank['GasProfile'] as Map<String, dynamic>?;
      final o2 = _toDouble(gasProfile?['O2Percent']) ?? 21.0;
      final he = _toDouble(gasProfile?['HePercent']) ?? 0.0;

      results.add({
        'gasMix': GasMix(o2: o2, he: he),
        'startPressure': _parsePsiPressure(tank['StartPressurePSI']),
        'endPressure': _parsePsiPressure(tank['EndPressurePSI']),
        'name': transmitter['Name'] as String? ?? '',
      });
    }

    return results;
  }

  /// Deduplicates dive sites by name across a list of raw dives.
  ///
  /// Each unique site name produces one site entity map with `name`,
  /// `uddfId`, and optional location fields.
  static List<Map<String, dynamic>> mapSites(List<ShearwaterRawDive> dives) {
    final siteMap = <String, Map<String, dynamic>>{};

    for (final dive in dives) {
      final name = dive.site;
      if (name == null) continue;

      siteMap.putIfAbsent(name, () {
        final site = <String, dynamic>{'name': name, 'uddfId': name};

        if (dive.location != null) {
          site['notes'] = dive.location;
        }

        final coords = _parseGnssLocation(dive.gnssEntryLocation);
        if (coords != null) {
          site['latitude'] = coords.$1;
          site['longitude'] = coords.$2;
        }

        return site;
      });
    }

    return siteMap.values.toList();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static bool _isImperial(ShearwaterRawDive rawDive) {
    final unitSystem = rawDive.footerJson?['UnitSystem'];
    return unitSystem == 1;
  }

  static DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null) return null;
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed;
    // Normalize naive/local datetimes to UTC wall-time to match the
    // convention used by other import paths (ValueTransforms.parseDate).
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  static int? _parseInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value);
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static double? _convertTemperature(String? value, bool isImperial) {
    if (value == null) return null;
    final numValue = double.tryParse(value);
    if (numValue == null) return null;
    return isImperial
        ? ShearwaterValueMapper.fahrenheitToCelsius(numValue)
        : numValue;
  }

  static double? _convertWeight(String? value, bool isImperial) {
    if (value == null) return null;
    final numValue = double.tryParse(value);
    if (numValue == null) return null;
    return isImperial ? ShearwaterValueMapper.lbsToKg(numValue) : numValue;
  }

  /// Parses a PSI string value and converts to bar.
  ///
  /// Returns null for empty or non-numeric values.
  static int? _parsePsiPressure(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    if (str.isEmpty) return null;
    final psi = double.tryParse(str);
    if (psi == null) return null;
    return ShearwaterValueMapper.psiToBar(psi).round();
  }

  static DiveMode _mapDiveMode(String? apparatus) {
    if (apparatus == null) return DiveMode.oc;
    final lower = apparatus.toLowerCase();
    if (lower.contains('closed circuit') || lower == 'ccr') return DiveMode.ccr;
    if (lower.contains('semi-closed') || lower == 'scr') return DiveMode.scr;
    return DiveMode.oc;
  }

  static String _buildNotes(ShearwaterRawDive rawDive) {
    final userNotes = rawDive.notes;
    final extraNotes = ShearwaterValueMapper.buildExtraNotes(
      weather: rawDive.weather,
      conditions: rawDive.conditions,
      dress: rawDive.dress,
      thermalComfort: rawDive.thermalComfort,
      workload: rawDive.workload,
      problems: rawDive.problems,
      malfunctions: rawDive.malfunctions,
      symptoms: rawDive.symptoms,
      gasNotes: rawDive.gasNotes,
      gearNotes: rawDive.gearNotes,
      issueNotes: rawDive.issueNotes,
    );

    if (userNotes != null && extraNotes != null) {
      return '$userNotes\n\n$extraNotes';
    }
    return userNotes ?? extraNotes ?? '';
  }

  /// Extracts surface pressure in bar from the first tank's
  /// SurfacePressureMBar field.
  static double? _extractSurfacePressure(ShearwaterRawDive rawDive) {
    final tankData =
        rawDive.tankProfileData?['TankData'] as List<dynamic>? ?? [];
    if (tankData.isEmpty) return null;

    final firstTank = tankData[0] as Map<String, dynamic>;
    final mbar = _toDouble(firstTank['SurfacePressureMBar']);
    if (mbar == null) return null;
    return ShearwaterValueMapper.mbarToBar(mbar);
  }

  /// Parses a GNSS location string "lat,lon" into a coordinate pair.
  static (double, double)? _parseGnssLocation(String? gnss) {
    if (gnss == null || gnss.isEmpty) return null;
    final parts = gnss.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lon = double.tryParse(parts[1].trim());
    if (lat == null || lon == null) return null;
    return (lat, lon);
  }

  static Future<pigeon.ParsedDive> _parseWithFfi({
    required String vendor,
    required String product,
    required Uint8List data,
  }) async {
    // Look up the libdivecomputer model number. For now, pass 0 as a
    // placeholder -- the native side resolves by vendor + product name.
    final api = pigeon.DiveComputerHostApi();
    return api.parseRawDiveData(vendor, product, 0, data);
  }

  /// Merges parsed profile and deco data into the base metadata map.
  @visibleForTesting
  static Map<String, dynamic> mergeWithParsedDive(
    Map<String, dynamic> baseMap,
    pigeon.ParsedDive parsed,
  ) {
    final merged = Map<String, dynamic>.from(baseMap);

    // Override depth/duration with parsed values (more accurate)
    merged['maxDepth'] = parsed.maxDepthMeters;
    merged['avgDepth'] = parsed.avgDepthMeters;
    merged['runtime'] = Duration(seconds: parsed.durationSeconds);

    // Add deco model info
    if (parsed.decoAlgorithm != null) {
      merged['decoAlgorithm'] = parsed.decoAlgorithm;
    }
    if (parsed.gfLow != null) {
      merged['gradientFactorLow'] = parsed.gfLow;
    }
    if (parsed.gfHigh != null) {
      merged['gradientFactorHigh'] = parsed.gfHigh;
    }

    // Override dive mode from parsed data (more accurate than apparatus guess).
    if (parsed.diveMode != null) {
      merged['diveMode'] = switch (parsed.diveMode) {
        'ccr' => DiveMode.ccr,
        'scr' => DiveMode.scr,
        _ => DiveMode.oc,
      };
    }

    // Build profile samples with all available sensor data.
    merged['profile'] = parsed.samples.map((s) {
      final sampleMap = <String, dynamic>{
        'timestamp': s.timeSeconds,
        'depth': s.depthMeters,
      };
      if (s.temperatureCelsius != null) {
        sampleMap['temperature'] = s.temperatureCelsius;
      }
      if (s.pressureBar != null) {
        sampleMap['pressure'] = s.pressureBar;
      }
      if (s.setpoint != null) {
        sampleMap['setpoint'] = s.setpoint;
      }
      if (s.ppo2 != null) {
        sampleMap['ppO2'] = s.ppo2;
      }
      if (s.heartRate != null) {
        sampleMap['heartRate'] = s.heartRate;
      }
      if (s.cns != null) {
        sampleMap['cns'] = s.cns;
      }
      if (s.rbt != null) {
        sampleMap['rbt'] = s.rbt;
      }
      if (s.tts != null) {
        sampleMap['tts'] = s.tts;
      }
      if (s.decoType != null) {
        sampleMap['decoType'] = s.decoType;
      }
      if (s.decoDepth != null && s.decoType != null && s.decoType != 0) {
        sampleMap['ceiling'] = s.decoDepth;
      }
      if (s.decoType == 0 && s.decoTime != null) {
        sampleMap['ndl'] = s.decoTime;
      }
      return sampleMap;
    }).toList();

    // Extract water temperature from profile samples if not already set
    if (merged['waterTemp'] == null) {
      final temps = parsed.samples
          .map((s) => s.temperatureCelsius)
          .whereType<double>()
          .toList();
      if (temps.isNotEmpty) {
        merged['waterTemp'] = temps.reduce((a, b) => a < b ? a : b);
      }
    }

    return merged;
  }
}
