import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/cloud_identifier_source.dart';
import 'package:submersion/features/media/data/services/gallery_origin_backfill.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';

/// What one run of [GalleryCloudIdBackfill] did.
typedef GalleryCloudIdBackfillOutcome = ({
  /// This device's gallery rows with no cloud id that were looked up.
  int checked,

  /// Of those, rows whose asset has a cloud id and were stamped.
  int stamped,
});

/// One-time stamp of the iCloud identifier on the gallery rows this device
/// linked before links recorded one (media sync program spec 6.2), so a
/// peer sharing the library can find each exact photo.
///
/// Only this device's own rows (its id is their origin): only here does a
/// row's stored asset id name an asset in this library. So it waits for the
/// origin backfill, which is what makes older rows this device's own; a
/// pass before it would set the flag over rows it could not yet claim.
///
/// Runs after a successful sync, never at launch, for the origin backfill's
/// reason: the cloud id has no fact group, so a stamp bumps the row clock
/// and republishes the row, and right after a pull that is least likely to
/// overwrite a peer's unseen newer edit. Only with full photo access, and
/// never prompting. Flagged in SharedPreferences, set only after a complete
/// pass, so a failed or waiting run tries again after the next sync.
class GalleryCloudIdBackfill {
  GalleryCloudIdBackfill({
    required MediaRepository mediaRepository,
    required CloudIdentifierSource cloudIdentifiers,
    required PhotoPickerService photos,
    required Future<PhotoPermissionStatus> Function() permissionStatus,
    required Future<String> Function() deviceId,
    required SharedPreferences prefs,
  }) : _mediaRepository = mediaRepository,
       _cloudIdentifiers = cloudIdentifiers,
       _photos = photos,
       _permissionStatus = permissionStatus,
       _deviceId = deviceId,
       _prefs = prefs;

  static const String doneFlagKey = 'media_gallery_cloud_id_backfill_v1';

  /// Whether this device has already run the backfill.
  static bool isDone(SharedPreferences prefs) =>
      prefs.getBool(doneFlagKey) ?? false;

  final MediaRepository _mediaRepository;
  final CloudIdentifierSource _cloudIdentifiers;
  final PhotoPickerService _photos;

  /// Reads photo access without asking for it, as the origin backfill does.
  final Future<PhotoPermissionStatus> Function() _permissionStatus;
  final Future<String> Function() _deviceId;
  final SharedPreferences _prefs;
  final _log = LoggerService.forClass(
    GalleryCloudIdBackfill,
    category: LogCategory.media,
  );

  /// Runs the backfill, or returns null when it already ran, is waiting
  /// (for the origin backfill or full photo access), or could not complete
  /// (logged; the flag stays unset).
  Future<GalleryCloudIdBackfillOutcome?> run() async {
    if (isDone(_prefs)) return null;
    try {
      // No photo library here (Windows, Linux): no gallery row was ever
      // linked on this device.
      if (!_photos.supportsGalleryBrowsing) {
        await _prefs.setBool(doneFlagKey, true);
        return (checked: 0, stamped: 0);
      }
      if (!GalleryOriginBackfill.isDone(_prefs)) {
        _log.info('Gallery cloud id backfill waiting for the origin backfill');
        return null;
      }
      if (await _permissionStatus() != PhotoPermissionStatus.authorized) {
        _log.info('Gallery cloud id backfill waiting for full photo access');
        return null;
      }
      final me = await _deviceId();
      final candidates = await _mediaRepository
          .getOwnGalleryMediaWithoutCloudId(me);
      final ids = await _cloudIdentifiers.cloudIdentifiers([
        for (final row in candidates) row.platformAssetId,
      ]);
      final found = [
        for (final row in candidates)
          if (ids[row.platformAssetId] case final cloudId?)
            (
              id: row.id,
              platformAssetId: row.platformAssetId,
              cloudAssetId: cloudId,
            ),
      ];
      final stamped = await _mediaRepository.stampCloudAssetIds(found);
      // Done once nothing is left that this pass did not ask about. Rows
      // whose asset has no cloud id stay candidates, but they were asked; a
      // row linked or relinked during the lookup was not, so it holds the
      // flag open for the next sync.
      final asked = candidates.toSet();
      final unasked = (await _mediaRepository.getOwnGalleryMediaWithoutCloudId(
        me,
      )).where((row) => !asked.contains(row)).length;
      if (unasked == 0) await _prefs.setBool(doneFlagKey, true);
      _log.info(
        'Gallery cloud id backfill ${unasked == 0 ? 'done' : 'partial'}: '
        'checked ${candidates.length}, stamped $stamped, unasked $unasked',
      );
      return (checked: candidates.length, stamped: stamped);
    } on Object catch (e, stackTrace) {
      _log.error(
        'Gallery cloud id backfill failed; will retry after the next sync',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
