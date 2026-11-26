import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/video_crop_cap.dart';

/// Deletes the crops a video does not keep ([videoCropsToDrop], issue
/// #5032): after each scan chunk, after a rename, and at launch for what is
/// already stored. Never touches a row.
///
/// Only the device that analysed a video removes its synced crops, with
/// tombstones so every peer drops them too: two devices that see different
/// rows halfway through a sync must not each delete a different set. Any
/// other device removes only crop files of its own, which it does not
/// normally hold.
class VideoCropCapper {
  VideoCropCapper({
    required MediaIdentificationRepository identifications,
    required IdentificationCropStore crops,
    required Future<List<TaggedSpecies>> Function(String mediaId) taggedSpecies,
    required Future<String?> Function() deviceId,
  }) : _identifications = identifications,
       _crops = crops,
       _taggedSpecies = taggedSpecies,
       _deviceId = deviceId;

  final MediaIdentificationRepository _identifications;
  final IdentificationCropStore _crops;
  final Future<List<TaggedSpecies>> Function(String mediaId) _taggedSpecies;
  final Future<String?> Function() _deviceId;
  static final _log = LoggerService.forClass(VideoCropCapper);

  /// Caps [mediaId]'s crops. Returns how many it removed; 0 for a photo,
  /// and on a device that did not analyse the video. Never throws.
  Future<int> cap(String mediaId) async {
    try {
      final (_, first) = await _drops(mediaId);
      if (first.isEmpty) return 0;
      final present = await _crops.presentAmong(mediaId, first.toList());
      if (present.isEmpty) return 0;
      // Read again just before deleting: a scan, rename or claim since the
      // first read may keep a crop that read dropped. Only crops both
      // reads drop go, and who owns them is read from this last snapshot:
      // a sync may have replaced the run in between.
      final (run, again) = await _drops(mediaId);
      // Only the maker trims synced crops, and only a run here says who
      // that is: with none (not synced yet) or this device's id unread,
      // only a run with no maker yet (never published) counts as its own.
      final me = await _deviceId();
      final mine =
          run != null &&
          (run.analysedBy == null || (me != null && run.madeOn(me)));
      final gone = [
        for (final id in present)
          if (again.contains(id)) id,
      ];
      if (gone.isEmpty) return 0;
      if (!mine) {
        await _crops.deleteFiles(mediaId, gone);
        return 0;
      }
      await _crops.delete(mediaId, gone);
      return gone.length;
    } on Object catch (e) {
      _log.debug('Could not cap the crops of $mediaId', error: e);
      return 0;
    }
  }

  /// [mediaId]'s run, and the tracks whose crop its rows drop now.
  Future<(MediaIdentificationRun?, Set<String>)> _drops(String mediaId) async {
    final (runs, stored) = await _identifications.forMediaIdsWithRuns([
      mediaId,
    ], withPaths: false);
    final run = runs[mediaId];
    final rows = visibleRows(run, stored[mediaId] ?? const []);
    if (!rows.any((i) => i.isTrack)) return (run, const <String>{});
    return (run, videoCropsToDrop(rows, tags: await _taggedSpecies(mediaId)));
  }

  /// Caps every one of [mediaIds], one at a time. Returns how many crops
  /// it removed. Never throws.
  Future<int> capAll(List<String> mediaIds) async {
    var removed = 0;
    for (final mediaId in mediaIds) {
      removed += await cap(mediaId);
    }
    return removed;
  }
}
