import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media_store/data/media_delete_processor.dart';
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
    MediaDeleteProcessor? deleteProcessor,
    Future<bool> Function()? preflight,
    Future<WorkerGate> Function(MediaTransferQueueEntry entry)? gate,
  }) : _queue = queue,
       _pipeline = pipeline,
       _deleteProcessor = deleteProcessor,
       _preflight = preflight,
       _gate = gate;

  final MediaTransferQueueRepository _queue;
  final MediaUploadPipeline _pipeline;

  /// Handles direction == 'delete' entries (orphan-prevention spec 5).
  /// Null in wiring shapes that predate the delete fast path; such
  /// entries are parked in the defer window instead of processed.
  final MediaDeleteProcessor? _deleteProcessor;

  /// Returns false to suspend the drain (store marker mismatch, design
  /// spec section 13).
  final Future<bool> Function()? _preflight;

  /// Network/policy admission (design spec section 9). Null admits all.
  final Future<WorkerGate> Function(MediaTransferQueueEntry entry)? _gate;

  /// Deferral window for policy/connectivity-blocked entries.
  static const Duration deferWindow = Duration(minutes: 10);

  final _log = LoggerService.forClass(MediaStoreWorker);
  bool _running = false;
  bool _disposed = false;
  Future<void>? _activeDrain;
  Timer? _wakeup;
  Duration? _wakeupDelay;

  /// The delay the currently armed retry wakeup will wait, or null when no
  /// row is deferred. Lets a test assert scheduling without waiting it out.
  @visibleForTesting
  Duration? get wakeupDelayForTesting => _wakeupDelay;

  /// The drain kicked by [enqueueAndKick], if any. Completes only when the
  /// queue has been fully drained, including each entry's post-upload cleanup.
  /// [enqueueAndKick] fires the drain in the background, so callers (and tests)
  /// that need to observe completion await this instead of racing it.
  Future<void>? get activeDrain => _activeDrain;

  Future<void> drain() async {
    if (_disposed || _running) return;
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
        if (entry.direction == 'delete') {
          final deleteProcessor = _deleteProcessor;
          if (deleteProcessor == null) {
            // No processor wired: park the entry so the drain terminates;
            // a properly wired worker picks it up later.
            await _queue.defer(entry.id, DateTime.now().add(deferWindow));
            continue;
          }
          await deleteProcessor.process(entry);
          continue;
        }
        await _pipeline.process(entry);
      }
    } finally {
      _running = false;
      await _armWakeup();
    }
  }

  /// Arms a single timer for the soonest deferred row, so a retry that comes
  /// due mid-session actually fires.
  ///
  /// Every other drain trigger is an external event: app start, a
  /// connectivity change, an explicit user action. Without this, a row that
  /// markFailed parked behind a long retryAfter - 25 hours for a
  /// source-unavailable failure - sat untouched for the rest of the
  /// session, and the settings page kept reporting it as outstanding work
  /// the entire time.
  ///
  /// Runs in drain's finally and must never throw: an exception here would
  /// replace whatever the drain itself was reporting.
  Future<void> _armWakeup() async {
    _wakeup?.cancel();
    _wakeup = null;
    _wakeupDelay = null;
    // A rebuild disposes this worker without cancelling a drain it already
    // started, so dispose can land while one is in flight and this runs
    // afterwards. Re-arming then would leave a superseded worker waking
    // itself forever behind the runtime that replaced it.
    if (_disposed) return;
    try {
      // One clock reading for both the query and the delay, so the timer
      // cannot be handed a negative duration by the query's own latency.
      final now = DateTime.now();
      final due = await _queue.earliestPendingWakeup(now);
      if (due == null) return;
      final delay = due.difference(now);
      _wakeupDelay = delay;
      _wakeup = Timer(delay, () => unawaited(drain()));
    } on Object catch (e) {
      _log.warning('Could not schedule the next transfer retry: $e');
    }
  }

  /// Retires this worker. Called when the runtime that owns it is disposed
  /// (disconnect, or a connect that rebuilds it). Cancels the retry wakeup
  /// and blocks any further drain, including one a still-armed timer or a
  /// late caller would otherwise start.
  ///
  /// Deliberately does not touch an in-flight drain: a rebuild does not
  /// cancel one, and a half-cancelled transfer is worse than one that runs
  /// to completion against a store it already opened. That drain's finally
  /// still calls _armWakeup, which is why the flag - not just the cancel -
  /// is what makes disposal stick.
  void dispose() {
    _disposed = true;
    _wakeup?.cancel();
    _wakeup = null;
    _wakeupDelay = null;
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
