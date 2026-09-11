import 'package:flutter/foundation.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';

/// Fire-and-forget entry point for the hooks that change a dive's profile
/// or tanks: downloads, re-parses, saves, splits and consolidations.
/// Serialises work (single-flight) and merges bursts of requests, like
/// `QualityScanScheduler`, which it is called beside.
class SensorSummaryScheduler {
  SensorSummaryScheduler._();
  static final SensorSummaryScheduler instance = SensorSummaryScheduler._();

  /// Widget tests that drive save flows against a fake-async zone set this
  /// to false (flutter_test_config does) to keep Drift work out of the zone.
  static bool enabled = true;

  static const _log = LoggerService('SensorSummaryScheduler');

  static DiveSensorSummaryRepository defaultRepositoryFactory() =>
      DiveSensorSummaryRepository();

  /// Tests substitute a repository bound to their in-memory database.
  @visibleForTesting
  DiveSensorSummaryRepository Function() repositoryFactory =
      defaultRepositoryFactory;

  Future<void> _tail = Future.value();
  final Set<String> _pending = {};
  bool _staleSweepPending = false;

  @visibleForTesting
  Future<void> get idle => _tail;

  /// Refreshes [diveIds] whose row is missing or stale.
  void schedule(Set<String> diveIds) {
    if (!enabled || diveIds.isEmpty) return;
    _pending.addAll(diveIds);
    _enqueue();
  }

  /// Refreshes every dive whose row is missing or stale: the startup
  /// backfill and the post-restore rebuild.
  void scheduleStaleSweep() {
    if (!enabled) return;
    _staleSweepPending = true;
    _enqueue();
  }

  void _enqueue() {
    // The queue is one chained future, so the callback must always
    // complete normally: an error escaping it leaves _tail completed with
    // that error, and every later schedule chains onto a failed future and
    // silently never runs. The inner catches keep their own wording; this
    // outer one is the backstop that holds however the body changes.
    _tail = _tail.then((_) async {
      try {
        final ids = Set.of(_pending);
        _pending.clear();
        final sweep = _staleSweepPending;
        _staleSweepPending = false;
        if (ids.isEmpty && !sweep) return;
        final repo = repositoryFactory();
        if (sweep) {
          try {
            ids.addAll(await repo.staleDiveIds());
          } catch (e, st) {
            _log.error(
              'Stale sensor summary query failed',
              error: e,
              stackTrace: st,
            );
          }
        }
        for (final id in ids) {
          try {
            await repo.ensureCurrent(id);
          } catch (e, st) {
            _log.error(
              'Scheduled sensor summary failed for $id',
              error: e,
              stackTrace: st,
            );
          }
        }
      } catch (e, st) {
        _log.error(
          'Scheduled sensor summary batch failed',
          error: e,
          stackTrace: st,
        );
      }
    });
  }
}

void scheduleSensorSummaryRefresh(Iterable<String> diveIds) =>
    SensorSummaryScheduler.instance.schedule(diveIds.toSet());
