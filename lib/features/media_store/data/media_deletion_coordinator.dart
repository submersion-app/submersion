import 'package:submersion/core/database/database.dart';
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
  ///
  /// [keepIf] spares any row it answers true for, judged inside the delete's
  /// own transaction (see [MediaRepository.deleteMultipleMedia]). A caller
  /// whose items were chosen earlier passes the rule that chose them, so a
  /// row relinked in the meantime, even during the queue write below,
  /// survives. Its intent was already enqueued; that is harmless by the
  /// same refcount that covers a crash between enqueue and delete.
  ///
  /// [holdRemoteDelete] leaves the worker alone, for a delete the user can
  /// still undo: the intents wait for the next drain, and an undo that puts
  /// the rows back first turns them into no-ops (issue #2718).
  Future<void> deleteMediaItems(
    List<MediaItem> items, {
    bool Function(MediaData row)? keepIf,
    bool holdRemoteDelete = false,
  }) => _delete(
    [for (final item in items) item.id],
    {for (final item in items) item.id: item},
    keepIf: keepIf,
    kick: !holdRemoteDelete,
  );

  /// Undo for a held [deleteMediaItems] (issue #2718): [rows] are media the
  /// undo has put back. An intent still held for a row's hash no-ops at
  /// drain time now that the row exists again. One that has drained, is
  /// draining, or failed partway may have taken some of the remote blobs,
  /// so the row's upload stamps cannot be trusted: they are cleared and a
  /// re-upload queued, the Verify Library sweep's repair (spec 6.2). Like
  /// the delete, no media-store problem may fail the undo; a row this
  /// misses waits for the sweep.
  Future<void> repairRestoredMedia(List<MediaData> rows) async {
    var queued = false;
    for (final row in rows) {
      final hash = row.contentHash;
      final hasOriginal = row.remoteUploadedAt != null;
      final hasThumb = row.remoteThumbUploadedAt != null;
      final hasRendition = row.remoteCompressedUploadedAt != null;
      if (hash == null || hash.isEmpty) continue;
      if (!hasOriginal && !hasThumb && !hasRendition) continue;
      // Untyped catch for the same reason as [_delete].
      try {
        if (await _queue().hasHeldDelete(hash)) continue;
        if (hasOriginal) await _mediaRepository.clearRemoteUploaded(row.id);
        if (hasThumb) {
          await _mediaRepository.clearRemoteThumbUploaded(row.id);
        }
        if (hasRendition) {
          await _mediaRepository.clearRemoteCompressed(row.id);
        }
        await _queue().enqueueRepairUpload(mediaId: row.id);
        queued = true;
      } catch (e, stackTrace) {
        _log.warning(
          'Could not repair restored media ${row.id} (sweep will reconcile)',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    if (queued) await _kick('repair after undo');
  }

  /// [known] short-circuits the per-id read for callers that already hold
  /// the row; ids absent from it are read back as before.
  Future<void> _delete(
    List<String> ids,
    Map<String, MediaItem> known, {
    bool Function(MediaData row)? keepIf,
    bool kick = true,
  }) async {
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
    if (keepIf != null) {
      await _mediaRepository.deleteMultipleMedia(ids, keepIf: keepIf);
    } else if (ids.length == 1) {
      await _mediaRepository.deleteMedia(ids.single);
    } else {
      await _mediaRepository.deleteMultipleMedia(ids);
    }
    if (enqueued && kick) await _kick('media delete');
  }

  Future<void> _kick(String after) async {
    final kickWorker = _kickWorker;
    if (kickWorker == null) return;
    try {
      await kickWorker();
    } catch (e) {
      _log.warning('Worker kick after $after failed', error: e);
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
