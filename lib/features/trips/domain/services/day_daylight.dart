import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/core/util/sun_times.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/insights/domain/time_of_day_bucket.dart';

/// Where a day's sunrise and sunset came from (issue #4375).
enum DaylightBasis {
  /// Computed for a dive site of the day, on that site's clock.
  site,

  /// No dive of the day has a usable site, or the sun does not rise or set
  /// there that day: the 06:00 and 18:00 stand-ins of
  /// [TimeOfDayClassifier] are used, and are never shown as real times.
  fallback,
}

/// The colour a point of the day timeline's sky takes.
enum SkyTone { night, sunriseGlow, day, sunsetGlow }

/// One sunrise or sunset that falls on the day.
class SunEvent extends Equatable {
  final bool isSunrise;

  /// Position on the day, 0 at 00:00 and 1 at 24:00 on the site's clock.
  final double fraction;

  /// The event on the site's clock, as a wall-clock-as-UTC value.
  final DateTime wallClock;

  const SunEvent({
    required this.isSunrise,
    required this.fraction,
    required this.wallClock,
  });

  @override
  List<Object?> get props => [isSunrise, fraction, wallClock];
}

/// Daylight across one calendar day of a trip, for the day timeline.
class DayDaylight extends Equatable {
  final DaylightBasis basis;

  /// Whether the sun is up at 00:00. True only where the previous evening's
  /// sunset falls after midnight.
  final bool startsInDaylight;

  /// Every sunrise and sunset whose wall clock lands on the day, in order.
  final List<SunEvent> events;

  const DayDaylight({
    required this.basis,
    required this.startsInDaylight,
    required this.events,
  });

  /// The first real sunrise of the day; null for a fallback day.
  SunEvent? get sunrise => _first(isSunrise: true);

  /// The first real sunset of the day; null for a fallback day.
  SunEvent? get sunset => _first(isSunrise: false);

  SunEvent? _first({required bool isSunrise}) {
    if (basis == DaylightBasis.fallback) return null;
    for (final event in events) {
      if (event.isSunrise == isSunrise) return event;
    }
    return null;
  }

  @override
  List<Object?> get props => [basis, startsInDaylight, events];
}

/// One colour stop of the day timeline's sky gradient.
typedef SkyStop = ({double fraction, SkyTone tone});

const double _secondsPerDay = 24 * 3600;

/// The sky across the day of [dives] (issue #4375).
///
/// The place is the first dive, in the order given, whose site has a usable
/// location, by the same rules [TimeOfDayClassifier.classify] applies; the
/// day is that dive's wall-clock date. The events come from the day before,
/// the day itself and the day after, so a sunset that runs past midnight is
/// drawn on the day it actually falls on.
///
/// Pass the [classifier] that colours the same dives' blocks to reuse its
/// site clocks rather than resolving the time zone again.
DayDaylight computeDayDaylight(
  List<Dive> dives, {
  TimeOfDayClassifier? classifier,
}) {
  for (final dive in dives) {
    final location = dive.site?.location;
    if (location == null ||
        !TimeOfDayClassifier.hasUsableLocation(
          location.latitude,
          location.longitude,
        )) {
      continue;
    }
    final entry = dive.entryTime ?? dive.dateTime;
    return _siteDaylight(
      DateTime.utc(entry.year, entry.month, entry.day),
      location.latitude,
      location.longitude,
      (classifier ?? TimeOfDayClassifier()).siteClockFor(
        location.latitude,
        location.longitude,
      ),
    );
  }
  if (dives.isEmpty) return _fallbackDaylight(DateTime.utc(2000));
  final entry = dives.first.entryTime ?? dives.first.dateTime;
  return _fallbackDaylight(DateTime.utc(entry.year, entry.month, entry.day));
}

/// The gradient stops for [daylight]: the tone at 00:00, three stops per
/// event (night 40 minutes before sunrise, the glow at it, day 30 minutes
/// after; mirrored at sunset), and the tone at 24:00.
///
/// Event stops can fall before 00:00 or after 24:00; the painter cuts those
/// off at the bar's ends. Fractions never decrease, so events closer
/// together than their glows still give a valid gradient.
List<SkyStop> skyStops(DayDaylight daylight) {
  const minute = 60 / _secondsPerDay;
  final eventStops = <SkyStop>[
    for (final event in daylight.events)
      if (event.isSunrise) ...[
        (fraction: event.fraction - 40 * minute, tone: SkyTone.night),
        (fraction: event.fraction, tone: SkyTone.sunriseGlow),
        (fraction: event.fraction + 30 * minute, tone: SkyTone.day),
      ] else ...[
        (fraction: event.fraction - 30 * minute, tone: SkyTone.day),
        (fraction: event.fraction, tone: SkyTone.sunsetGlow),
        (fraction: event.fraction + 40 * minute, tone: SkyTone.night),
      ],
  ];
  final startTone = daylight.startsInDaylight ? SkyTone.day : SkyTone.night;
  final endTone = daylight.events.isEmpty
      ? startTone
      : (daylight.events.last.isSunrise ? SkyTone.day : SkyTone.night);
  final raw = <SkyStop>[
    (
      fraction: math.min(0.0, eventStops.firstOrNull?.fraction ?? 0),
      tone: startTone,
    ),
    ...eventStops,
    (
      fraction: math.max(1.0, eventStops.lastOrNull?.fraction ?? 1),
      tone: endTone,
    ),
  ];
  final stops = <SkyStop>[];
  var floor = double.negativeInfinity;
  for (final stop in raw) {
    floor = math.max(floor, stop.fraction);
    stops.add((fraction: floor, tone: stop.tone));
  }
  return stops;
}

DayDaylight _siteDaylight(
  DateTime day,
  double latitude,
  double longitude,
  DateTime Function(DateTime instant) toWallClock,
) {
  SunTimes? sunOn(int offsetDays) => SunCalculator.wallClockFor(
    DateTime.utc(day.year, day.month, day.day + offsetDays),
    latitude,
    longitude,
    toWallClock,
  );

  final today = sunOn(0);
  if (today == null) return _fallbackDaylight(day);

  final all = <({bool isSunrise, DateTime at})>[
    for (final sun in [sunOn(-1), today, sunOn(1)])
      if (sun != null) ...[
        (isSunrise: true, at: sun.sunrise),
        (isSunrise: false, at: sun.sunset),
      ],
  ]..sort((a, b) => a.at.compareTo(b.at));

  final dayEnd = day.add(const Duration(days: 1));
  final before = all.where((e) => e.at.isBefore(day)).toList();
  final within = all
      .where((e) => !e.at.isBefore(day) && e.at.isBefore(dayEnd))
      .toList();

  final startsInDaylight = before.isNotEmpty
      ? before.last.isSunrise
      : (within.isNotEmpty && !within.first.isSunrise);

  return DayDaylight(
    basis: DaylightBasis.site,
    startsInDaylight: startsInDaylight,
    events: [
      for (final e in within)
        SunEvent(
          isSunrise: e.isSunrise,
          fraction: e.at.difference(day).inMilliseconds / 1000 / _secondsPerDay,
          wallClock: e.at,
        ),
    ],
  );
}

/// The 06:00 and 18:00 stand-ins on [day], as [TimeOfDayClassifier] uses.
DayDaylight _fallbackDaylight(DateTime day) {
  SunEvent at(int hour, {required bool isSunrise}) => SunEvent(
    isSunrise: isSunrise,
    fraction: hour / 24,
    wallClock: DateTime.utc(day.year, day.month, day.day, hour),
  );
  return DayDaylight(
    basis: DaylightBasis.fallback,
    startsInDaylight: false,
    events: [
      at(TimeOfDayClassifier.fallbackSunriseHour, isSunrise: true),
      at(TimeOfDayClassifier.fallbackSunsetHour, isSunrise: false),
    ],
  );
}
