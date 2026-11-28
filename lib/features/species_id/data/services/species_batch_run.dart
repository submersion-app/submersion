import 'dart:async';
import 'dart:collection';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/services/dive_species_run.dart';
import 'package:submersion/features/species_id/domain/entities/species_batch.dart';

/// Find species over many dives (issue #5127): a selection, a trip or the
/// whole logbook.
///
/// It hands one dive at a time to the dives' own run ([DiveSpeciesRun]),
/// so that run's state never holds more than the dive in progress and a
/// dive the diver starts from its card meanwhile runs in its turn, ahead
/// of the batch's next. Every dive applies right after its run, as a card's
/// run does, but all under one History operation: one entry for the whole
/// batch, while each apply holds the change log only as long as one dive's.
///
/// Lives for the app session, like the dives' run.
class SpeciesBatchRun extends StateNotifier<SpeciesBatchRunState?> {
  SpeciesBatchRun({
    required DiveSpeciesRun Function() runs,
    required int Function() databaseGeneration,
    required Future<bool> Function(String operationId) isReverted,
    required String Function() newOperationId,
  }) : _runs = runs,
       _generation = databaseGeneration,
       _isReverted = isReverted,
       _newOperationId = newOperationId,
       super(null);

  final DiveSpeciesRun Function() _runs;
  final int Function() _generation;
  final Future<bool> Function(String operationId) _isReverted;
  final String Function() _newOperationId;

  final _log = LoggerService.forClass(SpeciesBatchRun);
  final _pending = Queue<PlannedDive>();
  final _pendingIds = <String>{};
  var _onDeviceOnly = false;
  var _cancelled = false;
  var _disposed = false;
  Future<void> _done = Future.value();

  /// The History operation the batch files under, chosen at its start.
  String _operationId = '';

  /// Whether the batch started the dive in progress itself, rather than
  /// waiting for a run the diver started from that dive's card.
  var _startedCurrent = false;

  /// Completes when the batch running now ends; at once with none.
  Future<void> get done => _done;

  /// Whether [diveId] waits its turn in the batch.
  bool isPending(String diveId) => _pendingIds.contains(diveId);

  /// Starts a batch over [plan]'s dives, in order. [onDeviceOnly] leaves
  /// out media whose original is not on this device. Refused (false) while
  /// another batch runs: its dives and its download choice stay as they
  /// were.
  bool start(SpeciesBatchPlan plan, {bool onDeviceOnly = false}) {
    if (_disposed || (state?.isActive ?? false)) return false;
    _pending
      ..clear()
      ..addAll(plan.dives);
    _pendingIds
      ..clear()
      ..addAll([for (final d in plan.dives) d.diveId]);
    _onDeviceOnly = onDeviceOnly;
    _cancelled = false;
    state = SpeciesBatchRunState(
      diveCount: plan.dives.length,
      itemsPlanned: plan.items,
    );
    _done = _drain(_generation());
    return true;
  }

  /// Stops after the item in progress; the dives not reached are dropped.
  /// What was tagged so far stays, in the batch's entry. A run the diver
  /// started from a dive's card is theirs: it is not stopped.
  void cancel() {
    if (!(state?.isActive ?? false)) return;
    _cancelled = true;
    _pending.clear();
    _pendingIds.clear();
    final current = state?.currentDiveId;
    if (current != null && _startedCurrent) _runs().cancel(current);
  }

  /// Carries on after the device cooled down or a background pause.
  void resume() {
    final current = state?.currentDiveId;
    if (current != null) _runs().resume(current);
  }

  @override
  void dispose() {
    _disposed = true;
    _pending.clear();
    _pendingIds.clear();
    super.dispose();
  }

  /// The operation to file a dive's tags under, asked right before they are
  /// applied: never one the diver has undone meanwhile.
  Future<String> _operationForApply() async {
    try {
      if (await _isReverted(_operationId)) _operationId = _newOperationId();
    } on Object catch (e) {
      _log.debug('Could not read whether the run was undone', error: e);
    }
    return _operationId;
  }

  Future<void> _drain(int generation) async {
    _operationId = _newOperationId();
    var stopped = false;
    while (_pending.isNotEmpty && !_cancelled && !_disposed) {
      if (_generation() != generation) {
        stopped = true;
        break;
      }
      final dive = _pending.removeFirst();
      _pendingIds.remove(dive.diveId);
      _set(
        state!.copyWith(
          currentDiveId: () => dive.diveId,
          currentPlanned: dive.items,
        ),
      );
      final runs = _runs();
      // A dive whose card run is queued or going keeps that run, which
      // applies by itself; it is waited for, never run twice, and its
      // result stays on the card.
      _startedCurrent = !runs.isQueuedOrRunning(dive.diveId);
      await runs.start(
        dive.diveId,
        onDeviceOnly: _onDeviceOnly,
        operationId: _operationForApply,
      );
      if (_disposed) return;
      final ended = runs.stateOf(dive.diveId);
      if (_startedCurrent) runs.forget(dive.diveId);
      _startedCurrent = false;
      final s = state!;
      final total = ended?.total ?? 0;
      _set(
        s.copyWith(
          divesDone: s.divesDone + 1,
          // What the dive left out no longer counts towards the end.
          itemsPlanned: s.itemsPlanned - dive.items + total,
          itemsDone: s.itemsDone + (ended?.done ?? 0),
          currentDiveId: () => null,
          currentPlanned: 0,
          summary: ended == null
              ? s.summary
              : addSummaries(s.summary, ended.summary),
        ),
      );
    }
    if (_generation() != generation) stopped = true;
    if (_disposed) return;
    _pending.clear();
    _pendingIds.clear();
    _set(
      state!.copyWith(
        phase: _cancelled || stopped
            ? SpeciesBatchPhase.cancelled
            : SpeciesBatchPhase.finished,
        currentDiveId: () => null,
      ),
    );
  }

  void _set(SpeciesBatchRunState s) {
    if (!_disposed) state = s;
  }
}
