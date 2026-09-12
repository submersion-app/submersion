import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Everything the scrubber margin needs, gathered as of the trip start so
/// a past trip shows the estimate the diver had when they left.
class ScrubberMarginInputs extends Equatable {
  final EquipmentItem item;

  /// `scrubber_duration_h` times 60, else the scrubber-repack schedule's
  /// hours interval times 60, else null (no rating known).
  final double? ratedMinutes;

  /// Loop minutes since [consumedSince], else since the unit's purchase
  /// or creation date as the clocks engine anchors it (or ever), CCR and
  /// SCR dives before the trip start only.
  final double consumedMinutes;

  /// Where [consumedMinutes] starts: the newest scrubber-repack record on
  /// or before the trip start, else the repack clock's anchor date when it
  /// is. Null when neither is known and every loop dive counts.
  final DateTime? consumedSince;

  /// `Trip.expectedDives`.
  final int? expectedDivesOverride;

  /// Itinerary dive days, else the trip's calendar days.
  final int itineraryDiveDays;

  /// One figure per recent trip with dives, newest first (up to three).
  final List<double> divesPerDiveDayHistory;

  /// `Trip.expectedRuntimeMinutes`.
  final int? runtimeMinutesOverride;

  /// Summary scrubber minutes of recent rebreather (CCR or SCR) dives that carry one.
  final List<double> scrubberMinutesHistory;

  /// Runtime minutes of recent rebreather (CCR or SCR) dives, the fallback when no dive
  /// carries a scrubber figure.
  final List<double> rebreatherRuntimeMinutesHistory;

  const ScrubberMarginInputs({
    required this.item,
    required this.ratedMinutes,
    required this.consumedMinutes,
    this.consumedSince,
    this.expectedDivesOverride,
    required this.itineraryDiveDays,
    required this.divesPerDiveDayHistory,
    this.runtimeMinutesOverride,
    required this.scrubberMinutesHistory,
    required this.rebreatherRuntimeMinutesHistory,
  });

  @override
  List<Object?> get props => [
    item.id,
    ratedMinutes,
    consumedMinutes,
    consumedSince,
    expectedDivesOverride,
    itineraryDiveDays,
    divesPerDiveDayHistory,
    runtimeMinutesOverride,
    scrubberMinutesHistory,
    rebreatherRuntimeMinutesHistory,
  ];
}

/// The four figures the card states, each with the n behind it when it
/// was estimated (0 for an override). No date, no remaining life.
class ScrubberMargin extends Equatable {
  final EquipmentItem item;
  final double? ratedMinutes;
  final double consumedMinutes;

  /// See [ScrubberMarginInputs.consumedSince]; null means no repack is
  /// known, and the card says so rather than "since the last repack".
  final DateTime? consumedSince;

  /// Rated minus consumed, floored at zero; zero when there is no rating.
  final double remainingBefore;
  final int expectedDives;
  final int expectedDivesN;

  /// Whether the diver set this figure on the trip. An n of zero alone
  /// cannot say: a default with no history to average has no n either,
  /// and calling that an override would credit the diver with a number
  /// they never entered.
  final bool divesFromOverride;
  final double minutesPerDive;
  final int minutesPerDiveN;
  final bool minutesFromOverride;
  final double expectedUse;

  /// Remaining minus expected use; null when there is no rating.
  final double? marginAfter;

  /// Margin under 20 percent of the rated duration, or negative.
  final bool caution;

  const ScrubberMargin({
    required this.item,
    required this.ratedMinutes,
    required this.consumedMinutes,
    this.consumedSince,
    required this.remainingBefore,
    required this.expectedDives,
    required this.expectedDivesN,
    this.divesFromOverride = false,
    required this.minutesPerDive,
    required this.minutesPerDiveN,
    this.minutesFromOverride = false,
    required this.expectedUse,
    required this.marginAfter,
    required this.caution,
  });

  @override
  List<Object?> get props => [
    item.id,
    ratedMinutes,
    consumedMinutes,
    consumedSince,
    remainingBefore,
    expectedDives,
    expectedDivesN,
    divesFromOverride,
    minutesPerDive,
    minutesPerDiveN,
    minutesFromOverride,
    expectedUse,
    marginAfter,
    caution,
  ];
}
