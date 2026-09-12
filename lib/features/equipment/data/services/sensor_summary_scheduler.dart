import 'package:flutter/foundation.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_findings_pass.dart';

/// Fire-and-forget entry point for the hooks that change a dive's profile
/// or tanks: downloads, re-parses, saves, splits and consolidations.
/// Serialises work (single-flight) and merges bursts of requests, like
/// `QualityScanScheduler`, which it is called beside. Every batch ends
/// with a findings pass over the active diver's gear, so a downloaded
/// dive reaches its condition findings without a page visit.
///
/// Check-in and incident writes queue a findings pass over just the gear
/// they name ([scheduleFindings]), as the spec asks: those findings are
/// stored and read without the engine (the statistics rankings), so they
/// have to move when the write happens, not when a page is next opened.
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

  /// Tests pin the diver, thresholds and master toggle the findings pass
  /// runs with; the default reads the active diver's settings.
  @visibleForTesting
  Future<ConditionPassInputs> Function() conditionInputsLoader =
      EquipmentFindingsPass.loadActiveDiverInputs;

  /// Widget tests run with the scheduler off; this lets them see which
  /// gear a write asked to refresh.
  @visibleForTesting
  void Function(Set<String> equipmentIds)? findingsRequestListener;

  /// Likewise for stale sweep requests (launch, restore, a synced pull).
  @visibleForTesting
  void Function()? staleSweepRequestListener;

  /// Likewise for summary requests, with whether each was forced.
  @visibleForTesting
  void Function(Set<String> diveIds, bool force)? summaryRequestListener;

  Future<void> _tail = Future.value();
  final Set<String> _pending = {};

  /// The subset of [_pending] to rebuild even when the stored row looks
  /// current (see [schedule]).
  final Set<String> _forced = {};
  final Set<String> _pendingFindings = {};
  bool _allFindingsPending = false;
  bool _staleSweepPending = false;

  /// Dives a findings pass asked a summary for that has not been built yet
  /// (see [_requestMissingSummaries]).
  final Set<String> _summariesRequestedByFindings = {};

  @visibleForTesting
  Future<void> get idle => _tail;

  /// Refreshes [diveIds] whose row is missing or stale. With [force], it
  /// rebuilds them even when the row looks current: a row is current while
  /// the dive's updated_at is unchanged, and a data-quality repair can
  /// rewrite a profile or pressure series (or undo one) without touching
  /// it.
  void schedule(Set<String> diveIds, {bool force = false}) {
    summaryRequestListener?.call(diveIds, force);
    if (!enabled || diveIds.isEmpty) return;
    _pending.addAll(diveIds);
    if (force) _forced.addAll(diveIds);
    _enqueue();
  }

  /// Refreshes every dive whose row is missing or stale: the startup
  /// backfill, the post-restore rebuild and the rebuild after a sync
  /// pulled dives in.
  void scheduleStaleSweep() {
    staleSweepRequestListener?.call();
    if (!enabled) return;
    _staleSweepPending = true;
    _enqueue();
  }

  /// Refreshes the condition findings of [equipmentIds] alone, merged
  /// into the next batch. A summary batch in the same run already visits
  /// all active gear, so these ride along with it.
  void scheduleFindings(Set<String> equipmentIds) {
    findingsRequestListener?.call(equipmentIds);
    if (!enabled || equipmentIds.isEmpty) return;
    _pendingFindings.addAll(equipmentIds);
    _enqueue();
  }

  /// Refreshes the condition findings of all active gear in the next
  /// batch: the hook for an import, whose check-ins arrive inside
  /// equipment items and name no single item to refresh.
  void scheduleAllFindings() {
    if (!enabled) return;
    _allFindingsPending = true;
    _enqueue();
  }

  void _enqueue() {
    // The queue is one chained future, so the callback must always
    // complete normally: an error escaping it leaves _tail completed with
    // that error, and every later schedule chains onto a failed future and
    // silently never runs. The inner catches keep their own wording; this
    // outer one is the backstop that holds however the body changes.
    _tail = _tail.then((_) async {
      final findingsOnly = Set.of(_pendingFindings);
      _pendingFindings.clear();
      final allFindings = _allFindingsPending;
      _allFindingsPending = false;
      var summaryBatch = false;
      try {
        final ids = Set.of(_pending);
        _pending.clear();
        final forced = Set.of(_forced);
        _forced.clear();
        final sweep = _staleSweepPending;
        _staleSweepPending = false;
        if (ids.isEmpty && !sweep) {
          if (allFindings) {
            await _refreshFindings();
          } else if (findingsOnly.isNotEmpty) {
            await _refreshFindings(only: findingsOnly);
          }
          return;
        }
        summaryBatch = true;
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
            await repo.ensureCurrent(id, force: forced.contains(id));
            // Built: a later findings pass may ask for it again if it goes
            // stale.
            _summariesRequestedByFindings.remove(id);
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
      if (summaryBatch) await _refreshFindings();
    });
  }

  /// A findings pass that met exposed dives with no current sensor summary
  /// asks for them here, since a pass run off any item page (a check-in, an
  /// incident, an import) has no provider to do it. Without this the item
  /// kept its non-sensor findings and no review marker until a page visit
  /// or a later sweep. Each dive is asked for once until its summary is
  /// built: every summary batch ends with a findings pass, so a summary
  /// that cannot be built would otherwise be requested after every batch,
  /// without end.
  void _requestMissingSummaries(Set<String> diveIds) {
    final fresh = diveIds.difference(_summariesRequestedByFindings);
    if (fresh.isEmpty) return;
    _summariesRequestedByFindings.addAll(fresh);
    schedule(fresh);
  }

  /// Runs the engine through the review marker over active gear, or over
  /// [only] when given. The pass swallows per-item failures; this guards
  /// the settings read and the gear query so a broken batch never poisons
  /// the queue.
  Future<void> _refreshFindings({Set<String>? only}) async {
    try {
      final inputs = await conditionInputsLoader();
      if (!inputs.engineEnabled) return;
      final pass = EquipmentFindingsPass(
        requestSummaries: _requestMissingSummaries,
      );
      await pass.run(
        items: only == null
            ? await pass.activeItems(diverId: inputs.diverId)
            : await pass.itemsById(only, diverId: inputs.diverId),
        thresholds: inputs.thresholds,
      );
    } catch (e, st) {
      _log.error('Scheduled findings pass failed', error: e, stackTrace: st);
    }
  }
}

void scheduleSensorSummaryRefresh(
  Iterable<String> diveIds, {
  bool force = false,
}) => SensorSummaryScheduler.instance.schedule(diveIds.toSet(), force: force);

/// The hook for an import: every active item's findings are refreshed.
void scheduleAllConditionFindingsRefresh() =>
    SensorSummaryScheduler.instance.scheduleAllFindings();

/// The hook for writes that change an item's check-ins or incidents.
void scheduleConditionFindingsRefresh(Iterable<String> equipmentIds) =>
    SensorSummaryScheduler.instance.scheduleFindings(equipmentIds.toSet());
