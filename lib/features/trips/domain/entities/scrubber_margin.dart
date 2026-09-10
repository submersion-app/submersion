import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Everything the scrubber margin needs, gathered as of the trip start so
/// a past trip shows the estimate the diver had when they left.
class ScrubberMarginInputs extends Equatable {
  final EquipmentItem item;

  /// `scrubber_duration_h` times 60, else the scrubber-repack schedule's
  /// hours interval times 60, else null (no rating known).
  final double? ratedMinutes;

  /// Loop minutes since the newest scrubber-repack record (or ever), CCR
  /// and SCR dives before the trip start only.
  final double consumedMinutes;

  /// `Trip.expectedDives`.
  final int? expectedDivesOverride;

  /// Itinerary dive days, else the trip's calendar days.
  final int itineraryDiveDays;

  /// One figure per recent trip with dives, newest first (up to three).
  final List<double> divesPerDiveDayHistory;

  /// `Trip.expectedRuntimeMinutes`.
  final int? runtimeMinutesOverride;

  /// Summary scrubber minutes of recent CCR dives that carry one.
  final List<double> scrubberMinutesHistory;

  /// Runtime minutes of recent CCR dives, the fallback when no dive
  /// carries a scrubber figure.
  final List<double> ccrRuntimeMinutesHistory;

  const ScrubberMarginInputs({
    required this.item,
    required this.ratedMinutes,
    required this.consumedMinutes,
    this.expectedDivesOverride,
    required this.itineraryDiveDays,
    required this.divesPerDiveDayHistory,
    this.runtimeMinutesOverride,
    required this.scrubberMinutesHistory,
    required this.ccrRuntimeMinutesHistory,
  });

  @override
  List<Object?> get props => [
    item.id,
    ratedMinutes,
    consumedMinutes,
    expectedDivesOverride,
    itineraryDiveDays,
    divesPerDiveDayHistory,
    runtimeMinutesOverride,
    scrubberMinutesHistory,
    ccrRuntimeMinutesHistory,
  ];
}

/// The four figures the card states, each with the n behind it when it
/// was estimated (0 for an override). No date, no remaining life.
class ScrubberMargin extends Equatable {
  final EquipmentItem item;
  final double? ratedMinutes;
  final double consumedMinutes;

  /// Rated minus consumed, floored at zero; zero when there is no rating.
  final double remainingBefore;
  final int expectedDives;
  final int expectedDivesN;
  final double minutesPerDive;
  final int minutesPerDiveN;
  final double expectedUse;

  /// Remaining minus expected use; null when there is no rating.
  final double? marginAfter;

  /// Margin under 20 percent of the rated duration, or negative.
  final bool caution;

  const ScrubberMargin({
    required this.item,
    required this.ratedMinutes,
    required this.consumedMinutes,
    required this.remainingBefore,
    required this.expectedDives,
    required this.expectedDivesN,
    required this.minutesPerDive,
    required this.minutesPerDiveN,
    required this.expectedUse,
    required this.marginAfter,
    required this.caution,
  });

  @override
  List<Object?> get props => [
    item.id,
    ratedMinutes,
    consumedMinutes,
    remainingBefore,
    expectedDives,
    expectedDivesN,
    minutesPerDive,
    minutesPerDiveN,
    expectedUse,
    marginAfter,
    caution,
  ];
}
