import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media_store/data/media_delete_processor.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';
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
    Future<MediaTransferHoldKind?> Function()? preflight,
    Future<bool> Function()? isOffline,
    Future<WorkerGate> Function(MediaTransferQueueEntry entry)? gate,
    Duration entryBudget = defaultEntryBudget,
    Duration preflightBudget = defaultPreflightBudget,
    Duration preflightRetryWindow = defaultPreflightRetryWindow,
  }) : _queue = queue,
       _pipeline = pipeline,
       _deleteProcessor = deleteProcessor,
       _preflight = preflight,
       _isOffline = isOffline,
       _gate = gate,
       _entryBudget = entryBudget,
       _preflightBudget = preflightBudget,
       _preflightRetryWindow = preflightRetryWindow {
    // A claim released while this worker is idle is a transfer that
    // settled outside any drain of its own: late, past its budget, or after
    // the worker that started it was replaced. A backoff it left behind has
    // no wakeup, so drain, which arms one. While the drain loop runs, the
    // release is the loop's to see; while it schedules its wakeup, the
    // drain runs once more after, rather than a second one beside it.
    _releaseSub = queue.claimReleases.listen((_) {
      if (_disposed) return;
      if (!_running) {
        unawaited(drain());
      } else if (_scheduling) {
        _drainAgain = true;
      }
    });
  }

  late final StreamSubscription<void> _releaseSub;

  final MediaTransferQueueRepository _queue;
  final MediaUploadPipeline _pipeline;

  /// Handles direction == 'delete' entries (orphan-prevention spec 5).
  /// Null in wiring shapes that predate the delete fast path; such
  /// entries are parked in the defer window instead of processed.
  final MediaDeleteProcessor? _deleteProcessor;

  /// Returns null to admit the drain, or the kind of refusal that suspends
  /// it (detached, or a store marker mismatch; design spec section 13).
  final Future<MediaTransferHoldKind?> Function()? _preflight;

  /// Asked only when the preflight throws, to tell an offline moment (a
  /// quiet hold) from a store that cannot be checked (a suspension). Null
  /// reads as online, and so does a throw from it: the reason then shows,
  /// which is the safer mistake.
  final Future<bool> Function()? _isOffline;

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

  /// How long a drain the preflight suspended waits before trying again.
  ///
  /// A suspended drain leaves its due rows untouched, which is right for the
  /// rows (no attempt burned, no backoff written) but left the queue with
  /// nothing to wake it: [MediaTransferQueueRepository.earliestPendingWakeup]
  /// deliberately skips rows that are already due. Every retry then hung on
  /// an external trigger re-running the same check, and on desktop, where
  /// the app sits in one process for days, the rows read "Waiting" for as
  /// long (issue #1356). The preflight is one small GET, so a periodic retry
  /// costs almost nothing, and it is what lets a marker that was merely slow
  /// to download from iCloud clear on its own.
  static const Duration defaultPreflightRetryWindow = Duration(minutes: 10);

  final Duration _entryBudget;
  final Duration _preflightBudget;
  final Duration _preflightRetryWindow;

  final _log = LoggerService.forClass(
    MediaStoreWorker,
    category: LogCategory.media,
  );
  bool _running = false;

  /// Whether a finished drain is scheduling its wakeup (still [_running]).
  bool _scheduling = false;

  /// Set when a transfer settled while the drain was scheduling: the drain
  /// runs once more when it is done, since its wakeup may predate the row.
  bool _drainAgain = false;
  bool _disposed = false;
  bool _suspended = false;
  final _suspensionChanges = StreamController<bool>.broadcast();
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

  /// Whether the most recent preflight suspended the drain. The queue's rows
  /// carry no trace of a suspension (they are left exactly as they were), so
  /// without this the only record was a log line and the settings page could
  /// not tell "paused" from "queued" (issue #1356).
  bool get isSuspended => _suspended;

  /// The current value on subscribe, then every change.
  ///
  /// Emitting the current value is load-bearing, not a convenience: the
  /// runtime fires its first drain before any reader can subscribe, and
  /// [_setSuspended] never repeats a value it has already sent. A reader
  /// that sampled [isSuspended] and then subscribed would silently lose a
  /// flip that landed in between, and nothing would ever re-send it.
  Stream<bool> get suspensionChanges => Stream<bool>.multi((controller) {
    controller.add(_suspended);
    final subscription = _suspensionChanges.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });

  void _setSuspended(bool value) {
    if (_suspended == value) return;
    _suspended = value;
    if (!_suspensionChanges.isClosed) _suspensionChanges.add(value);
  }

  Future<void> drain() async {
    if (_disposed || _running) return;
    _running = true;
    // Set only on the one exit that means "nothing was due, and I looked":
    // every other way out of the loop - a failed preflight, a gate that
    // stopped the drain, an exception out of the pipeline - leaves work
    // behind on purpose, and must not arm the immediate wakeup below.
    var drainedToEmpty = false;
    // Whether the preflight stopped this drain, for ANY reason. Separate from
    // the user-visible [isSuspended], which speaks only for a determinate
    // refusal: a preflight that could not answer (offline) still leaves due
    // rows behind with nothing to pick them up, so scheduling has to know
    // about it even though the UI must not.
    var preflightBlocked = false;
    try {
      // Rows a dead process or a superseded worker left in 'transferring'
      // are invisible to nextPending. Leases keep this off any row a live
      // transfer in this process owns, so it runs on every drain: launch,
      // resume and rebuild alike (spec 7.1).
      await _reclaimStranded();
      while (true) {
        // Re-checked per entry, not once per drain: a store wipe or user
        // disconnect mid-drain must suspend the rest of the queue.
        if (!await _preflightPasses()) {
          preflightBlocked = true;
          return;
        }
        // Claimed, not just selected: another worker draining this queue (a
        // rebuild leaves the superseded one running) must not take the same
        // row, from here through the gate to the end of its transfer.
        final entry = await _queue.claimNextPending(DateTime.now());
        if (entry == null) {
          drainedToEmpty = true;
          break;
        }
        // Whether the claim went to a transfer, which releases it when the
        // transfer settles. Every other way out of this iteration gives it
        // back here.
        var handedOff = false;
        try {
          if (_gate != null) {
            final WorkerGate decision;
            try {
              decision = await _gate(entry);
            } on Object catch (e, stackTrace) {
              // The gate reads connectivity and policies, and any of them
              // can throw. Treated as a failed admission: the stop is held
              // with its reason and the retry window armed, never a silent
              // exit (or an uncaught error from an unawaited drain).
              await _gateFailed(e, stackTrace);
              preflightBlocked = true;
              break;
            }
            if (decision == WorkerGate.stopDraining) {
              _log.info('Drain stopped by gate (offline or suspended)');
              _hold(_offlineHold);
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
              // This worker can never process it, and a deferral only hid
              // that behind a retry that could not succeed (spec 7.1).
              // Failed with a message, it shows, and Retry brings it back
              // once a wired worker exists.
              await _queue.fail(
                entry.id,
                'No delete processor on this device; retry once it has one',
              );
              continue;
            }
            handedOff = true;
            await _withinBudget(entry, () => deleteProcessor.process(entry));
            continue;
          }
          handedOff = true;
          await _withinBudget(entry, () async {
            await _pipeline.process(entry);
          });
        } finally {
          if (!handedOff) _queue.release(entry.id);
        }
      }
    } finally {
      // Still running while the wakeup is scheduled: a second drain started
      // in this window would cancel or overwrite this one's timer and hold.
      // A transfer that settles meanwhile is not lost, though: it asks for
      // a follow-up drain, run once scheduling is done.
      _scheduling = true;
      try {
        await _armWakeup(
          drainedToEmpty: drainedToEmpty,
          preflightBlocked: preflightBlocked,
        );
      } finally {
        _scheduling = false;
        _running = false;
      }
      if (_drainAgain && !_disposed) {
        _drainAgain = false;
        unawaited(drain());
      }
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
  ///
  /// Owns the entry's claim, and releases it only when [work] settles, not
  /// when the budget runs out: a timed-out transfer keeps running, and until
  /// it stops no later drain may select its row (still pending, if the hang
  /// came before markTransferring) or reclaim it (transferring).
  Future<void> _withinBudget(
    MediaTransferQueueEntry entry,
    Future<void> Function() work,
  ) async {
    final Future<void> running;
    try {
      running = work();
    } on Object {
      _queue.release(entry.id);
      rethrow;
    }
    // Its own listener, so the release outlives the timeout below. Errors
    // surface through the awaited timeout; this copy of them is dropped. A
    // release after the drain gave up is heard by every idle worker over
    // this queue (see the constructor), which arms the retry.
    running.whenComplete(() => _queue.releaseSettled(entry.id)).ignore();
    try {
      await running.timeout(_entryBudget);
    } on TimeoutException {
      _log.warning(
        'Transfer entry ${entry.id} (media ${entry.mediaId}) exceeded its '
        '${_entryBudget.inMinutes}m budget; deferring it and draining on',
      );
      await _queue.defer(
        entry.id,
        DateTime.now().add(deferWindow),
        reason:
            'Took longer than its ${_entryBudget.inMinutes}m budget; '
            'retrying later',
        // As claimed (a fresh read): a failure the transfer recorded before
        // the budget ran out moved it, and its own retry time and error
        // stand.
        ifAttempts: entry.attempts,
      );
    }
  }

  /// Never throws: a failed reclaim leaves the stranded rows for the next
  /// drain, and must not stop this one taking the rows that are due.
  Future<void> _reclaimStranded() async {
    try {
      final reclaimed = await _queue.requeueStale();
      if (reclaimed > 0) {
        _log.info('Reclaimed $reclaimed stranded transfer(s)');
      }
    } on Object catch (e, stackTrace) {
      _log.warning(
        'Could not reclaim stranded transfers',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Whether the drain may proceed. Null preflight admits everything. Every
  /// outcome is recorded as the queue's hold (spec 7.1: the queue never
  /// waits silently), and a pass clears it.
  ///
  /// A refusal suspends the drain and names its kind: detached, or a marker
  /// mismatch.
  ///
  /// A preflight that throws stops the drain too. It reads the store marker
  /// out of the bucket, so an offline moment or a transient failure makes it
  /// throw rather than answer - and since every drain() call site is
  /// fire-and-forget (app start, connectivity change, the retry wakeup,
  /// enqueueAndKick), an escaping throw had no handler and surfaced as an
  /// uncaught zone error instead of a stopped drain (#942). Stopping is also
  /// the safe reading: the check exists to stop transfers against a store
  /// this device may no longer be attached to, so "could not verify" must
  /// never be treated as "verified". What it tells the user depends on
  /// [_isOffline]: offline holds quietly, because drain() runs this check
  /// BEFORE the gate that owns offline and an ordinary moment without network
  /// must not read as a broken store; online, the store itself could not be
  /// checked, and that suspends with the error as its reason.
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
    if (preflight == null) {
      _hold(null);
      return true;
    }
    try {
      final refusal = await preflight().timeout(_preflightBudget);
      if (refusal == null) {
        _hold(null);
        return true;
      }
      _log.warning('Media store preflight refused ($refusal); drain suspended');
      _hold(MediaTransferHold(refusal, _refusalMessages[refusal]!));
    } on Object catch (e, stackTrace) {
      if (await _offline()) {
        _log.info('Media store preflight could not run while offline');
        _hold(_offlineHold);
      } else {
        _log.warning(
          'Media store preflight could not run; drain suspended',
          error: e,
          stackTrace: stackTrace,
        );
        _hold(
          MediaTransferHold(
            MediaTransferHoldKind.storeUnreachable,
            'Could not check the media store: $e',
          ),
        );
      }
    }
    return false;
  }

  /// Holds the drain for a gate that threw, as a preflight throw is held:
  /// quietly while offline, otherwise with the error as its reason.
  Future<void> _gateFailed(Object e, StackTrace stackTrace) async {
    if (await _offline()) {
      _log.info('Transfer gate could not run while offline');
      _hold(_offlineHold);
      return;
    }
    _log.warning(
      'Transfer gate could not run; drain held',
      error: e,
      stackTrace: stackTrace,
    );
    _hold(
      MediaTransferHold(
        MediaTransferHoldKind.storeUnreachable,
        'Could not check transfer conditions: $e',
      ),
    );
  }

  static const _offlineHold = MediaTransferHold(
    MediaTransferHoldKind.offline,
    'Offline',
  );

  /// The diagnostic message for each refusal a preflight can answer.
  static const _refusalMessages = {
    MediaTransferHoldKind.offline: 'Offline',
    MediaTransferHoldKind.storeUnreachable: 'Could not check the media store',
    MediaTransferHoldKind.detached:
        'This device is no longer attached to this media store',
    MediaTransferHoldKind.markerMismatch:
        'The media store no longer carries the marker this device attached to',
  };

  Future<bool> _offline() async {
    final isOffline = _isOffline;
    if (isOffline == null) return false;
    try {
      return await isOffline();
    } on Object {
      return false;
    }
  }

  /// Records [hold] on the queue, where the summary reads it, and mirrors
  /// its suspension into [isSuspended].
  ///
  /// A no-op once disposed: dispose does not stop a drain already running,
  /// and the queue's hold is shared with the worker that replaced this one,
  /// which must not have its reason overwritten by a superseded loop.
  void _hold(MediaTransferHold? hold) {
    if (_disposed) return;
    _queue.recordHold(hold, owner: this);
    _setSuspended(hold?.suspends ?? false);
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
  ///
  /// [preflightBlocked] says the preflight stopped the drain. Its due rows
  /// are still due, so the immediate branch must not take them (it would spin
  /// against a check that keeps failing); they get the
  /// [defaultPreflightRetryWindow] instead.
  Future<void> _armWakeup({
    required bool drainedToEmpty,
    required bool preflightBlocked,
  }) async {
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
      if (preflightBlocked) {
        // Always arm, even with an empty queue. A blocked preflight is
        // re-run only by a drain, and a suspension is cleared only by one
        // that passes, so a drain that armed nothing here could never
        // recover in this process. Both halves need it: an offline blip
        // would otherwise strand every due row until an unrelated trigger,
        // and the final iteration of an emptying drain can record a
        // suspension with nothing left to carry a timer, leaving the notice
        // standing forever over a queue with nothing in it.
        //
        // Never later than a row's own backoff. That timer is the one this
        // branch replaces, and a row deferred for thirty seconds must not
        // wait out the retry window because an unrelated check failed.
        final due = await _queue.earliestPendingWakeup(now);
        final backoff = due?.difference(now);
        final delay = backoff != null && backoff > Duration.zero
            ? (backoff < _preflightRetryWindow
                  ? backoff
                  : _preflightRetryWindow)
            : _preflightRetryWindow;
        _wakeupDelay = delay;
        _wakeup = Timer(delay, () => unawaited(drain()));
        return;
      }
      // The drain asked "what is due?" against its own clock reading, and
      // earliestPendingWakeup asks "what is not due yet?" against this one.
      // Those are complements only if no time passed in between, so a row
      // whose backoff expired since - or one enqueued since, which the
      // single-flight guard turned into a no-op kick - answers to neither
      // query and would wait for an unrelated trigger (#1210). Hand it
      // straight back to a fresh drain.
      //
      // Only when the drain reached an empty queue. A drain that declined to
      // run (offline, or the preflight case handled above) left its due row
      // behind deliberately, and re-kicking that would spin against a drain
      // that keeps declining.
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
  ///
  /// Clears the queue's hold if this worker recorded the current one: a
  /// disconnect builds no runtime in its place, and a hold left standing
  /// would name a store this device no longer uses. The board tracks who
  /// recorded it, so a replacement's reason survives this worker retiring.
  void dispose() {
    _disposed = true;
    _wakeup?.cancel();
    _wakeup = null;
    _wakeupDelay = null;
    _queue.clearHoldOwnedBy(this);
    unawaited(_releaseSub.cancel());
    _suspensionChanges.close();
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
