import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/services/scrubber_margin_service.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';

/// One remaining trip day: its date (local midnight), the dives planned on
/// it, and whether an itinerary day set that number.
class FillForecastDay extends Equatable {
  const FillForecastDay({
    required this.date,
    required this.plannedDives,
    this.isOverride = false,
  });

  final DateTime date;
  final int plannedDives;
  final bool isOverride;

  @override
  List<Object?> get props => [date, plannedDives, isOverride];
}

/// Everything the forecast reads. Nothing here is stored by the forecast.
class FillForecastInputs {
  const FillForecastInputs({
    required this.now,
    required this.tripStart,
    required this.tripEnd,
    required this.slotCount,
    required this.fullCount,
    required this.partialCount,
    this.itinerary = const [],
    this.divesPerDayTarget,
    this.expectedDives,
    this.divesPerDiveDayHistory = const [],
    this.diversSharing = 1,
    this.divesLoggedToday = 0,
    this.fillOpensAt,
    this.fillClosesAt,
  });

  /// The device's local time; its calendar date is "today".
  final DateTime now;
  final DateTime tripStart;
  final DateTime tripEnd;
  final int slotCount;
  final int fullCount;
  final int partialCount;
  final List<ItineraryDay> itinerary;
  final int? divesPerDayTarget;
  final int? expectedDives;
  final List<double> divesPerDiveDayHistory;
  final int diversSharing;
  final int divesLoggedToday;

  /// The fill station's hours, minutes after local midnight.
  final int? fillOpensAt;
  final int? fillClosesAt;
}

/// The forecast's answer. Demand and supply count cylinders.
class FillForecast extends Equatable {
  const FillForecast({
    required this.fullCount,
    required this.partialCount,
    required this.todayDemand,
    required this.tomorrowDemand,
    required this.tomorrowSupply,
    required this.todayShortfall,
    required this.tomorrowShortfall,
    required this.deadlineMinutes,
    required this.remainingDemand,
    required this.days,
  });

  final int fullCount;
  final int partialCount;

  /// Cylinders today's remaining dives need.
  final int todayDemand;
  final int tomorrowDemand;

  /// Full cylinders left for tomorrow once today's remaining dives have
  /// used theirs (decided 2026-09-29).
  final int tomorrowSupply;
  final int todayShortfall;
  final int tomorrowShortfall;

  /// Today's closing time at the fill station, minutes after local
  /// midnight, while it is still ahead; else null.
  final int? deadlineMinutes;

  /// Cylinders the rest of the trip needs, today's remaining dives included.
  final int remainingDemand;

  /// Today (or the trip's first day, before it starts) through its last.
  final List<FillForecastDay> days;

  /// Today's remaining dives already need more than the full cylinders.
  bool get caution => todayShortfall > 0;

  /// Tomorrow needs more than today will leave.
  bool get fillRunNeeded => tomorrowShortfall > 0;

  bool get isShort => caution || fillRunNeeded;

  @override
  List<Object?> get props => [
    fullCount,
    partialCount,
    todayDemand,
    tomorrowDemand,
    tomorrowSupply,
    todayShortfall,
    tomorrowShortfall,
    deadlineMinutes,
    remainingDemand,
    days,
  ];
}

/// Pure. The trip's fill forecast (spec "Phase 2 forecasting"), or null
/// for a trip that has ended or has no slots.
///
/// A day's demand is its planned dives times the divers sharing. Today's
/// planned dives drop by the dives already logged, floored at zero, before
/// that multiplication. Supply is the full slots; partial ones are reported,
/// never counted. Tomorrow's supply is what today's remaining dives leave.
FillForecast? computeFillForecast(FillForecastInputs inputs) {
  final today = tripDay(inputs.now);
  final start = tripDay(inputs.tripStart);
  final end = tripDay(inputs.tripEnd);
  if (inputs.slotCount == 0 || end.isBefore(today)) return null;

  final byDay = itineraryByDay(inputs.itinerary);
  final perDiveDay = _perDiveDay(inputs, start, end);
  int plannedOn(DateTime day) {
    if (day.isBefore(start) || day.isAfter(end)) return 0;
    final row = byDay[day];
    final set = row?.plannedDives;
    if (set != null) return math.max(0, set);
    return isTripDiveDay(row) ? perDiveDay : 0;
  }

  final divers = math.max(1, inputs.diversSharing);
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  final todayDives = math.max(0, plannedOn(today) - inputs.divesLoggedToday);
  final todayDemand = todayDives * divers;
  final tomorrowDemand = plannedOn(tomorrow) * divers;
  final tomorrowSupply = math.max(0, inputs.fullCount - todayDemand);

  final first = today.isAfter(start) ? today : start;
  final days = [
    for (final day in tripDaysBetween(first, end))
      FillForecastDay(
        date: day,
        plannedDives: plannedOn(day),
        isOverride: byDay[day]?.plannedDives != null,
      ),
  ];
  final later = days
      .where((d) => d.date.isAfter(today))
      .fold(0, (sum, d) => sum + d.plannedDives * divers);

  final opens = inputs.fillOpensAt;
  final closes = inputs.fillClosesAt;
  final nowMinutes = inputs.now.hour * 60 + inputs.now.minute;
  final deadline =
      opens != null && closes != null && opens < closes && nowMinutes < closes
      ? closes
      : null;

  return FillForecast(
    fullCount: inputs.fullCount,
    partialCount: inputs.partialCount,
    todayDemand: todayDemand,
    tomorrowDemand: tomorrowDemand,
    tomorrowSupply: tomorrowSupply,
    todayShortfall: math.max(0, todayDemand - inputs.fullCount),
    tomorrowShortfall: math.max(0, tomorrowDemand - tomorrowSupply),
    deadlineMinutes: deadline,
    remainingDemand: todayDemand + later,
    days: days,
  );
}

/// Dives on an ordinary dive day, first match wins (the spec's order after
/// an itinerary day's own plan): the trip's target, the expected dives
/// spread over the trip's dive days, the median of recent trips, else the
/// default. A fraction rounds up (decided 2026-09-29): a bottle too many,
/// never one too few. A zero or negative number counts as unset.
int _perDiveDay(FillForecastInputs inputs, DateTime start, DateTime end) {
  final target = positiveOverride(inputs.divesPerDayTarget);
  if (target != null) return target;
  final expected = positiveOverride(inputs.expectedDives);
  if (expected != null) {
    final diveDays = tripDiveDayCount(
      start: start,
      end: end,
      itinerary: inputs.itinerary,
    );
    if (diveDays > 0) return (expected / diveDays).ceil();
  }
  return estimatedDivesPerDiveDay(inputs.divesPerDiveDayHistory).ceil();
}

/// Pure. When the forecast next changes by itself: at the fill deadline
/// while it is ahead, else at the next local midnight.
DateTime fillForecastNextRefresh(DateTime now, FillForecast forecast) {
  final today = tripDay(now);
  final deadline = forecast.deadlineMinutes;
  if (deadline != null) {
    final at = DateTime(
      today.year,
      today.month,
      today.day,
      deadline ~/ 60,
      deadline % 60,
    );
    if (at.isAfter(now)) return at;
  }
  return DateTime(today.year, today.month, today.day + 1);
}
