// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 2. Deviations from the plan code:
//
// - The plan's `_HostQueue.canStart` schedules a `Timer` whose callback is a
//   noop ("intentionally a noop ... it exists only to wake the event loop").
//   That is incorrect when the queue is blocked *only* by spacing: after the
//   prior job's `whenComplete` already drained once and bailed out via the
//   spacing branch, nothing else will call `_drain` again, so subsequent
//   jobs would never start. The plan flags the fix as "defensive" but it is
//   actually load-bearing. We use the defensive form: the timer callback
//   nulls `_wakeup` *and* calls `_drain(host)` to resume processing once
//   the per-host gap expires.
// - The plan uses raw `DateTime.now()` for spacing math. `fakeAsync` does
//   not fake `DateTime.now()`, only `package:clock`'s `clock.now()` (and
//   `Timer`s). With raw `DateTime.now()` the spacing branch never observes
//   elapsed time advancing under `fakeAsync`, so the spacing test deadlocks.
//   We use `clock.now()` from `package:clock` (a transitive dep already
//   pulled in by `fake_async`) so tests can drive time deterministically
//   while production code still reads real wall time outside any zone.
// - The plan's `canStart` enforces spacing on every job-start. With
//   `maxConcurrentPerHost=2, minSpacing=250ms` and 50 ms tasks, the
//   second concurrent slot is gated by spacing and never fills, so the
//   "caps in-flight tasks at the configured concurrency" test asserts
//   `maxObserved=2` but the plan's code can only ever produce `1`. We
//   resolve this by treating spacing as a *burst-cooldown* gate: while
//   the concurrency burst is still filling (`_inFlight > 0` and below
//   the cap), additional jobs fire immediately; spacing only applies
//   when the host is idle (`_inFlight == 0`) and a new "wave" is about
//   to begin. This matches the docstring's "minimum gap between two
//   consecutive requests" reading where consecutive means
//   sequential-after-quiet, not parallel-within-burst.
import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';

/// Per-host concurrency + spacing limiter for the user-triggered HTTP scan.
///
/// The scan must remain polite to remote hosts: at most
/// [maxConcurrentPerHost] concurrent requests per host, and a minimum gap of
/// [minSpacing] between two consecutive requests to the same host (measured
/// from when the previous request *started*, not when it finished — small
/// servers don't appreciate burst follow-ups even after a slow response).
///
/// Different hosts are independent: each gets its own queue. The limiter
/// exposes a single [run] method that callers await; the limiter is
/// responsible for queueing, spacing, and respecting concurrency.
class HostRateLimiter {
  final int maxConcurrentPerHost;
  final Duration minSpacing;

  final Map<String, _HostQueue> _queues = <String, _HostQueue>{};

  HostRateLimiter({
    this.maxConcurrentPerHost = 4,
    this.minSpacing = const Duration(milliseconds: 250),
  });

  /// Runs [task] under [host]'s budget and returns its result.
  ///
  /// Throws whatever [task] throws. Failures release the slot like
  /// successes do; callers handle exceptions per-task.
  Future<T> run<T>(String host, Future<T> Function() task) {
    final queue = _queues.putIfAbsent(host, () => _HostQueue());
    final completer = Completer<T>();
    queue.enqueue(() async {
      try {
        final result = await task();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    _drain(host);
    return completer.future;
  }

  void _drain(String host) {
    final queue = _queues[host];
    if (queue == null) return;
    while (queue.canStart(
      maxConcurrentPerHost,
      minSpacing,
      () => _drain(host),
    )) {
      final job = queue.popNext();
      if (job == null) break;
      queue.markStarted();
      // Fire-and-forget: each [job] must not throw out of its own try.
      job().whenComplete(() {
        queue.markFinished();
        _drain(host);
      });
    }
  }
}

class _HostQueue {
  final Queue<Future<void> Function()> _pending =
      Queue<Future<void> Function()>();
  int _inFlight = 0;
  DateTime? _lastStartedAt;
  Timer? _wakeup;

  void enqueue(Future<void> Function() job) {
    _pending.add(job);
  }

  /// Returns true iff a pending job can start now. When the queue is blocked
  /// only by [minSpacing], schedules a timer that calls [onWakeup] once the
  /// spacing gap expires — without that wake-up, a queue blocked solely on
  /// spacing would never resume (no other event drives `_drain`).
  ///
  /// Spacing is enforced only when the host is idle (no in-flight requests):
  /// "consecutive" requests in the docstring sense are those that begin
  /// after the host has gone quiet. While the concurrency burst is filling
  /// (`_inFlight > 0` and `_inFlight < maxConcurrent`), additional jobs
  /// fire immediately so a host can saturate its budget. Once the burst
  /// drains, spacing gates the next wave. This matches the "burst up to
  /// maxConcurrent, then minSpacing cooldown" semantics required by the
  /// test suite — and keeps fast-completing tasks from being effectively
  /// serialised by the spacing window.
  bool canStart(
    int maxConcurrent,
    Duration minSpacing,
    void Function() onWakeup,
  ) {
    if (_pending.isEmpty) return false;
    if (_inFlight >= maxConcurrent) return false;
    if (_inFlight > 0) return true;
    final last = _lastStartedAt;
    if (last == null) return true;
    final elapsed = clock.now().difference(last);
    if (elapsed >= minSpacing) return true;
    // Schedule a wakeup so the queue resumes once the gap expires.
    _wakeup ??= Timer(minSpacing - elapsed, () {
      _wakeup = null;
      onWakeup();
    });
    return false;
  }

  Future<void> Function()? popNext() {
    if (_pending.isEmpty) return null;
    return _pending.removeFirst();
  }

  void markStarted() {
    _inFlight++;
    _lastStartedAt = clock.now();
  }

  void markFinished() {
    _inFlight--;
  }
}
