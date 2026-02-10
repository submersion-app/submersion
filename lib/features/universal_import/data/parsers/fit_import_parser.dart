import 'dart:typed_data';

import 'package:submersion/features/dive_import/data/services/fit_parser_service.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

/// Parser adapter for Garmin FIT binary files.
///
/// Wraps [FitParserService] and converts its [ImportedDive] output
/// into the unified [ImportPayload] format. FIT files only contain
/// dive data, so the payload will only ever have a single "dives" tab.
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

    // Convert ImportedDive to the Map<String, dynamic> format
    // expected by the universal import pipeline.
    final diveData = <String, dynamic>{
      'dateTime': dive.startTime,
      'maxDepth': dive.maxDepth,
      'avgDepth': dive.avgDepth,
      'duration': dive.duration,
      'runtime': dive.duration,
      'waterTemp': dive.minTemperature,
      'sourceId': dive.sourceId,
    };

    if (dive.avgHeartRate != null) {
      diveData['avgHeartRate'] = dive.avgHeartRate;
    }
    if (dive.latitude != null && dive.longitude != null) {
      diveData['latitude'] = dive.latitude;
      diveData['longitude'] = dive.longitude;
    }

    if (dive.profile.isNotEmpty) {
      diveData['profile'] = dive.profile.map((s) {
        final point = <String, dynamic>{
          'timestamp': s.timeSeconds,
          'depth': s.depth,
        };
        if (s.temperature != null) point['temperature'] = s.temperature;
        if (s.heartRate != null) point['heartRate'] = s.heartRate;
        return point;
      }).toList();
    }

    return ImportPayload(
      entities: {
        ImportEntityType.dives: [diveData],
      },
      metadata: {'sourceApp': 'Garmin', 'sourceId': dive.sourceId},
    );
  }
}
