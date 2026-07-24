import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// Wraps media-row deletion with the remote-blob delete fast path
/// (orphan-prevention spec 5.2): the delete INTENT is enqueued BEFORE the
/// row dies - the queue lives in a different database, so no cross-DB
/// transaction exists, and this ordering makes the only crash window
/// harmless (an intent whose row survived no-ops on the drain-time
/// refcount). Enqueue problems never block the deletion itself; missed
/// intents fall to the Verify Library sweep.
///
/// Single-enqueuer rule (spec 5.4): only user-action deletion flows go
/// through this coordinator. Sync tombstone application deletes rows
/// directly and must never enqueue remote deletes.
class MediaDeletionCoordinator {
  MediaDeletionCoordinator({
    required MediaRepository mediaRepository,
    required MediaTransferQueueRepository Function() queue,
    Future<void> Function()? kickWorker,
  }) : _mediaRepository = mediaRepository,
       _queue = queue,
       _kickWorker = kickWorker;

  final MediaRepository _mediaRepository;
  final MediaTransferQueueRepository Function() _queue;
  final Future<void> Function()? _kickWorker;
  final _log = LoggerService.forClass(MediaDeletionCoordinator);

  Future<void> deleteMedia(String id) => deleteMultipleMedia([id]);

  /// Deletes by id, reading each row back to build its blob-delete intent.
  Future<void> deleteMultipleMedia(List<String> ids) =>
      _delete(ids, const <String, MediaItem>{});

  /// [deleteMultipleMedia] for callers that already hold the rows. The
  /// dive-deletion cascade partitions its doomed set out of a single
  /// select, so re-reading each row by id here would be duplicate work
  /// proportional to the number of photos on the dives being deleted.
  Future<void> deleteMediaItems(List<MediaItem> items) => _delete(
    [for (final item in items) item.id],
    {for (final item in items) item.id: item},
  );

  /// [known] short-circuits the per-id read for callers that already hold
  /// the row; ids absent from it are read back as before.
  Future<void> _delete(List<String> ids, Map<String, MediaItem> known) async {
    var enqueued = false;
    for (final id in ids) {
      // Untyped catch on purpose: an uninitialized
      // LocalCacheDatabaseService throws StateError (an Error, not an
      // Exception), and no media-store problem may ever block the user's
      // deletion.
      try {
        if (await _enqueueIntent(id, known[id])) enqueued = true;
      } catch (e, stackTrace) {
        _log.warning(
          'Could not enqueue remote delete for media $id '
          '(sweep will reconcile)',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    if (ids.length == 1) {
      await _mediaRepository.deleteMedia(ids.single);
    } else {
      await _mediaRepository.deleteMultipleMedia(ids);
    }
    if (enqueued && _kickWorker != null) {
      try {
        await _kickWorker();
      } catch (e) {
        _log.warning('Worker kick after media delete failed', error: e);
      }
    }
  }

  Future<bool> _enqueueIntent(String id, MediaItem? known) async {
    final item = known ?? await _mediaRepository.getMediaById(id);
    final hash = item?.contentHash;
    if (item == null || hash == null || hash.isEmpty) return false;
    final everUploaded =
        item.remoteUploadedAt != null ||
        item.remoteThumbUploadedAt != null ||
        item.remoteCompressedUploadedAt != null;
    if (!everUploaded) return false;
    await _queue().enqueueDelete(
      mediaId: id,
      contentHash: hash,
      originalExt: StoreKeys.extensionFor(item.originalFilename),
      renditionExt: item.mediaType == MediaType.video ? 'mp4' : 'jpg',
    );
    return true;
  }
}
