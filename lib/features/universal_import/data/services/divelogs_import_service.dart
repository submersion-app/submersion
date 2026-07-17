import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_dive_mapper.dart';

/// Fetches the full divelogs.de logbook and assembles an ImportPayload for
/// the universal import pipeline.
class DivelogsImportService {
  DivelogsImportService({
    required DivelogsApiClient api,
    DivelogsDiveMapper mapper = const DivelogsDiveMapper(),
  }) : _api = api,
       _mapper = mapper;

  final DivelogsApiClient _api;
  final DivelogsDiveMapper _mapper;

  Future<ImportPayload> fetchAllDives() async {
    final result = await _api.getAllDives();

    final diveEntities = <Map<String, dynamic>>[];
    final sitesByKey = <String, Map<String, dynamic>>{};
    for (final dive in result.dives) {
      diveEntities.add(_mapper.mapDive(dive));
      final site = _mapper.mapSite(dive);
      if (site != null) {
        final existing = sitesByKey[site['uddfId'] as String];
        if (existing == null) {
          sitesByKey[site['uddfId'] as String] = site;
        } else {
          // Same site seen on an earlier dive: backfill GPS the first
          // occurrence lacked so location data is not dropped.
          existing.putIfAbsent('latitude', () => site['latitude']);
          existing.putIfAbsent('longitude', () => site['longitude']);
          existing.removeWhere((_, value) => value == null);
        }
      }
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (diveEntities.isNotEmpty) {
      entities[ImportEntityType.dives] = diveEntities;
    }
    if (sitesByKey.isNotEmpty) {
      entities[ImportEntityType.sites] = sitesByKey.values.toList();
    }

    return ImportPayload(
      entities: entities,
      warnings: [
        if (result.skippedCount > 0)
          ImportWarning(
            severity: ImportWarningSeverity.warning,
            message: result.skippedCount == 1
                ? '1 dive could not be read from divelogs.de and was skipped.'
                : '${result.skippedCount} dives could not be read from '
                      'divelogs.de and were skipped.',
          ),
      ],
      metadata: {'source': 'divelogs.de', 'diveCount': result.dives.length},
    );
  }
}
