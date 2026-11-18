import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';

/// Removes what the marine life model left for media that is gone, and
/// clears it all on request (issue #4668).
///
/// Never throws: it runs after deletions that have already succeeded, and
/// anything left behind is picked up by [sweepOrphans].
class IdentificationCleanup {
  IdentificationCleanup({
    required MediaIdentificationRepository identifications,
    required IdentificationEmbeddingRepository embeddings,
    required IdentificationCropStore crops,
  }) : _identifications = identifications,
       _embeddings = embeddings,
       _crops = crops;

  final MediaIdentificationRepository _identifications;
  final IdentificationEmbeddingRepository _embeddings;
  final IdentificationCropStore _crops;
  final _log = LoggerService.forClass(IdentificationCleanup);

  /// From the media deletion coordinator. A delete held for undo removes
  /// nothing: an undo puts the media rows back, and the diver's decisions on
  /// them must still be there.
  Future<void> onMediaDeleted(
    List<String> mediaIds, {
    required bool undoable,
  }) async {
    if (undoable || mediaIds.isEmpty) return;
    try {
      await _purge(mediaIds);
    } on Object catch (e) {
      _log.debug('Could not remove identifications of deleted media', error: e);
    }
  }

  /// Identifications whose media row is gone, with their crops and
  /// embeddings: deletions applied by sync, and deletes held for undo that
  /// were never undone. Returns how many media items were cleared.
  Future<int> sweepOrphans() async {
    try {
      final orphans = await _identifications.orphanMediaIds();
      if (orphans.isNotEmpty) await _purge(orphans);
      return orphans.length;
    } on Object catch (e) {
      _log.debug('Could not sweep orphaned identifications', error: e);
      return 0;
    }
  }

  /// Every identification in the open logbook, with its crops and
  /// embeddings. Only this logbook's: the crops folder and the embeddings
  /// are shared by every logbook opened on the device. Species tags are not
  /// touched.
  Future<void> clearAll() async {
    await _purge(await _identifications.mediaIds());
  }

  Future<void> _purge(List<String> mediaIds) async {
    final ids = await _identifications.deleteForMedia(mediaIds);
    await _embeddings.delete(ids);
    await _crops.deleteMedia(mediaIds);
  }
}
