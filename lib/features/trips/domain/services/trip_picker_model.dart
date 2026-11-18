import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/estimated_profile.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

/// One corner of a dive's shape in the trip day picker.
class TripPickerPoint extends Equatable {
  const TripPickerPoint(this.seconds, this.depth);

  /// Seconds from the start of the shape.
  final double seconds;

  /// Depth in meters.
  final double depth;

  @override
  List<Object?> get props => [seconds, depth];
}

/// One dive as the day picker draws it: its depth over time, hanging from
/// the surface.
class TripPickerDive extends Equatable {
  const TripPickerDive({
    required this.diveId,
    required this.points,
    required this.dashed,
  });

  final String diveId;

  /// At least two points, the first at zero seconds.
  final List<TripPickerPoint> points;

  /// Drawn as a dashed outline with no fill: an estimate standing in for a
  /// profile that was not recorded, or a dive that has not happened.
  final bool dashed;

  /// How long the shape runs, in seconds.
  double get spanSeconds => points.last.seconds;

  /// The shape's deepest point, in meters.
  double get maxDepth =>
      points.fold(0, (deepest, p) => math.max(deepest, p.depth));

  @override
  List<Object?> get props => [diveId, points, dashed];
}

/// One day's tile: its dives in the order they were dived.
class TripPickerDay extends Equatable {
  const TripPickerDay({required this.date, required this.dives});

  final DateTime date;
  final List<TripPickerDive> dives;

  /// The summed length of the day's shapes, in seconds.
  double get spanSeconds =>
      dives.fold(0, (total, dive) => total + dive.spanSeconds);

  @override
  List<Object?> get props => [date, dives];
}

/// What the whole day picker draws, with the two scales every tile shares so
/// that days can be compared: the trip's deepest shape and its busiest day.
class TripPickerModel extends Equatable {
  const TripPickerModel({
    required this.days,
    required this.maxDepth,
    required this.widestDaySeconds,
  });

  /// One entry per story day, in the story's order.
  final List<TripPickerDay> days;

  /// The deepest shape of the trip, in meters; 0 when nothing is drawn.
  final double maxDepth;

  /// The longest day's summed shapes, in seconds; 0 when nothing is drawn.
  final double widestDaySeconds;

  @override
  List<Object?> get props => [days, maxDepth, widestDaySeconds];
}

/// Builds the day picker's model for a trip story.
///
/// [profiles] is the app's shared mini-profile cache, and its three answers
/// per dive are honoured as the dive list honours them: a point list is the
/// recorded profile; an empty list means the dive has no samples, so its
/// estimate is drawn; no entry means not known yet or unreadable, so nothing
/// is drawn.
///
/// A dive that has not happened, a draft or one of [undivedPlanIds], is
/// dashed whatever profile is stored for it: a plan made in the planner is
/// saved with its planned profile, and would otherwise look like a logged
/// dive. `isPlanned` alone is not the test (issue #3924).
///
/// A null [undivedPlanIds] means that read has not answered. Until it does,
/// a dive marked planned draws nothing: it may have been dived or not, and a
/// solid shape that turns dashed a moment later says it happened first.
TripPickerModel buildTripPickerModel({
  required List<TripStoryDay> days,
  required Map<String, List<DiveProfilePoint>> profiles,
  required Set<String>? undivedPlanIds,
}) {
  final pickerDays = [
    for (final day in days)
      TripPickerDay(
        date: day.date,
        dives: [
          for (final dive in _inEntryOrder(day.dives))
            if (undivedPlanIds != null || !dive.isPlanned || dive.isDraft)
              ?_shapeFor(
                dive,
                profiles[dive.id],
                notHappened:
                    dive.isDraft ||
                    (undivedPlanIds?.contains(dive.id) ?? false),
              ),
        ],
      ),
  ];
  var maxDepth = 0.0;
  var widestDaySeconds = 0.0;
  for (final day in pickerDays) {
    widestDaySeconds = math.max(widestDaySeconds, day.spanSeconds);
    for (final dive in day.dives) {
      maxDepth = math.max(maxDepth, dive.maxDepth);
    }
  }
  return TripPickerModel(
    days: pickerDays,
    maxDepth: maxDepth,
    widestDaySeconds: widestDaySeconds,
  );
}

/// Keeps the last model built, and hands it back while what it was built
/// from has not changed.
///
/// The picker rebuilds whenever the selected day changes or its space does,
/// and the model walks every sample of every dive on the trip. Its inputs
/// change far less often than that.
class TripPickerModelMemo {
  List<TripStoryDay>? _days;
  List<List<DiveProfilePoint>?> _entries = const [];
  Set<String>? _undivedPlanIds;
  TripPickerModel? _model;

  static const _sameIds = SetEquality<String>();

  /// The same list, entry by entry: the cache keeps an untouched dive's list.
  static const _sameEntries = ListEquality<List<DiveProfilePoint>?>(
    IdentityEquality(),
  );

  /// [buildTripPickerModel] for these inputs, built only when they differ
  /// from the last call's.
  ///
  /// [days] is compared by identity: a story keeps its list. [profiles] is
  /// compared entry by entry for this trip's dives only, also by identity:
  /// the cache writes a new map each time a profile lands anywhere in the
  /// app, and keeps the list of every dive it did not touch.
  TripPickerModel resolve({
    required List<TripStoryDay> days,
    required Map<String, List<DiveProfilePoint>> profiles,
    required Set<String>? undivedPlanIds,
  }) {
    final entries = [
      for (final day in days)
        for (final dive in day.dives) profiles[dive.id],
    ];
    final cached = _model;
    if (cached != null &&
        identical(days, _days) &&
        _sameEntries.equals(entries, _entries) &&
        _sameIds.equals(undivedPlanIds, _undivedPlanIds)) {
      return cached;
    }
    _days = days;
    _entries = entries;
    _undivedPlanIds = undivedPlanIds;
    return _model = buildTripPickerModel(
      days: days,
      profiles: profiles,
      undivedPlanIds: undivedPlanIds,
    );
  }
}

List<Dive> _inEntryOrder(List<Dive> dives) =>
    [...dives]
      ..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime));

TripPickerDive? _shapeFor(
  Dive dive,
  List<DiveProfilePoint>? profile, {
  required bool notHappened,
}) {
  if (profile == null) return null;
  final List<TripPickerPoint> points;
  final bool dashed;
  if (profile.isNotEmpty) {
    final start = profile.first.timestamp;
    points = [
      for (final p in profile)
        TripPickerPoint((p.timestamp - start).toDouble(), p.depth),
    ];
    dashed = notHappened;
  } else {
    final estimate = EstimatedProfile.estimate(
      maxDepth: dive.maxDepth,
      runtime: dive.measuredRuntime,
      bottomTime: dive.bottomTime,
    );
    if (estimate == null) return null;
    points = [
      for (final p in estimate.points) TripPickerPoint(p.seconds, p.depth),
    ];
    dashed = true;
  }
  final shape = TripPickerDive(diveId: dive.id, points: points, dashed: dashed);
  // Nothing to draw: one sample, no time, or no depth.
  if (points.length < 2 || shape.spanSeconds <= 0 || shape.maxDepth <= 0) {
    return null;
  }
  return shape;
}
