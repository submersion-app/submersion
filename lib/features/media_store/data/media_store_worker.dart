import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';

/// Sequential single-flight queue drainer (Phase 1). Phase 2 adds
/// lifecycle/connectivity triggers; Phase 3 adds parallelism and progress.
class MediaStoreWorker {
  MediaStoreWorker({
    required MediaTransferQueueRepository queue,
    required MediaUploadPipeline pipeline,
    Future<bool> Function()? preflight,
  }) : _queue = queue,
       _pipeline = pipeline,
       _preflight = preflight;

  final MediaTransferQueueRepository _queue;
  final MediaUploadPipeline _pipeline;

  /// Returns false to suspend the drain (store marker mismatch, design
  /// spec section 13).
  final Future<bool> Function()? _preflight;

  final _log = LoggerService.forClass(MediaStoreWorker);
  bool _running = false;

  Future<void> drain() async {
    if (_running) return;
    _running = true;
    try {
      if (_preflight != null && !await _preflight()) {
        _log.warning('Media store preflight failed; drain suspended');
        return;
      }
      while (true) {
        final entry = await _queue.nextPending(DateTime.now());
        if (entry == null) break;
        await _pipeline.process(entry);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> enqueueAndKick(String mediaId) async {
    await _queue.enqueueUpload(mediaId: mediaId);
    unawaited(drain());
  }
}
