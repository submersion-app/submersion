import 'dart:convert';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// Drains 'delete' transfer-queue entries: removes a dead media row's
/// remote original, thumb, and rendition objects (orphan-prevention spec
/// section 5). The refcount re-check happens here at drain time - never at
/// enqueue time - so references that appear between the two (late sync
/// pulls, re-imports) win and the delete becomes a no-op.
class MediaDeleteProcessor {
  MediaDeleteProcessor({
    required MediaTransferQueueRepository queue,
    required MediaObjectStore store,
    required MediaRepository mediaRepository,
  }) : _queue = queue,
       _store = store,
       _mediaRepository = mediaRepository;

  final MediaTransferQueueRepository _queue;
  final MediaObjectStore _store;
  final MediaRepository _mediaRepository;
  final _log = LoggerService.forClass(MediaDeleteProcessor);

  Future<void> process(MediaTransferQueueEntry entry) async {
    await _queue.markTransferring(entry.id);
    try {
      final hash = entry.contentHash;
      if (hash == null || hash.isEmpty) {
        // Unusable intent; nothing safe to delete. The sweep is the
        // backstop.
        await _queue.markDone(entry.id);
        return;
      }
      if (await _mediaRepository.countRowsWithHash(hash) > 0) {
        await _queue.markDone(entry.id);
        return;
      }
      final payload = _parsePayload(entry.payloadJson);
      await _store.delete(
        StoreKeys.objectKey(hash, extension: payload.originalExt),
      );
      await _store.delete(StoreKeys.thumbKey(hash));
      await _store.delete(
        StoreKeys.renditionKey(hash, ext: payload.renditionExt),
      );
      await _queue.markDone(entry.id);
    } on Exception catch (e, stackTrace) {
      _log.warning(
        'Remote delete failed for ${entry.contentHash}',
        error: e,
        stackTrace: stackTrace,
      );
      await _queue.markFailed(entry.id, e.toString());
    }
  }

  /// Defensive parse: a corrupt payload degrades to plausible extensions
  /// rather than failing the entry - deleting a key that never existed is
  /// an idempotent no-op, and anything missed falls to the sweep.
  ({String originalExt, String renditionExt}) _parsePayload(String? json) {
    if (json != null) {
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map<String, dynamic>) {
          final original = decoded['originalExt'];
          final rendition = decoded['renditionExt'];
          if (original is String && rendition is String) {
            return (originalExt: original, renditionExt: rendition);
          }
        }
      } on FormatException {
        // fall through to defaults
      }
    }
    return (originalExt: 'bin', renditionExt: 'jpg');
  }
}
