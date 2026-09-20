import 'package:flutter/foundation.dart';

import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';

/// Keeps the phase 2 derived metrics current without blocking a write.
///
/// Modelled on SensorSummaryScheduler and called beside it: one singleton,
/// one serialised tail, bursts merged into a single drain, every entry point
/// fire and forget. The two stay separate because their engines version
/// independently, so a bump to one must not rebuild the other's rows.
class DerivedMetricsScheduler {
  DerivedMetricsScheduler._();

  static final DerivedMetricsScheduler instance = DerivedMetricsScheduler._();

  /// Widget tests that drive save flows against a fake-async zone set this
  /// to false (flutter_test_config does) to keep isolate work out of them.
  static bool enabled = true;

  static DerivedMetricsRepository defaultRepositoryFactory() =>
      DerivedMetricsRepository();

  /// Tests substitute a repository bound to their in-memory database.
  @visibleForTesting
  DerivedMetricsRepository Function() repositoryFactory =
      defaultRepositoryFactory;

  /// Fires with the ids a caller asked for, BEFORE the [enabled] guard, so a
  /// widget test running with the scheduler off can still assert which dives
  /// a write asked to refresh. A sweep reports an empty set.
  @visibleForTesting
  void Function(Set<String> diveIds, bool force)? requestListener;

  Future<void> _tail = Future.value();
  final Set<String> _pending = {};

  /// The subset of [_pending] to rebuild even when the stored row looks
  /// current (see [schedule]).
  final Set<String> _forced = {};
  bool _sweepPending = false;
  String? _sweepDiverId;

  /// Awaited by tests; resolves when the queue has drained.
  @visibleForTesting
  Future<void> get idle => _tail;

  /// Queues a refresh for [diveIds].
  ///
  /// [force] rebuilds rows that look current, for a repair that rewrote a
  /// profile without touching the dive's `updated_at`.
  void schedule(Set<String> diveIds, {bool force = false}) {
    requestListener?.call(diveIds, force);
    if (!enabled || diveIds.isEmpty) return;
    _pending.addAll(diveIds);
    if (force) _forced.addAll(diveIds);
    _enqueue();
  }

  /// Queues a pass over every dive whose row is missing or stale: launch,
  /// restore, and a synced pull.
  void scheduleStaleSweep({String? diverId}) {
    requestListener?.call(const {}, false);
    if (!enabled) return;
    _sweepPending = true;
    _sweepDiverId = diverId;
    _enqueue();
  }

  void _enqueue() {
    // The callback must ALWAYS complete normally. An error escaping it
    // leaves _tail completed with that error, and every later schedule
    // chains onto a failed future and silently never runs again.
    _tail = _tail.then((_) async {
      try {
        final repo = repositoryFactory();

        if (_sweepPending) {
          _sweepPending = false;
          final diverId = _sweepDiverId;
          _sweepDiverId = null;
          try {
            _pending.addAll(await repo.staleDiveIds(diverId: diverId));
          } catch (_) {
            // A failed sweep must not stop the per-dive refreshes already
            // queued beside it.
          }
        }

        final ids = _pending.toList();
        final forced = {..._forced};
        _pending.clear();
        _forced.clear();

        for (final id in ids) {
          try {
            await repo.ensureCurrent(id, force: forced.contains(id));
          } catch (_) {
            // One unreadable dive must not strand the rest of the batch.
          }
        }
      } catch (_) {
        // Nothing here may escape; see the comment above.
      }
    });
  }
}

/// The hook a write calls. Free function so call sites do not import the
/// singleton, and iterable-taking so they can pass a list literal, matching
/// `scheduleSensorSummaryRefresh` beside it.
void scheduleDerivedMetricsRefresh(
  Iterable<String> diveIds, {
  bool force = false,
}) => DerivedMetricsScheduler.instance.schedule(diveIds.toSet(), force: force);
