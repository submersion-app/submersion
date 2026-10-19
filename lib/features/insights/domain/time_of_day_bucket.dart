import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/core/util/sun_times.dart';

/// The part of the day a dive belongs to (issue #3340), in the order of the
/// day, which is also the order the Time patterns chart lists them in.
enum TimeOfDayBucket {
  /// In before sunrise, out after it.
  dawn('Dawn'),

  /// In after sunrise and before midday.
  morning('Morning'),

  /// In from midday, out before sunset.
  afternoon('Afternoon'),

  /// In before sunset, out after it.
  dusk('Dusk'),

  /// The whole dive is in darkness.
  night('Night');

  const TimeOfDayBucket(this.key);

  /// Stable, locale-independent key; the presentation layer translates it
  /// through `timeOfDayDistributionLabel`.
  final String key;

  static TimeOfDayBucket? fromKey(String key) {
    for (final bucket in values) {
      if (bucket.key == key) return bucket;
    }
    return null;
  }
}

/// Where the sunrise and sunset a dive was bucketed against came from.
enum SunTimesBasis {
  /// Computed for the dive site on the dive date.
  site,

  /// The dive has no site, or the site has no usable coordinates: the
  /// fallback clock times were used.
  noLocation,

  /// The site is placed, but the sun did not rise or set there that day
  /// (polar day or polar night): the fallback clock times were used.
  noSunEvent,
}

typedef TimeOfDayClassification = ({
  TimeOfDayBucket bucket,
  SunTimesBasis basis,
});

/// Buckets a dive by its entry and exit against sunrise and sunset at the
/// dive site (issue #3340). The Time patterns chart and the Dive focus
/// "Time of day" factor both classify through here, so they cannot disagree.
///
/// Every time is a wall clock stored as UTC (see `wall_clock_utc.dart`): the
/// digits the diver saw at the site.
///
/// An instance remembers the clock of each site it has seen, because
/// resolving a coordinate to its time zone is the expensive step and a log
/// revisits the same sites. Sun times are plain arithmetic and are not kept.
class TimeOfDayClassifier {
  /// Stands in for sunrise when it cannot be derived.
  static const int fallbackSunriseHour = 6;

  /// Stands in for sunset when it cannot be derived.
  static const int fallbackSunsetHour = 18;

  /// Splits morning from afternoon on the site's clock, always: morning and
  /// afternoon are clock ideas, so this is never solar noon.
  static const int middayHour = 12;

  final Map<(double, double), DateTime Function(DateTime)> _siteClocks = {};

  /// The bucket for a dive, given the sun times of the entry date.
  ///
  /// The rules are checked in the order Dawn, Dusk, Night, Morning,
  /// Afternoon, so a dive that crosses sunrise or sunset is always Dawn or
  /// Dusk whatever its entry time. An entry at the very moment of sunrise or
  /// sunset counts as after it; an exit at that moment has not crossed it.
  ///
  /// [nextSunrise] is the following day's sunrise, which a dive running past
  /// midnight is measured against; left out, it is taken as a day after
  /// [sunrise]. An [exit] that is missing, or not after [entry], leaves the
  /// entry alone to decide, and such a dive is never Dawn or Dusk.
  static TimeOfDayBucket bucketFor({
    required DateTime entry,
    DateTime? exit,
    required DateTime sunrise,
    required DateTime sunset,
    DateTime? nextSunrise,
  }) {
    final end = exit != null && exit.isAfter(entry) ? exit : entry;
    final laterSunrise = nextSunrise ?? sunrise.add(const Duration(days: 1));

    // A dive crossing both sunset and the next sunrise takes the first one
    // it crossed, so only an entry already past sunset reaches the next
    // sunrise here; a daylight entry falls through to Dusk.
    final crossesSunrise =
        (entry.isBefore(sunrise) && end.isAfter(sunrise)) ||
        (!entry.isBefore(sunset) && end.isAfter(laterSunrise));
    if (crossesSunrise) return TimeOfDayBucket.dawn;
    if (entry.isBefore(sunset) && end.isAfter(sunset)) {
      return TimeOfDayBucket.dusk;
    }
    if (entry.isBefore(sunrise) || !entry.isBefore(sunset)) {
      return TimeOfDayBucket.night;
    }
    return entry.hour < middayHour
        ? TimeOfDayBucket.morning
        : TimeOfDayBucket.afternoon;
  }

  /// Buckets a dive at the site at [latitude], [longitude].
  ///
  /// Falls back to [fallbackSunriseHour] and [fallbackSunsetHour] when the
  /// coordinates are missing, unusable or 0,0, or the sun does not rise or set
  /// there on the entry date; [SunTimesBasis] says which.
  TimeOfDayClassification classify({
    required DateTime entry,
    DateTime? exit,
    double? latitude,
    double? longitude,
  }) {
    // 0,0 is the stand-in devices and logbooks write for "no fix" (see
    // `ImportSiteLocation.fix`), not a dive site in the Gulf of Guinea.
    if (latitude == null ||
        longitude == null ||
        (latitude == 0 && longitude == 0) ||
        !SunCalculator.isValidCoordinate(latitude, longitude)) {
      return (bucket: _fallback(entry, exit), basis: SunTimesBasis.noLocation);
    }

    final toWallClock = _siteClocks.putIfAbsent((
      latitude,
      longitude,
    ), () => SiteTimeZone.wallClockConverterFor(latitude, longitude));
    final sun = SunCalculator.wallClockFor(
      entry,
      latitude,
      longitude,
      toWallClock,
    );
    if (sun == null) {
      return (bucket: _fallback(entry, exit), basis: SunTimesBasis.noSunEvent);
    }

    // The next sunrise only matters to a dive that runs into another day.
    final runsPastMidnight =
        exit != null &&
        DateTime.utc(
          exit.year,
          exit.month,
          exit.day,
        ).isAfter(DateTime.utc(entry.year, entry.month, entry.day));
    final nextDay = runsPastMidnight
        ? SunCalculator.wallClockFor(
            DateTime.utc(entry.year, entry.month, entry.day + 1),
            latitude,
            longitude,
            toWallClock,
          )
        : null;

    return (
      bucket: bucketFor(
        entry: entry,
        exit: exit,
        sunrise: sun.sunrise,
        sunset: sun.sunset,
        // The sun may not rise the next day (polar day or night begins);
        // that date then takes the fallback sunrise, as any such day does.
        nextSunrise: runsPastMidnight
            ? nextDay?.sunrise ??
                  DateTime.utc(
                    entry.year,
                    entry.month,
                    entry.day + 1,
                    fallbackSunriseHour,
                  )
            : null,
      ),
      basis: SunTimesBasis.site,
    );
  }

  static TimeOfDayBucket _fallback(DateTime entry, DateTime? exit) => bucketFor(
    entry: entry,
    exit: exit,
    sunrise: DateTime.utc(
      entry.year,
      entry.month,
      entry.day,
      fallbackSunriseHour,
    ),
    sunset: DateTime.utc(
      entry.year,
      entry.month,
      entry.day,
      fallbackSunsetHour,
    ),
  );
}
