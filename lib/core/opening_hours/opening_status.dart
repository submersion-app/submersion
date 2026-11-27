import 'package:equatable/equatable.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';

/// Whether a place is open at a moment, from its [OpeningHours].
///
/// Everything here reads wall-clock digits only: the caller turns "now" into
/// the place's own clock first (a dive site's from its GPS position), and the
/// times returned carry the same flavour (local or UTC-flagged) as the input.

/// How far ahead to look for the next opening: a whole year, so a season
/// that starts in eleven months is still found.
const int _lookAheadDays = 366;

/// After this many joined days of being open, the place does not close.
const int _neverClosesAfterDays = 8;

/// The schedule that applies on [date]: of those whose season contains it
/// (no season contains every date), the shortest season; ties go to the
/// schedule listed first. Null when none applies: closed for the season.
OpeningSchedule? scheduleOn(OpeningHours hours, DateTime date) {
  OpeningSchedule? best;
  var bestLength = 0;
  for (final schedule in hours.schedules) {
    final season = schedule.season;
    if (season != null && !season.contains(date)) continue;
    final length = season?.lengthInDays ?? 366;
    if (best == null || length < bestLength) {
      best = schedule;
      bestLength = length;
    }
  }
  return best;
}

sealed class OpeningStatus extends Equatable {
  const OpeningStatus();
}

/// Open now.
class OpenNow extends OpeningStatus {
  /// When it next closes; null when it does not (always open, or open
  /// around the clock for more than a week).
  final DateTime? closesAt;

  const OpenNow({required this.closesAt});

  @override
  List<Object?> get props => [closesAt];
}

/// Closed now.
class ClosedNow extends OpeningStatus {
  /// When it next opens within a year; null when it does not.
  final DateTime? nextOpen;

  /// Whether no schedule applies today at all (closed for the season).
  final bool outOfSeason;

  const ClosedNow({required this.nextOpen, required this.outOfSeason});

  @override
  List<Object?> get props => [nextOpen, outOfSeason];
}

/// The hours say nothing about when it opens (a note alone).
class OpeningUnknown extends OpeningStatus {
  const OpeningUnknown();

  @override
  List<Object?> get props => const [];
}

/// Whether the place is open at [wallClock], its own local time.
OpeningStatus openingStatusAt(OpeningHours hours, DateTime wallClock) {
  if (hours.alwaysOpen) return const OpenNow(closesAt: null);
  if (hours.schedules.isEmpty) return const OpeningUnknown();

  DateTime at(int dayOffset, [int minutes = 0]) {
    final make = wallClock.isUtc ? DateTime.utc : DateTime.new;
    return make(
      wallClock.year,
      wallClock.month,
      wallClock.day + dayOffset,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  Iterable<(DateTime, DateTime)> openOn(int dayOffset) sync* {
    final date = at(dayOffset);
    final day = scheduleOn(hours, date)?.dayHours(date.weekday);
    if (day == null) return;
    switch (day.kind) {
      case DayHoursKind.closed:
        return;
      case DayHoursKind.open24h:
        yield (at(dayOffset), at(dayOffset, minutesPerDay));
      case DayHoursKind.ranges:
        for (final r in day.ranges) {
          yield (at(dayOffset, r.opensAt), at(dayOffset, r.closesAt));
        }
    }
  }

  for (final (opens, closes) in openOn(0)) {
    if (wallClock.isBefore(opens) || !wallClock.isBefore(closes)) continue;
    return OpenNow(closesAt: _closingFrom(closes, openOn));
  }

  final outOfSeason = scheduleOn(hours, at(0)) == null;
  for (var offset = 0; offset <= _lookAheadDays; offset++) {
    for (final (opens, _) in openOn(offset)) {
      if (opens.isAfter(wallClock)) {
        return ClosedNow(nextOpen: opens, outOfSeason: outOfSeason);
      }
    }
  }
  return ClosedNow(nextOpen: null, outOfSeason: outOfSeason);
}

/// Follows an open stretch ending at [closes] through every range that opens
/// exactly as the last one closes: a later range the same day (12:00 to
/// 13:00, then 13:00 on) or the next day's from midnight. Null when it never
/// ends within a week.
DateTime? _closingFrom(
  DateTime closes,
  Iterable<(DateTime, DateTime)> Function(int dayOffset) openOn,
) {
  final ahead = [
    for (var offset = 0; offset <= _neverClosesAfterDays; offset++)
      ...openOn(offset),
  ];
  // Still open a week past the first close: it does not close. Each step
  // moves [end] strictly later (a range closes after it opens), so the
  // loop ends.
  final horizon = closes.add(const Duration(days: _neverClosesAfterDays - 1));
  var end = closes;
  while (end.isBefore(horizon)) {
    final next = ahead.where((r) => r.$1 == end).firstOrNull;
    if (next == null) return end;
    end = next.$2;
  }
  return null;
}
