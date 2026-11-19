import 'package:equatable/equatable.dart';

/// A media item a run looked at, for applying confident matches together.
typedef RunAppliedItem = ({String mediaId, bool isVideo});

/// Where a Find species run for one dive stands (issue #4727).
enum DiveRunPhase { waiting, running, paused, finished, cancelled }

/// Why a run is paused.
enum DiveRunPause {
  /// The app went to the background; it carries on when the app is back.
  background,

  /// The device is too warm; it carries on when the diver says so.
  tooHot,
}

/// What a run came to, for the line the dive's card shows.
class DiveRunSummary extends Equatable {
  const DiveRunSummary({
    this.photos = 0,
    this.videos = 0,
    this.speciesTagged = 0,
    this.unreadable = 0,
  });

  /// Photos and videos looked at.
  final int photos;
  final int videos;

  /// Species the app tagged on its own.
  final int speciesTagged;

  /// Items that could not be opened or downloaded.
  final int unreadable;

  DiveRunSummary copyWith({
    int? photos,
    int? videos,
    int? speciesTagged,
    int? unreadable,
  }) => DiveRunSummary(
    photos: photos ?? this.photos,
    videos: videos ?? this.videos,
    speciesTagged: speciesTagged ?? this.speciesTagged,
    unreadable: unreadable ?? this.unreadable,
  );

  @override
  List<Object?> get props => [photos, videos, speciesTagged, unreadable];
}

/// One dive's run.
class DiveSpeciesRunState extends Equatable {
  const DiveSpeciesRunState({
    required this.diveId,
    this.phase = DiveRunPhase.waiting,
    this.pauseReason,
    this.total = 0,
    this.done = 0,
    this.summary = const DiveRunSummary(),
  });

  final String diveId;
  final DiveRunPhase phase;
  final DiveRunPause? pauseReason;

  /// Items in the run, and items finished.
  final int total;
  final int done;
  final DiveRunSummary summary;

  bool get isActive =>
      phase == DiveRunPhase.waiting ||
      phase == DiveRunPhase.running ||
      phase == DiveRunPhase.paused;

  DiveSpeciesRunState copyWith({
    DiveRunPhase? phase,
    DiveRunPause? Function()? pauseReason,
    int? total,
    int? done,
    DiveRunSummary? summary,
  }) => DiveSpeciesRunState(
    diveId: diveId,
    phase: phase ?? this.phase,
    pauseReason: pauseReason == null ? this.pauseReason : pauseReason(),
    total: total ?? this.total,
    done: done ?? this.done,
    summary: summary ?? this.summary,
  );

  @override
  List<Object?> get props => [diveId, phase, pauseReason, total, done, summary];
}
