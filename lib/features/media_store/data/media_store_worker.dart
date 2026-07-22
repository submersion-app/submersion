import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// Per-entry admission decision made just before processing.
enum WorkerGate { proceed, deferEntry, stopDraining }

/// Sequential single-flight queue drainer. Phase 2 adds the per-entry
/// gate (network policies) and connectivity triggers; Phase 3 adds
/// parallelism and progress.
class MediaStoreWorker {
  MediaStoreWorker({
    required MediaTransferQueueRepository queue,
    required MediaUploadPipeline pipeline,
    Future<bool> Function()? preflight,
    Future<WorkerGate> Function(MediaTransferQueueEntry entry)? gate,
  }) : _queue = queue,
       _pipeline = pipeline,
       _preflight = preflight,
       _gate = gate;

  final MediaTransferQueueRepository _queue;
  final MediaUploadPipeline _pipeline;

  /// Returns false to suspend the drain (store marker mismatch, design
  /// spec section 13).
  final Future<bool> Function()? _preflight;

  /// Network/policy admission (design spec section 9). Null admits all.
  final Future<WorkerGate> Function(MediaTransferQueueEntry entry)? _gate;

  /// Deferral window for policy/connectivity-blocked entries.
  static const Duration deferWindow = Duration(minutes: 10);

  final _log = LoggerService.forClass(MediaStoreWorker);
  bool _running = false;
  Future<void>? _activeDrain;

  /// The drain kicked by [enqueueAndKick], if any. Completes only when the
  /// queue has been fully drained, including each entry's post-upload cleanup.
  /// [enqueueAndKick] fires the drain in the background, so callers (and tests)
  /// that need to observe completion await this instead of racing it.
  Future<void>? get activeDrain => _activeDrain;

  Future<void> drain() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        // Re-checked per entry, not once per drain: a store wipe or user
        // disconnect mid-drain must suspend the rest of the queue.
        if (_preflight != null && !await _preflight()) {
          _log.warning('Media store preflight failed; drain suspended');
          return;
        }
        final entry = await _queue.nextPending(DateTime.now());
        if (entry == null) break;
        if (_gate != null) {
          final decision = await _gate(entry);
          if (decision == WorkerGate.stopDraining) {
            _log.info('Drain stopped by gate (offline or suspended)');
            break;
          }
          if (decision == WorkerGate.deferEntry) {
            await _queue.defer(entry.id, DateTime.now().add(deferWindow));
            continue;
          }
        }
        await _pipeline.process(entry);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> enqueueAndKick(String mediaId) async {
    await _queue.enqueueUpload(mediaId: mediaId);
    _activeDrain = drain();
    unawaited(_activeDrain!);
  }

  /// Enqueues a forced re-upload of [mediaId] at [level] (per-item override)
  /// and kicks a background drain.
  Future<void> reuploadAndKick(String mediaId, MediaUploadQuality level) async {
    await _queue.enqueueReupload(mediaId: mediaId, overrideLevel: level.name);
    _activeDrain = drain();
    unawaited(_activeDrain!);
  }
}
