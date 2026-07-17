import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/divelogs_sync/data/mappers/divelogs_reference_mappers.dart';
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

    // Gear/geartypes/certifications degrade independently: a failure on any
    // of them becomes a warning and must never abort the dive pull.
    final extraWarnings = <ImportWarning>[];
    Map<int, String> geartypes = const {};
    var gear = const <DivelogsGearItem>[];
    var certs = const <DivelogsCertification>[];
    try {
      geartypes = await _api.getGeartypes();
    } on DivelogsApiException {
      // Types degrade to EquipmentType.other; not worth a user warning.
    }
    try {
      gear = await _api.getGear();
    } on DivelogsApiException catch (e) {
      extraWarnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message: 'Gear could not be fetched from divelogs.de: ${e.message}',
        ),
      );
    }
    try {
      certs = await _api.getCertifications();
    } on DivelogsApiException catch (e) {
      extraWarnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message:
              'Certifications could not be fetched from divelogs.de: '
              '${e.message}',
        ),
      );
    }

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

    final equipmentEntities = [
      for (final item in gear)
        <String, dynamic>{
          'uddfId': DivelogsDiveMapper.gearKey(item.id),
          'name': item.name,
          'type': DivelogsReferenceMappers.equipmentTypeForGeartypeName(
            geartypes[item.geartypeId],
          ),
          if (item.purchaseDate != null) 'purchaseDate': item.purchaseDate,
          if (item.lastServiceDate != null)
            'lastServiceDate': item.lastServiceDate,
          'status': item.discardDate != null
              ? EquipmentStatus.retired
              : EquipmentStatus.active,
          'isActive': item.discardDate == null,
        },
    ];

    final certEntities = [
      for (final cert in certs)
        <String, dynamic>{
          'uddfId': 'divelogs-cert-${cert.id ?? cert.name}',
          'name': cert.name,
          'agency': DivelogsReferenceMappers.agencyForOrg(cert.org),
          if (cert.date != null) 'issueDate': cert.date,
          if (DivelogsReferenceMappers.levelForName(cert.name) != null)
            'level': DivelogsReferenceMappers.levelForName(cert.name),
        },
    ];

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (diveEntities.isNotEmpty) {
      entities[ImportEntityType.dives] = diveEntities;
    }
    if (sitesByKey.isNotEmpty) {
      entities[ImportEntityType.sites] = sitesByKey.values.toList();
    }
    if (equipmentEntities.isNotEmpty) {
      entities[ImportEntityType.equipment] = equipmentEntities;
    }
    if (certEntities.isNotEmpty) {
      entities[ImportEntityType.certifications] = certEntities;
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
        ...extraWarnings,
      ],
      metadata: {'source': 'divelogs.de', 'diveCount': result.dives.length},
    );
  }
}
