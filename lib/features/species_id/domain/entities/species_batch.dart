import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/dive_species_run_state.dart';

/// One dive of a run over many (issue #5127): its photos and videos, and
/// how many of them the run will look at with the installed model.
class PlannedDive extends Equatable {
  const PlannedDive({
    required this.diveId,
    required this.items,
    required this.toLookAt,
  });

  final String diveId;

  /// Photos and videos of the dive, what its progress counts through.
  final int items;

  /// Those not looked at with the installed model yet.
  final int toLookAt;

  @override
  List<Object?> get props => [diveId, items, toLookAt];
}

/// What a run over many dives will do, counted before it starts.
class SpeciesBatchPlan extends Equatable {
  const SpeciesBatchPlan({
    this.dives = const [],
    this.notOnDevice = 0,
    this.divesAsked = 0,
  });

  /// The dives with something to do, in the order they run.
  final List<PlannedDive> dives;

  /// Of the items to look at, those whose original is not on this device.
  final int notOnDevice;

  /// Dives asked about, for the counting progress.
  final int divesAsked;

  int get toLookAt => dives.fold(0, (sum, d) => sum + d.toLookAt);
  int get items => dives.fold(0, (sum, d) => sum + d.items);
  bool get isEmpty => dives.isEmpty;

  @override
  List<Object?> get props => [dives, notOnDevice, divesAsked];
}

/// Where a run over many dives stands.
enum SpeciesBatchPhase { running, finished, cancelled }

/// A run over many dives (issue #5127). The dive in progress has its own
/// state in the dive's run; this holds what the finished dives came to.
class SpeciesBatchRunState extends Equatable {
  const SpeciesBatchRunState({
    this.phase = SpeciesBatchPhase.running,
    required this.diveCount,
    this.divesDone = 0,
    required this.itemsPlanned,
    this.itemsDone = 0,
    this.currentDiveId,
    this.currentPlanned = 0,
    this.summary = const DiveRunSummary(),
  });

  final SpeciesBatchPhase phase;
  final int diveCount;
  final int divesDone;

  /// Photos and videos of the planned dives, less what finished dives left
  /// out (not on this device), so the bar never runs past its end.
  final int itemsPlanned;

  /// Photos and videos of the finished dives.
  final int itemsDone;

  /// The dive in progress, and how many items its plan counted.
  final String? currentDiveId;
  final int currentPlanned;

  /// What the finished dives came to, added up.
  final DiveRunSummary summary;

  bool get isActive => phase == SpeciesBatchPhase.running;

  SpeciesBatchRunState copyWith({
    SpeciesBatchPhase? phase,
    int? divesDone,
    int? itemsPlanned,
    int? itemsDone,
    String? Function()? currentDiveId,
    int? currentPlanned,
    DiveRunSummary? summary,
  }) => SpeciesBatchRunState(
    phase: phase ?? this.phase,
    diveCount: diveCount,
    divesDone: divesDone ?? this.divesDone,
    itemsPlanned: itemsPlanned ?? this.itemsPlanned,
    itemsDone: itemsDone ?? this.itemsDone,
    currentDiveId: currentDiveId == null ? this.currentDiveId : currentDiveId(),
    currentPlanned: currentPlanned ?? this.currentPlanned,
    summary: summary ?? this.summary,
  );

  @override
  List<Object?> get props => [
    phase,
    diveCount,
    divesDone,
    itemsPlanned,
    itemsDone,
    currentDiveId,
    currentPlanned,
    summary,
  ];
}

/// The progress line of a run over many dives: the batch's state with the
/// dive in progress folded in.
class SpeciesBatchProgress extends Equatable {
  const SpeciesBatchProgress({
    required this.diveNumber,
    required this.diveCount,
    required this.itemsDone,
    required this.itemsTotal,
    this.pauseReason,
    this.paused = false,
  });

  /// The dive in progress, counted from 1, or the dives done when between.
  final int diveNumber;
  final int diveCount;
  final int itemsDone;
  final int itemsTotal;
  final bool paused;
  final DiveRunPause? pauseReason;

  /// Between 0 and 1.
  double get fraction =>
      itemsTotal == 0 ? 0 : (itemsDone / itemsTotal).clamp(0.0, 1.0);

  /// Folds the dive in progress ([current]) into [batch].
  factory SpeciesBatchProgress.of(
    SpeciesBatchRunState batch,
    DiveSpeciesRunState? current,
  ) {
    final running = current != null && batch.currentDiveId != null;
    // The dive's own total replaces what its plan counted once known: it
    // leaves out what is not on this device.
    final known = running && current.phase != DiveRunPhase.waiting;
    final total =
        batch.itemsPlanned - (known ? batch.currentPlanned - current.total : 0);
    final done = batch.itemsDone + (known ? current.done : 0);
    return SpeciesBatchProgress(
      diveNumber: batch.currentDiveId == null
          ? batch.divesDone
          : batch.divesDone + 1,
      diveCount: batch.diveCount,
      itemsDone: done,
      itemsTotal: total < done ? done : total,
      paused: running && current.phase == DiveRunPhase.paused,
      pauseReason: running ? current.pauseReason : null,
    );
  }

  @override
  List<Object?> get props => [
    diveNumber,
    diveCount,
    itemsDone,
    itemsTotal,
    paused,
    pauseReason,
  ];
}

/// Adds [b] to [a], for the batch's summary.
DiveRunSummary addSummaries(DiveRunSummary a, DiveRunSummary b) =>
    DiveRunSummary(
      photos: a.photos + b.photos,
      videos: a.videos + b.videos,
      speciesTagged: a.speciesTagged + b.speciesTagged,
      unreadable: a.unreadable + b.unreadable,
      notOnDevice: a.notOnDevice + b.notOnDevice,
    );
