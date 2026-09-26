import 'package:path/path.dart' as p;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_dive_mapper.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_reference_mappers.dart';
import 'package:submersion/features/universal_import/data/services/import_site_location.dart';

/// What one fetch of a divelogs.de logbook produced.
class DivelogsFetchResult {
  const DivelogsFetchResult({
    required this.payload,
    required this.photosBySourceUuid,
    required this.diveCount,
    required this.skippedDives,
    required this.gearUnavailable,
    required this.certificationsUnavailable,
    required this.photoListingFailures,
  });

  final ImportPayload payload;

  /// Listed photos per payload dive, keyed by the dive's `sourceUuid`.
  final Map<String, List<RemotePhoto>> photosBySourceUuid;
  final int diveCount;
  final int skippedDives;
  final bool gearUnavailable;
  final bool certificationsUnavailable;
  final int photoListingFailures;

  int get photoCount =>
      photosBySourceUuid.values.fold(0, (sum, list) => sum + list.length);
}

/// Extensions a listed picture may keep: images and the videos divelogs.de
/// can hold. Anything else (a `.php` endpoint, no extension at all) would
/// leave a file in the user's folder that nothing opens.
const _mediaExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.heic',
  '.heif',
  '.tif',
  '.tiff',
  '.bmp',
  '.mp4',
  '.mov',
  '.m4v',
  '.avi',
  '.mkv',
  '.webm',
};

/// Characters no file name may carry on Windows, plus control characters.
final _unsafeFileNameChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

/// The name a listed picture is saved under: the URL's own file name when
/// it is an image or video, made safe for every platform's file system,
/// else a stable name built from the dive and the picture's position.
String remotePhotoFileName(
  DivelogsPicture picture, {
  required String remoteDiveId,
  required int index,
}) {
  final segments = picture.url?.pathSegments ?? const <String>[];
  final name = segments.isEmpty
      ? ''
      : p.basename(segments.last).replaceAll(_unsafeFileNameChars, '_');
  final ext = p.extension(name).toLowerCase();
  if (_mediaExtensions.contains(ext) &&
      p.basenameWithoutExtension(name).isNotEmpty) {
    return name;
  }
  final safeId = remoteDiveId.replaceAll(_unsafeFileNameChars, '_');
  return 'divelogs-$safeId-${index + 1}.jpg';
}

/// Fetches a full divelogs.de logbook and assembles an [ImportPayload] for
/// the universal import pipeline.
///
/// `/dives` failing is fatal. Gear, gear types, certifications and each
/// dive's picture listing degrade independently to coded warnings, so a
/// problem with any of them never costs the dives.
class DivelogsImportService {
  DivelogsImportService({
    required DivelogsApiClient api,
    DivelogsDiveMapper mapper = const DivelogsDiveMapper(),
  }) : _api = api,
       _mapper = mapper;

  final DivelogsApiClient _api;
  final DivelogsDiveMapper _mapper;

  Future<DivelogsFetchResult> fetchLogbook({
    required bool includePhotos,
    void Function(int current, int total)? onPhotoListingProgress,
  }) async {
    final result = await _api.getAllDives();

    Map<int, String> geartypes = const {};
    var gear = const <DivelogsGearItem>[];
    var certs = const <DivelogsCertification>[];
    var gearUnavailable = false;
    var certificationsUnavailable = false;
    try {
      geartypes = await _api.getGeartypes();
    } on DivelogsUnauthorizedException {
      rethrow;
    } on DivelogsApiException {
      // Types degrade to EquipmentType.other; not worth a notice.
    }
    try {
      gear = await _api.getGear();
    } on DivelogsUnauthorizedException {
      rethrow;
    } on DivelogsApiException {
      gearUnavailable = true;
    }
    try {
      certs = await _api.getCertifications();
    } on DivelogsUnauthorizedException {
      rethrow;
    } on DivelogsApiException {
      certificationsUnavailable = true;
    }

    final diveEntities = <Map<String, dynamic>>[];
    final sitesByKey = <String, Map<String, dynamic>>{};
    for (final dive in result.dives) {
      diveEntities.add(_mapper.mapDive(dive));
      final site = _mapper.mapSite(dive);
      if (site == null) continue;
      final key = site['uddfId'] as String;
      final existing = sitesByKey[key];
      if (existing == null) {
        sitesByKey[key] = site;
      } else if (ImportSiteLocation.coordinatesOf(existing) == null &&
          ImportSiteLocation.coordinatesOf(site) != null) {
        // Same site on an earlier dive: backfill a position it lacked. The
        // incoming map was built by mapSite, so its pair already passed the
        // contract.
        sitesByKey[key] = {...existing, ...site};
      }
    }

    final photosBySourceUuid = <String, List<RemotePhoto>>{};
    var photoListingFailures = 0;
    if (includePhotos) {
      final remoteIds = [
        for (final dive in result.dives)
          if (dive.id != null) dive.id!,
      ];
      for (var i = 0; i < remoteIds.length; i++) {
        final remoteId = remoteIds[i];
        try {
          final pictures = await _api.getPictures(remoteId);
          final photos = <RemotePhoto>[
            for (final (n, picture) in pictures.indexed)
              if (picture.url != null)
                RemotePhoto(
                  url: picture.url!,
                  fileName: remotePhotoFileName(
                    picture,
                    remoteDiveId: remoteId,
                    index: n,
                  ),
                ),
          ];
          if (photos.isNotEmpty) {
            photosBySourceUuid[DivelogsDiveMapper.sourceUuidFor(remoteId)] =
                photos;
          }
          // A row with no downloadable link is a photo the import cannot
          // bring over; count the dive rather than drop it without a word.
          if (photos.length < pictures.length) photoListingFailures++;
        } on DivelogsUnauthorizedException {
          rethrow;
        } on DivelogsApiException {
          photoListingFailures++;
        }
        onPhotoListingProgress?.call(i + 1, remoteIds.length);
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

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{
      if (diveEntities.isNotEmpty) ImportEntityType.dives: diveEntities,
      if (sitesByKey.isNotEmpty)
        ImportEntityType.sites: sitesByKey.values.toList(),
      if (equipmentEntities.isNotEmpty)
        ImportEntityType.equipment: equipmentEntities,
      if (certEntities.isNotEmpty)
        ImportEntityType.certifications: certEntities,
    };

    final warnings = <ImportWarning>[
      if (result.skippedCount > 0)
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.divesSkipped,
          message: '${result.skippedCount} divelogs.de dives could not be read',
          count: result.skippedCount,
        ),
      if (gearUnavailable)
        const ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.gearUnavailable,
          message: 'divelogs.de gear list could not be fetched',
        ),
      if (certificationsUnavailable)
        const ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.certificationsUnavailable,
          message: 'divelogs.de certification list could not be fetched',
        ),
      if (photoListingFailures > 0)
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.photoListingsUnavailable,
          message: '$photoListingFailures divelogs.de photo listings failed',
          count: photoListingFailures,
        ),
    ];

    return DivelogsFetchResult(
      payload: ImportPayload(
        entities: entities,
        warnings: warnings,
        metadata: {'source': 'divelogs.de', 'diveCount': result.dives.length},
      ),
      photosBySourceUuid: photosBySourceUuid,
      diveCount: result.dives.length,
      skippedDives: result.skippedCount,
      gearUnavailable: gearUnavailable,
      certificationsUnavailable: certificationsUnavailable,
      photoListingFailures: photoListingFailures,
    );
  }
}
