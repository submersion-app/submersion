import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
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

/// Stamps the iCloud identifier on this device's gallery rows that carry
/// none (media sync program spec 6.2), so a peer sharing the library can
/// find each exact photo: rows linked before links recorded one, and rows
/// whose photo had no cloud id at link time because iCloud Photos had not
/// uploaded it yet, or was off. Those can gain one later, so the pass
/// repeats, at most once a day ([interval]): one batch lookup over the rows
/// still missing an id, and a stamp only for those iCloud now answers.
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
/// never prompting. The last complete pass is recorded in SharedPreferences,
/// so a failed or waiting run tries again after the next sync.
class GalleryCloudIdBackfill {
  GalleryCloudIdBackfill({
    required MediaRepository mediaRepository,
    required CloudIdentifierSource cloudIdentifiers,
    required PhotoPickerService photos,
    required Future<PhotoPermissionStatus> Function() permissionStatus,
    required Future<String> Function() deviceId,
    required SharedPreferences prefs,
    DateTime Function()? now,
    LocalAssetCacheRepository? assetCache,
  }) : _mediaRepository = mediaRepository,
       _cloudIdentifiers = cloudIdentifiers,
       _photos = photos,
       _permissionStatus = permissionStatus,
       _deviceId = deviceId,
       _prefs = prefs,
       _now = now ?? DateTime.now,
       _assetCache = assetCache;

  /// When the last complete pass ran, epoch milliseconds.
  static const String lastRunKey =
      'media_gallery_cloud_id_backfill_last_run_v1';

  /// The least time between two passes.
  static const Duration interval = Duration(days: 1);

  /// Whether a pass is due at [now]. Cheap, so callers can ask before
  /// building anything the pass needs.
  static bool isDue(SharedPreferences prefs, DateTime now) {
    final last = prefs.getInt(lastRunKey);
    if (last == null) return true;
    return !now.isBefore(
      DateTime.fromMillisecondsSinceEpoch(last).add(interval),
    );
  }

  final MediaRepository _mediaRepository;
  final CloudIdentifierSource _cloudIdentifiers;
  final PhotoPickerService _photos;

  /// Reads photo access without asking for it, as the origin backfill does.
  final Future<PhotoPermissionStatus> Function() _permissionStatus;
  final Future<String> Function() _deviceId;
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  /// This device's resolution cache. A stamp is something new to find the
  /// photo by, and the sync hint that lifts a search's backoff covers only
  /// a peer's writes, so the pass lifts it for the rows it stamps itself.
  final LocalAssetCacheRepository? _assetCache;
  final _log = LoggerService.forClass(
    GalleryCloudIdBackfill,
    category: LogCategory.media,
  );

  /// Runs a pass, or returns null when one is not due yet, is waiting (for
  /// the origin backfill or full photo access), or could not complete
  /// (logged; the pass is not recorded).
  Future<GalleryCloudIdBackfillOutcome?> run() async {
    if (!isDue(_prefs, _now())) return null;
    try {
      // No photo library here (Windows, Linux): no gallery row was ever
      // linked on this device.
      if (!_photos.supportsGalleryBrowsing) {
        await _recordRun();
        return (checked: 0, stamped: 0);
      }
      // No iCloud identifiers on this platform (Android): nothing to ask,
      // so the pass is recorded without reading a row.
      if (!_cloudIdentifiers.isSupported) {
        await _recordRun();
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
      final stampedIds = await _mediaRepository.stampCloudAssetIds(found);
      await _assetCache?.clearUnresolved(stampedIds);
      final stamped = stampedIds.length;
      // Complete once nothing is left that this pass did not ask about. Rows
      // whose asset has no cloud id stay candidates for tomorrow's pass, but
      // they were asked; a row linked or relinked during the lookup was not,
      // so the pass is not recorded and the next sync asks again.
      final asked = candidates.toSet();
      final unasked = (await _mediaRepository.getOwnGalleryMediaWithoutCloudId(
        me,
      )).where((row) => !asked.contains(row)).length;
      if (unasked == 0) await _recordRun();
      _log.info(
        'Gallery cloud id backfill ${unasked == 0 ? 'complete' : 'partial'}: '
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

  Future<void> _recordRun() =>
      _prefs.setInt(lastRunKey, _now().millisecondsSinceEpoch);
}
