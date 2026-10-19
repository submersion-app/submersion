import 'dart:math' as math;

/// Sunrise and sunset for one day at one place.
typedef SunTimes = ({DateTime sunrise, DateTime sunset});

/// Offline sunrise and sunset from a coordinate and a date (issue #3340).
///
/// The NOAA solar equations (Meeus, "Astronomical Algorithms"), good to
/// about a minute away from the poles. Sunrise and sunset are the moments
/// the sun's upper edge meets a sea-level horizon, with the standard
/// allowance for atmospheric refraction.
///
/// A time zone plays no part in the calculation: the sun times come from the
/// coordinate alone, as instants. [wallClockFor] then reads those instants on
/// the site's clock, which is where the zone and daylight saving come in.
abstract final class SunCalculator {
  /// The sun's centre at sunrise and sunset: 90 degrees, plus 34 arc minutes
  /// of refraction and the 16 arc minute solar radius.
  static const double _zenithDegrees = 90.833;

  static const double _minutesPerDay = 1440;
  static const double _julianDayOfUnixEpoch = 2440587.5;
  static const double _julianDayOfJ2000 = 2451545.0;
  static const double _daysPerJulianCentury = 36525.0;

  /// Sunrise and sunset, as UTC instants, of the solar day whose noon at
  /// [longitude] falls on the UTC calendar date [year]-[month]-[day].
  ///
  /// Null when the sun does not rise or does not set that day (polar night
  /// or polar day), and for a coordinate that is not on the globe.
  static SunTimes? utcFor(
    int year,
    int month,
    int day,
    double latitude,
    double longitude,
  ) {
    if (!isValidCoordinate(latitude, longitude)) return null;

    final midnight = DateTime.utc(year, month, day);
    // Evaluate the sun's position at local mean noon, not at 00:00 UTC, so
    // the answer does not drift with longitude.
    final meanNoonMinutes = _minutesPerDay / 2 - 4 * longitude;
    final julianDay =
        midnight.millisecondsSinceEpoch / Duration.millisecondsPerDay +
        _julianDayOfUnixEpoch +
        meanNoonMinutes / _minutesPerDay;
    final t = (julianDay - _julianDayOfJ2000) / _daysPerJulianCentury;

    final meanLongitude = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360;
    final meanAnomaly = 357.52911 + t * (35999.05029 - 0.0001537 * t);
    final eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    final m = _radians(meanAnomaly);
    final equationOfCenter =
        math.sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
        math.sin(2 * m) * (0.019993 - 0.000101 * t) +
        math.sin(3 * m) * 0.000289;
    final omega = _radians(125.04 - 1934.136 * t);
    final apparentLongitude = _radians(
      meanLongitude + equationOfCenter - 0.00569 - 0.00478 * math.sin(omega),
    );
    final meanObliquity =
        23 +
        (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    final obliquity = _radians(meanObliquity + 0.00256 * math.cos(omega));
    final declination = math.asin(
      math.sin(obliquity) * math.sin(apparentLongitude),
    );

    // Equation of time: how far the sundial runs ahead of the clock.
    final y = math.pow(math.tan(obliquity / 2), 2).toDouble();
    final l0 = _radians(meanLongitude);
    final equationOfTimeMinutes =
        4 *
        _degrees(
          y * math.sin(2 * l0) -
              2 * eccentricity * math.sin(m) +
              4 * eccentricity * y * math.sin(m) * math.cos(2 * l0) -
              0.5 * y * y * math.sin(4 * l0) -
              1.25 * eccentricity * eccentricity * math.sin(2 * m),
        );

    final lat = _radians(latitude);
    final cosHourAngle =
        math.cos(_radians(_zenithDegrees)) /
            (math.cos(lat) * math.cos(declination)) -
        math.tan(lat) * math.tan(declination);
    // Above 1 the sun never reaches the horizon; below -1 it never leaves
    // the sky. A pole itself divides by zero and lands here as well.
    if (!cosHourAngle.isFinite || cosHourAngle.abs() > 1) return null;

    final halfDayMinutes = 4 * _degrees(math.acos(cosHourAngle));
    final solarNoonMinutes = meanNoonMinutes - equationOfTimeMinutes;
    DateTime at(double minutes) => midnight.add(
      Duration(
        milliseconds: (minutes * Duration.millisecondsPerMinute).round(),
      ),
    );
    return (
      sunrise: at(solarNoonMinutes - halfDayMinutes),
      sunset: at(solarNoonMinutes + halfDayMinutes),
    );
  }

  /// Sunrise and sunset on the site's clock for the calendar day of [date],
  /// as wall-clock-as-UTC values (see `wall_clock_utc.dart`).
  ///
  /// Only the year, month and day of [date] are read. [toWallClock] maps an
  /// instant to the site's wall clock, as
  /// `SiteTimeZone.wallClockConverterFor` returns.
  ///
  /// Where the clock runs far from the sun (Kiritimati keeps UTC+14 at 157
  /// degrees west), the solar day computed for a date lands on the
  /// neighbouring day of the site's calendar. The date is then stepped until
  /// solar noon reads on the day asked for. Null as [utcFor] is.
  static SunTimes? wallClockFor(
    DateTime date,
    double latitude,
    double longitude,
    DateTime Function(DateTime instant) toWallClock,
  ) {
    final wanted = DateTime.utc(date.year, date.month, date.day);
    var candidate = wanted;
    // One step corrects any real zone; the bound only stops a converter
    // that never agrees.
    for (var attempt = 0; attempt < 3; attempt++) {
      final sun = utcFor(
        candidate.year,
        candidate.month,
        candidate.day,
        latitude,
        longitude,
      );
      if (sun == null) return null;
      final noon = sun.sunrise.add(sun.sunset.difference(sun.sunrise) ~/ 2);
      final noonWall = toWallClock(noon);
      final offDays = DateTime.utc(
        noonWall.year,
        noonWall.month,
        noonWall.day,
      ).difference(wanted).inDays;
      if (offDays == 0) {
        return (
          sunrise: toWallClock(sun.sunrise),
          sunset: toWallClock(sun.sunset),
        );
      }
      candidate = DateTime.utc(
        candidate.year,
        candidate.month,
        candidate.day - offDays,
      );
    }
    return null;
  }

  /// Whether the pair is a finite point on the globe.
  static bool isValidCoordinate(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static double _radians(double degrees) => degrees * math.pi / 180;

  static double _degrees(double radians) => radians * 180 / math.pi;
}
