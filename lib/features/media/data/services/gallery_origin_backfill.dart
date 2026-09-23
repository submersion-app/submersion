import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/gallery_asset_reader.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';

/// What one run of [GalleryOriginBackfill] did.
typedef GalleryOriginBackfillOutcome = ({
  /// Gallery rows with no origin that were probed.
  int checked,

  /// Of those, rows whose asset id loads here and were stamped.
  int stamped,
});

/// One-time stamp of this device's id on the gallery rows it linked before
/// gallery links recorded an origin (media sync program spec 6.1).
///
/// A gallery row's origin decides its verdict: only the device that linked
/// it may call a failed search notFound, which orphans the row everywhere.
/// Older rows carry no origin, so no device may call them missing, including
/// the one that linked them. This finds the rows whose stored asset id still
/// loads here, which only the linking device's id does, and stamps them, so
/// that device regains its verdict and every peer learns where they live.
///
/// Runs after a successful sync, never at launch: the origin has no fact
/// group, so a stamp bumps the row clock and republishes the whole row, and
/// a peer's newer edit this device has not pulled yet would lose to the
/// stale copy. Right after a pull that window is as small as it gets.
///
/// Only with full photo access: a limited selection hides photos this device
/// did link, and a pass over a partial library would set the flag over rows
/// it never saw. Flagged in SharedPreferences like
/// `MediaOriginRepublishSweep`, and set only after a complete pass, so a
/// failed or waiting run tries again after the next sync.
class GalleryOriginBackfill {
  GalleryOriginBackfill({
    required MediaRepository mediaRepository,
    required GalleryAssetReader reader,
    required PhotoPickerService photos,
    required Future<PhotoPermissionStatus> Function() permissionStatus,
    required Future<String> Function() deviceId,
    required SharedPreferences prefs,
  }) : _mediaRepository = mediaRepository,
       _reader = reader,
       _photos = photos,
       _permissionStatus = permissionStatus,
       _deviceId = deviceId,
       _prefs = prefs;

  static const String doneFlagKey = 'media_gallery_origin_backfill_v1';

  /// Whether this device has already run the backfill. Cheap, so callers can
  /// ask before building anything it needs.
  static bool isDone(SharedPreferences prefs) =>
      prefs.getBool(doneFlagKey) ?? false;

  final MediaRepository _mediaRepository;
  final GalleryAssetReader _reader;
  final PhotoPickerService _photos;

  /// Reads photo access without asking for it. Not the service's
  /// checkPermission: on mobile that is a request, and this runs after a
  /// sync, unasked, so it must never show the OS prompt. Without full
  /// access it waits for the user to grant it through the gallery flow.
  final Future<PhotoPermissionStatus> Function() _permissionStatus;
  final Future<String> Function() _deviceId;
  final SharedPreferences _prefs;
  final _log = LoggerService.forClass(
    GalleryOriginBackfill,
    category: LogCategory.media,
  );

  /// Runs the backfill, or returns null when it already ran, is waiting for
  /// full photo access, or could not complete (logged; the flag stays unset).
  Future<GalleryOriginBackfillOutcome?> run() async {
    if (isDone(_prefs)) return null;
    try {
      // No photo library here (Windows, Linux): no gallery row was ever
      // linked on this device, so there is nothing of its own to stamp.
      if (!_photos.supportsGalleryBrowsing) {
        await _prefs.setBool(doneFlagKey, true);
        return (checked: 0, stamped: 0);
      }
      if (await _permissionStatus() != PhotoPermissionStatus.authorized) {
        _log.info('Gallery origin backfill waiting for full photo access');
        return null;
      }
      final me = await _deviceId();
      final candidates = await _mediaRepository.getGalleryMediaWithoutOrigin();
      final mine = <({String id, String platformAssetId})>[];
      var unanswered = 0;
      for (final row in candidates) {
        try {
          if (await _reader.exists(row.platformAssetId)) mine.add(row);
        } on Object catch (e) {
          // One asset the platform cannot answer for must not hold the rest
          // back; it stays unstamped, which is the safe state, and keeps the
          // pass from counting as complete.
          unanswered++;
          _log.warning('Could not probe ${row.id}; left unstamped', error: e);
        }
      }
      final stamped = await _mediaRepository.stampOriginDevice(mine, me);
      // Done only once every candidate had an answer, and nothing is left
      // that this pass did not ask about. A probe that failed said nothing
      // about its row; a row relinked during the probe loop is still a
      // candidate, under an asset this pass never probed. Either way the
      // next sync asks again. Rows that answered "not here" stay
      // candidates too, but they were asked, so they do not hold it open.
      final asked = candidates.toSet();
      final unasked = (await _mediaRepository.getGalleryMediaWithoutOrigin())
          .where((row) => !asked.contains(row))
          .length;
      final complete = unanswered == 0 && unasked == 0;
      if (complete) await _prefs.setBool(doneFlagKey, true);
      _log.info(
        'Gallery origin backfill ${complete ? 'done' : 'partial'}: '
        'checked ${candidates.length}, stamped $stamped, '
        'unanswered $unanswered, unasked $unasked',
      );
      return (checked: candidates.length, stamped: stamped);
    } on Object catch (e, stackTrace) {
      _log.error(
        'Gallery origin backfill failed; will retry after the next sync',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
