// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md`
// Task 12. Thin wrapper that decides *when* `SubscriptionPoller.pollAllDue`
// runs:
//
// 1. App-launch warm-up. `startAfterWarmup()` waits 30 s, then runs one cycle
//    and schedules the next periodic timer.
// 2. Periodic timer. `_scheduleNext()` re-reads the active subscriptions'
//    `pollIntervalSeconds`, computes the cadence via `computeInterval`, and
//    arms a one-shot `Timer` that re-schedules itself after firing. We use a
//    self-rescheduling one-shot rather than `Timer.periodic` so the cadence
//    can adapt as subscriptions are added / removed / re-configured between
//    cycles.
// 3. User-triggered single cycle. `pollNow()` runs a cycle immediately and
//    returns the count from the underlying poller.
//
// Plan deviations:
//
// - The plan recommends `package:meta` for `@visibleForTesting`. The rest of
//   the codebase imports it from `package:flutter/foundation.dart`, so we
//   follow that convention here for consistency.
// - The plan specifies that Step 4 wires `startAfterWarmup()` from `main.dart`
//   via a post-frame callback. That step is intentionally deferred to
//   Phase 3c (Settings page integration). The provider in
//   `media_resolver_providers.dart` is created lazily on first read, so any
//   future caller — Settings page, manifest mode panel, or `main.dart` —
//   can `startAfterWarmup()` itself when the time comes.
// - The plan's `pollNow()` returns `Future<int>`. We keep that signature
//   (matches `SubscriptionPoller.pollAllDue`'s return) so callers that want
//   to surface "polled N subscriptions" toasts can do so without any
//   additional bookkeeping.
import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/services/subscription_poller.dart';

/// Schedules [SubscriptionPoller.pollAllDue] cycles.
///
/// Three triggers run a cycle:
///
/// - **App-launch warm-up.** [startAfterWarmup] sleeps 30 s, runs one cycle,
///   and schedules the next periodic cycle.
/// - **Periodic timer.** Self-rescheduling `Timer` armed by [_scheduleNext];
///   cadence is recomputed each cycle from the active subscriptions'
///   `pollIntervalSeconds` via [computeInterval].
/// - **User-triggered.** [pollNow] runs a cycle immediately, returning the
///   number of subscriptions visited.
///
/// The scheduler is a Riverpod-managed singleton; [dispose] cancels the
/// outstanding timer when the provider is torn down.
class SubscriptionPollerScheduler {
  SubscriptionPollerScheduler({
    required SubscriptionPoller poller,
    required ManifestSubscriptionRepository subscriptions,
  }) : _pollAllDue = poller.pollAllDue,
       _activePollIntervals = (() async {
         // `listActiveDue` returns due-now subs only; for cadence computation
         // we want every active sub regardless of its `nextPollAt`. The repo
         // helper `listAllActive` exposes that.
         final all = await subscriptions.listAllActive();
         return all.map((s) => s.pollIntervalSeconds).toList();
       });

  /// Test seam — bypasses the real `SubscriptionPoller` /
  /// `ManifestSubscriptionRepository` so unit tests can drive the scheduler
  /// without standing up the full DB-backed pipeline.
  @visibleForTesting
  SubscriptionPollerScheduler.forTest({
    required Future<int> Function(DateTime now) pollAllDue,
    required Future<List<int>> Function() activePollIntervals,
  }) : _pollAllDue = pollAllDue,
       _activePollIntervals = activePollIntervals;

  final Future<int> Function(DateTime now) _pollAllDue;
  final Future<List<int>> Function() _activePollIntervals;
  final _log = LoggerService.forClass(SubscriptionPollerScheduler);
  Timer? _timer;
  Timer? _warmupTimer;

  /// Sleep [warmup] (30 s by default) so first-frame work isn't blocked by
  /// the network, then run a cycle and schedule the next periodic one.
  ///
  /// The warm-up [Timer] is tracked so [dispose] can cancel it before it
  /// fires, preventing leaked callbacks during hot-restart, test teardown,
  /// or provider disposal. Calling [startAfterWarmup] more than once
  /// without disposing in between is a no-op (the existing warm-up
  /// continues).
  Future<void> startAfterWarmup({
    Duration warmup = const Duration(seconds: 30),
  }) async {
    if (_warmupTimer != null) return;
    _warmupTimer = Timer(warmup, () async {
      _warmupTimer = null;
      await pollNow();
      await _scheduleNext();
    });
  }

  // coverage:ignore-start
  // Periodic scheduling is an integration concern; unit-tested via
  // `pollNow()` and `computeInterval()`. Driving real `Timer`s through
  // `package:fake_async` would only re-verify SDK semantics, not anything
  // specific to this class.
  Future<void> _scheduleNext() async {
    final intervals = await _activePollIntervals();
    final next = computeInterval(intervals);
    _timer?.cancel();
    _timer = Timer(next, () async {
      try {
        await _pollAllDue(DateTime.now().toUtc());
      } catch (e, st) {
        _log.error('Periodic poll cycle failed', error: e, stackTrace: st);
      }
      await _scheduleNext();
    });
  }
  // coverage:ignore-end

  /// Cancel the outstanding warm-up + periodic timers. Called from
  /// `ref.onDispose(scheduler.dispose)` in [Provider] registration.
  /// The warm-up timer is cancelled first so its callback (which would
  /// schedule the periodic timer) cannot run after disposal.
  void dispose() {
    _warmupTimer?.cancel();
    _warmupTimer = null;
    _timer?.cancel();
    _timer = null;
  }

  /// Run one cycle now. Returns the number of subscriptions the cycle
  /// touched (success + 304 + failure all counted), straight from the
  /// underlying [SubscriptionPoller.pollAllDue].
  Future<int> pollNow() async => _pollAllDue(DateTime.now().toUtc());

  /// Cadence rule: smallest of `min(pollIntervalSeconds) / 4` and 1 hour,
  /// floored at 30 s to avoid runaway loops on misconfigured feeds.
  ///
  /// Different subscriptions can have different intervals; this picks the
  /// most-frequent rate that satisfies all of them. The poller's own
  /// `due-only` filter (`nextPollAt <= now`) decides which subs actually
  /// run on each tick.
  static Duration computeInterval(List<int> pollIntervalSeconds) {
    if (pollIntervalSeconds.isEmpty) return const Duration(hours: 1);
    final smallest = pollIntervalSeconds.reduce((a, b) => a < b ? a : b);
    final quarter = Duration(seconds: smallest ~/ 4);
    final result = quarter < const Duration(hours: 1)
        ? quarter
        : const Duration(hours: 1);
    return result < const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : result;
  }
}
