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
    Duration entryBudget = defaultEntryBudget,
    Duration preflightBudget = defaultPreflightBudget,
  }) : _queue = queue,
       _pipeline = pipeline,
       _deleteProcessor = deleteProcessor,
       _preflight = preflight,
       _gate = gate,
       _entryBudget = entryBudget,
       _preflightBudget = preflightBudget;

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

  /// How long the drain waits on one entry before moving to the next.
  ///
  /// Generous on purpose. This is not a policy on how fast a transfer ought
  /// to be - an original-quality video over a slow uplink legitimately takes
  /// a long time, and the adapters that do carry request timeouts (only S3,
  /// at S3ApiClient.defaultUploadTimeout) already police that layer. Its one
  /// job is to keep a transfer that will never come back from freezing the
  /// whole queue, which is what happened in issue #1270.
  static const Duration defaultEntryBudget = Duration(minutes: 30);

  /// How long the drain waits on the preflight before giving up on it.
  ///
  /// Much shorter than [defaultEntryBudget] because the work is much
  /// smaller: one GET of smv1/store.json. It runs before EVERY entry, so a
  /// stall here wedges the drain without a single row being touched.
  static const Duration defaultPreflightBudget = Duration(seconds: 30);

  final Duration _entryBudget;
  final Duration _preflightBudget;

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
    // Set only on the one exit that means "nothing was due, and I looked":
    // every other way out of the loop - a failed preflight, a gate that
    // stopped the drain, an exception out of the pipeline - leaves work
    // behind on purpose, and must not arm the immediate wakeup below.
    var drainedToEmpty = false;
    try {
      while (true) {
        // Re-checked per entry, not once per drain: a store wipe or user
        // disconnect mid-drain must suspend the rest of the queue.
        if (!await _preflightPasses()) return;
        final entry = await _queue.nextPending(DateTime.now());
        if (entry == null) {
          drainedToEmpty = true;
          break;
        }
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
          await _withinBudget(entry, () => deleteProcessor.process(entry));
          continue;
        }
        await _withinBudget(entry, () async {
          await _pipeline.process(entry);
        });
      }
    } finally {
      _running = false;
      await _armWakeup(drainedToEmpty: drainedToEmpty);
    }
  }

  /// Runs one entry's processing under [_entryBudget], moving on rather than
  /// waiting forever (issue #1270).
  ///
  /// The budget stops the drain WAITING; it does not stop the transfer. Dart
  /// cannot cancel a Future, so [work] keeps running and still owns its queue
  /// row - which is what makes moving on safe. The row it left in
  /// 'transferring' is invisible to [MediaTransferQueueRepository.nextPending]
  /// until that call finally settles it, and every staging path is minted per
  /// call ([MediaCacheStore.stagingFile]), so the entries that follow cannot
  /// collide with the one still in flight.
  ///
  /// The deferral is load-bearing in exactly one case: a hang BEFORE
  /// markTransferring (a stalled queue write, or a processor that never
  /// reaches it) leaves the row 'pending' and re-selectable, and without a
  /// future nextAttemptAt the loop would pick it straight back up and spin.
  /// On the ordinary 'transferring' row the write is inert. [defer] is the
  /// right verb either way: a budget expiry is a postponement, not a failed
  /// attempt - the transfer may yet succeed, so it must not burn one of the
  /// five attempts markFailed counts.
  Future<void> _withinBudget(
    MediaTransferQueueEntry entry,
    Future<void> Function() work,
  ) async {
    try {
      await work().timeout(_entryBudget);
    } on TimeoutException {
      _log.warning(
        'Transfer entry ${entry.id} (media ${entry.mediaId}) exceeded its '
        '${_entryBudget.inMinutes}m budget; deferring it and draining on',
      );
      await _queue.defer(entry.id, DateTime.now().add(deferWindow));
    }
  }

  /// Whether the drain may proceed. Null preflight admits everything.
  ///
  /// A preflight that throws suspends the drain exactly like one that returns
  /// false. It reads the store marker out of the bucket, so an offline moment
  /// or a transient S3 failure makes it throw rather than answer - and since
  /// every drain() call site is fire-and-forget (app start, connectivity
  /// change, the retry wakeup, enqueueAndKick), an escaping throw had no
  /// handler and surfaced as an uncaught zone error instead of a suspended
  /// drain (#942). Suspending is also the safe reading: the check exists to
  /// stop transfers against a store this device may no longer be attached to,
  /// so "could not verify" must never be treated as "verified".
  ///
  /// A preflight that never answers is the same case, and reaches the same
  /// handler: [_preflightBudget] turns the stall into a TimeoutException.
  /// Only the S3 adapter carries request timeouts of its own, so on the
  /// others this is the sole thing standing between a stalled marker read
  /// and a drain that hangs before touching a single row (issue #1270).
  ///
  /// The throw is logged with its error and stack trace, not interpolated into
  /// the message: catching it is what stops the crash, so the log is now the
  /// only record of a preflight that keeps failing, and a bare string would
  /// make that state less diagnosable than the uncaught zone error it replaced.
  Future<bool> _preflightPasses() async {
    final preflight = _preflight;
    if (preflight == null) return true;
    try {
      if (await preflight().timeout(_preflightBudget)) return true;
      _log.warning('Media store preflight failed; drain suspended');
    } on Object catch (e, stackTrace) {
      _log.warning(
        'Media store preflight could not run; drain suspended',
        error: e,
        stackTrace: stackTrace,
      );
    }
    return false;
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
  ///
  /// [drainedToEmpty] says the drain looked and found nothing due. That is
  /// what makes the already-due branch below safe; see it for why.
  Future<void> _armWakeup({required bool drainedToEmpty}) async {
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
      // The drain asked "what is due?" against its own clock reading, and
      // earliestPendingWakeup asks "what is not due yet?" against this one.
      // Those are complements only if no time passed in between, so a row
      // whose backoff expired since - or one enqueued since, which the
      // single-flight guard turned into a no-op kick - answers to neither
      // query and would wait for an unrelated trigger (#1210). Hand it
      // straight back to a fresh drain.
      //
      // Only when the drain reached an empty queue. A drain that declined to
      // run (offline, failed preflight) left its due row behind deliberately,
      // and re-kicking that would spin against a drain that keeps declining.
      // A drain that emptied the queue cannot: every loop exit consumes its
      // entry, so the next drain either takes this row or is itself a decline.
      if (drainedToEmpty && await _queue.nextPending(now) != null) {
        _wakeupDelay = Duration.zero;
        _wakeup = Timer(Duration.zero, () => unawaited(drain()));
        return;
      }
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
