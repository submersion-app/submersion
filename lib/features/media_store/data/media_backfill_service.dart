import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// "Upload existing library" (design spec section 9 trigger 2). Enqueues
/// every eligible photo; enqueueUpload is idempotent per media id, so
/// re-running is safe. Existing upload rows of the candidates are re-armed
/// with a fresh attempt budget, so ones that failed against a store the
/// diver has since left reach the attached one.
class MediaBackfillService {
  MediaBackfillService({
    required MediaRepository mediaRepository,
    required MediaTransferQueueRepository queue,
    MediaStoreAttachState? attachState,
    MediaStoresRepository? stores,
  }) : _mediaRepository = mediaRepository,
       _queue = queue,
       _attachState = attachState,
       _stores = stores;

  final MediaRepository _mediaRepository;
  final MediaTransferQueueRepository _queue;

  /// Names the attached store, so rows stamped in another store upload to
  /// this one (issue #3482).
  final MediaStoreAttachState? _attachState;

  /// Names the store the library announces: only a device attached to it
  /// takes over rows stamped in another store (issue #3569).
  final MediaStoresRepository? _stores;
  final _log = LoggerService.forClass(MediaBackfillService);

  Future<int> enqueueAll() async {
    final storeId = await _attachState?.attachedStoreId();
    final announced = (await _stores?.getActive())?.id;
    final ids = await _mediaRepository.getBackfillCandidateIds(
      storeId: storeId,
      takesOver: takesOverStores(storeId, announced),
    );
    for (final id in ids) {
      await _queue.enqueueUpload(mediaId: id);
    }
    // enqueueUpload hands back a terminally failed row unchanged, and a
    // pending one keeps the attempts it spent, possibly against another
    // store. Asking to upload everything is an explicit retry of them.
    final rearmed = await _queue.rearmUploads(ids);
    if (rearmed > 0) _log.info('Backfill re-armed $rearmed upload rows');
    _log.info('Backfill enqueued ${ids.length} items');
    return ids.length;
  }
}
