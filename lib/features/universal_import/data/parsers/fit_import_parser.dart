import 'dart:typed_data';

import 'package:submersion/features/dive_import/data/services/fit_parser_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

/// Parser adapter for Garmin FIT binary files.
///
/// Wraps [FitParserService] and converts its enriched [ImportedDive] output
/// into the unified [ImportPayload] format using the same keys UDDF imports
/// produce, so the shared `UddfEntityImporter` persists tanks, gas, deco, GPS
/// and CNS/OTU without any FIT-specific persistence code.
class FitImportParser implements ImportParser {
  final FitParserService _service;

  const FitImportParser({FitParserService service = const FitParserService()})
    : _service = service;

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.fit];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final dive = await _service.parseFitFile(fileBytes);

    if (dive == null) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message:
                'Could not parse FIT file. '
                'The file may be corrupt or not contain dive data.',
          ),
        ],
      );
    }

    final sourceUuid = dive.sourceUuid ?? dive.sourceId;

    final diveData = <String, dynamic>{
      'dateTime': dive.startTime,
      'maxDepth': dive.maxDepth,
      'avgDepth': dive.avgDepth,
      // `duration` is bottom time (distinct from runtime); fall back to elapsed.
      'duration': dive.bottomTimeSeconds != null
          ? Duration(seconds: dive.bottomTimeSeconds!)
          : dive.duration,
      'runtime': dive.duration,
      'waterTemp': dive.minTemperature,
      'sourceId': dive.sourceId,
      'sourceUuid': sourceUuid,
    };

    if (dive.avgHeartRate != null) diveData['avgHeartRate'] = dive.avgHeartRate;
    if (dive.diveNumber != null) diveData['diveNumber'] = dive.diveNumber;
    if (dive.surfaceIntervalSeconds != null) {
      diveData['surfaceInterval'] = Duration(
        seconds: dive.surfaceIntervalSeconds!,
      );
    }
    if (dive.waterType != null) diveData['waterType'] = dive.waterType;
    if (dive.decoModel != null) diveData['decoAlgorithm'] = dive.decoModel;
    if (dive.gfLow != null) diveData['gradientFactorLow'] = dive.gfLow;
    if (dive.gfHigh != null) diveData['gradientFactorHigh'] = dive.gfHigh;
    if (dive.cnsEnd != null) diveData['cnsEnd'] = dive.cnsEnd;
    if (dive.otu != null) diveData['otu'] = dive.otu;
    if (dive.computerModel != null) {
      diveData['diveComputerModel'] = dive.computerModel;
    }
    if (dive.computerSerial != null) {
      diveData['diveComputerSerial'] = dive.computerSerial;
    }
    if (dive.computerFirmware != null) {
      diveData['diveComputerFirmware'] = dive.computerFirmware;
    }
    if (dive.latitude != null && dive.longitude != null) {
      diveData['latitude'] = dive.latitude;
      diveData['longitude'] = dive.longitude;
    }
    if (dive.exitLatitude != null && dive.exitLongitude != null) {
      diveData['exitLatitude'] = dive.exitLatitude;
      diveData['exitLongitude'] = dive.exitLongitude;
    }

    if (dive.tanks.isNotEmpty) {
      diveData['tanks'] = dive.tanks.map((t) {
        final tank = <String, dynamic>{'order': t.order};
        if (t.startPressureBar != null) {
          tank['startPressure'] = t.startPressureBar;
        }
        if (t.endPressureBar != null) tank['endPressure'] = t.endPressureBar;
        if (t.volumeLiters != null) tank['volume'] = t.volumeLiters;
        if (t.o2Percent != null || t.hePercent != null) {
          tank['gasMix'] = GasMix(
            o2: t.o2Percent ?? 21.0,
            he: t.hePercent ?? 0.0,
          );
        }
        return tank;
      }).toList();
    }

    if (dive.profile.isNotEmpty) {
      diveData['profile'] = dive.profile.map((s) {
        final point = <String, dynamic>{
          'timestamp': s.timeSeconds,
          'depth': s.depth,
        };
        if (s.temperature != null) point['temperature'] = s.temperature;
        if (s.heartRate != null) point['heartRate'] = s.heartRate;
        if (s.cns != null) point['cns'] = s.cns;
        if (s.ndlSeconds != null) point['ndl'] = s.ndlSeconds;
        if (s.ttsSeconds != null) point['tts'] = s.ttsSeconds;
        if (s.ceiling != null) point['ceiling'] = s.ceiling;
        final tankPressures = s.tankPressures;
        if (tankPressures != null && tankPressures.isNotEmpty) {
          point['allTankPressures'] = tankPressures
              .map(
                (p) => <String, dynamic>{
                  'tankIndex': p.tankIndex,
                  'pressure': p.pressureBar,
                },
              )
              .toList();
        }
        return point;
      }).toList();
    }

    return ImportPayload(
      entities: {
        ImportEntityType.dives: [diveData],
      },
      metadata: {
        'sourceApp': 'Garmin',
        'sourceId': dive.sourceId,
        'sourceUuid': sourceUuid,
      },
    );
  }
}
