import 'package:flutter/services.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_dive_mapper.dart';

/// Parses a Shearwater Cloud SQLite database file into an [ImportPayload].
///
/// Orchestrates the full Shearwater Cloud import flow:
/// 1. Validates the database structure.
/// 2. Reads raw dives from [ShearwaterDbReader].
/// 3. Maps each dive via [ShearwaterDiveMapper.mapDive].
/// 4. Extracts unique sites via [ShearwaterDiveMapper.mapSites].
/// 5. Returns a unified [ImportPayload].
class ShearwaterCloudParser implements ImportParser {
  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.shearwaterDb];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    // 1. Validate database.
    final isValid = await ShearwaterDbReader.isShearwaterCloudDb(fileBytes);
    if (!isValid) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message:
                'File is not a valid Shearwater Cloud database. '
                'Expected dive_details and log_data tables.',
          ),
        ],
      );
    }

    // 2. Read raw dives.
    final List<ShearwaterRawDive> rawDives;
    try {
      rawDives = await ShearwaterDbReader.readDives(fileBytes);
    } catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Failed to read dives from database: $e',
          ),
        ],
      );
    }
    if (rawDives.isEmpty) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Shearwater Cloud database contains no dives.',
          ),
        ],
      );
    }

    // 3. Map dives to ImportPayload entities.
    //    After the first platform-level FFI failure, fall back to
    //    metadata-only for remaining dives.
    final warnings = <ImportWarning>[];
    final diveEntities = <Map<String, dynamic>>[];
    var ffiAvailable = true;
    // Dives whose log data went undecoded because FFI was unavailable. Dives
    // with no log data had no profile to lose, so they are not counted.
    var platformBlocked = 0;

    for (final rawDive in rawDives) {
      if (ffiAvailable) {
        try {
          final diveMap = await ShearwaterDiveMapper.mapDive(
            rawDive,
            warnings: warnings,
          );
          diveEntities.add(diveMap);
          continue;
        } on MissingPluginException {
          ffiAvailable = false;
        } on PlatformException {
          ffiAvailable = false;
        }
      }
      if (rawDive.decompressedLogData?.isNotEmpty ?? false) platformBlocked++;
      diveEntities.add(ShearwaterDiveMapper.mapDiveMetadata(rawDive));
    }

    // One warning for the whole file, counting every affected dive.
    if (platformBlocked > 0) {
      warnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.info,
          code: ImportWarningCode.profileUndecodableOnPlatform,
          count: platformBlocked,
          message:
              'Profile parsing is not available on this platform. '
              '$platformBlocked dive(s) will be imported with metadata only.',
          entityType: ImportEntityType.dives,
        ),
      );
    }

    // 4. Extract unique sites.
    final sites = ShearwaterDiveMapper.mapSites(rawDives);

    // 5. Build payload.
    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (diveEntities.isNotEmpty) {
      entities[ImportEntityType.dives] = diveEntities;
    }
    if (sites.isNotEmpty) {
      entities[ImportEntityType.sites] = sites;
    }

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: {'source': 'shearwater_cloud', 'diveCount': rawDives.length},
    );
  }
}
