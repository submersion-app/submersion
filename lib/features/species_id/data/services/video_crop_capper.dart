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
      final (runs, stored) = await _identifications.forMediaIdsWithRuns([
        mediaId,
      ], withPaths: false);
      final run = runs[mediaId];
      final rows = visibleRows(run, stored[mediaId] ?? const []);
      if (!rows.any((i) => i.isTrack)) return 0;
      final drop = videoCropsToDrop(rows, tags: await _taggedSpecies(mediaId));
      if (drop.isEmpty) return 0;
      final present = await _crops.presentAmong(mediaId, drop.toList());
      if (present.isEmpty) return 0;
      final me = await _deviceId();
      if (run != null && me != null && !run.madeOn(me)) {
        await _crops.deleteFiles(mediaId, present.toList());
        return 0;
      }
      await _crops.delete(mediaId, present.toList());
      return present.length;
    } on Object catch (e) {
      _log.debug('Could not cap the crops of $mediaId', error: e);
      return 0;
    }
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
