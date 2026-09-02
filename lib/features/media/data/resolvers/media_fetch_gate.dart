import 'dart:async';
import 'dart:collection';

import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// How long a fetch may hold a concurrency slot before it is handed on.
///
/// Short, because its job is to stop one unreachable item monopolising a
/// permit, not to give a healthy fetch a generous allowance. A store thumbnail
/// off a working endpoint lands in well under a second; anything past five is
/// already an outlier, and the cost of guessing wrong is only that the fetch
/// finishes without a slot.
const Duration kMediaFetchSlotBudget = Duration(seconds: 5);

/// How long a caller waits before settling for the still-loading placeholder.
///
/// Long, because this one is user-visible: it is the point at which a tile
/// stops shimmering and admits it does not have the bytes yet. Six times the
/// slot budget, so a merely slow source has ample room to arrive before the
/// user is told anything at all.
const Duration kMediaFetchTotalBudget = Duration(seconds: 30);

/// Caps simultaneous media-store fetches and collapses duplicate ones.
///
/// Nothing gated the store read path before #1175. Every visible grid tile
/// resolves independently -- `MediaItemView` kicks its own future from
/// `initState` -- so a screenful of store-backed thumbnails opened one HEAD
/// plus one GET per tile, all at once. A 140 px grid puts 30-60 tiles on
/// screen on desktop, each request is retried up to six times with backoff,
/// and none of them shared work with any other. Against a slow endpoint that
/// is a gallery of permanent shimmer; against a healthy one it is still a
/// burst most S3-compatible servers throttle.
///
/// Three independent problems, one object:
///
/// * **Concurrency.** [maxConcurrent] fetches run at a time; the rest queue.
///   Matching `GalleryThumbnailCache`'s cap, which solved the same shape of
///   problem for PhotoKit.
/// * **Coalescing.** Two callers asking for the same key share one fetch.
///   That is not a micro-optimisation here: media rows are content-addressed,
///   so the same photo linked to two dives is two rows with one hash, and
///   without this each issues its own download of identical bytes and both
///   race to write the same cache entry.
/// * **Time.** A cap with no deadline turns one unreachable item into a
///   stalled gallery, because a permit held by a fetch against a dead share is
///   a permit no live tile can have. A fetch that outlives [slotBudget] hands
///   its slot to the next waiter and keeps running; a caller that outlives
///   [totalBudget] settles for [UnavailableKind.stillFetching]. Neither
///   cancels anything: Dart cannot cancel a `Future`, and the honest thing to
///   tell the user about a slow download is that it is slow, not that it
///   failed.
///
/// Deliberately NOT a byte cache. The bytes already have one -- `MediaCacheStore`,
/// on disk -- and holding them in memory as well is what the viewer's own
/// providers were doing wrong.
class MediaFetchGate {
  MediaFetchGate({
    this.maxConcurrent = 4,
    this.slotBudget = kMediaFetchSlotBudget,
    this.totalBudget = kMediaFetchTotalBudget,
    int? maxDetached,
  }) : assert(maxConcurrent > 0),
       assert(slotBudget <= totalBudget),
       maxDetached = maxDetached ?? maxConcurrent * 3;

  /// Ceiling on fetches holding a slot.
  final int maxConcurrent;

  /// Ceiling on fetches that outlived [slotBudget] and are still running.
  ///
  /// Without it, detaching would leak: against a dead mount the gate would
  /// start [maxConcurrent] fresh fetches every [slotBudget] forever, each
  /// parking a `dart:io` pool thread, which is the exact starvation this class
  /// exists to prevent (#1182). At the cap a fetch keeps its slot instead of
  /// detaching, restoring back-pressure. Outstanding work is therefore never
  /// more than [maxConcurrent] + [maxDetached], whatever the source does.
  final int maxDetached;

  /// How long a fetch may hold a slot.
  final Duration slotBudget;

  /// How long a caller waits before settling for
  /// [UnavailableKind.stillFetching].
  final Duration totalBudget;

  /// Raw fetches in flight, keyed for coalescing.
  ///
  /// Deliberately the fetch itself rather than a caller's bounded view of it.
  /// A caller that gave up at [totalBudget] leaves the fetch running, and a
  /// retry must join that one: starting a second download of bytes already on
  /// the way is the waste this map exists to prevent, and it is exactly what a
  /// user who taps a still-loading tile would trigger.
  final Map<String, Future<MediaSourceData?>> _inFlight =
      <String, Future<MediaSourceData?>>{};

  /// Callers parked waiting for a slot.
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();

  int _running = 0;
  int _detached = 0;

  /// Fetches holding a slot, for tests.
  int get runningCount => _running;

  /// Fetches that outlived [slotBudget] and are still running, for tests.
  int get detachedCount => _detached;

  /// Callers currently parked, for tests.
  int get waitingCount => _waiting.length;

  /// Runs [fetch] under the cap, sharing the result with any caller that asks
  /// for the same [key] while it is still running.
  ///
  /// Never leaves the caller waiting longer than [totalBudget]; past that it
  /// answers [UnavailableKind.stillFetching] and the fetch carries on without
  /// it.
  Future<MediaSourceData?> run(
    String key,
    Future<MediaSourceData?> Function() fetch,
  ) {
    final pending = _inFlight[key];
    if (pending != null) return _bounded(pending);

    // _withSlot suspends at its first await before returning, so the
    // assignment below always lands before the callback that clears it.
    final future = _withSlot(fetch);
    _inFlight[key] = future;
    // Cleared when the fetch really settles, not when a caller stops waiting.
    // The identity check keeps a late-settling fetch from evicting the entry a
    // subsequent call already replaced it with.
    future.whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }).ignore();
    return _bounded(future);
  }

  /// One caller's bounded view of [future]. The fetch itself is untouched.
  Future<MediaSourceData?> _bounded(Future<MediaSourceData?> future) {
    return future.timeout(
      totalBudget,
      onTimeout: () =>
          const UnavailableData(kind: UnavailableKind.stillFetching),
    );
  }

  Future<MediaSourceData?> _withSlot(
    Future<MediaSourceData?> Function() fetch,
  ) async {
    await _acquire();
    var holdsSlot = true;
    var detached = false;

    void detach() {
      if (!holdsSlot || _detached >= maxDetached) return;
      holdsSlot = false;
      detached = true;
      _detached++;
      _release();
    }

    // Cancelled in the finally block rather than left to fire harmlessly: a
    // stale firing would release a slot this fetch no longer holds, letting
    // the effective cap drift upward for the life of the process.
    final timer = Timer(slotBudget, detach);
    try {
      return await fetch();
    } finally {
      timer.cancel();
      if (detached) {
        _detached--;
      } else if (holdsSlot) {
        holdsSlot = false;
        _release();
      }
    }
  }

  Future<void> _acquire() {
    if (_running < maxConcurrent) {
      _running++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  /// FIFO, unlike `GalleryThumbnailCache`'s LIFO.
  ///
  /// That class serves newest-first on the argument that older waiters belong
  /// to tiles already scrolled away. It does not hold here: [run] hands a
  /// parked future to any later caller asking for the same key, so a waiter
  /// can have live tiles behind it, and newest-first would leave them shimmering
  /// for the whole of a long fling. Fairness is worth more than recency when a
  /// slot is 30-60 tiles deep.
  void _release() {
    if (_waiting.isEmpty) {
      _running--;
      return;
    }
    // The slot passes straight to the next waiter: _running stays put because
    // one fetch ends exactly as another begins.
    _waiting.removeFirst().complete();
  }
}
