import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as lat_lng_tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/util/time_zone_database.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';

/// Offline mapping from a coordinate to its local clock.
///
/// Dive times are stored as wall-clock-as-UTC (see `wall_clock_utc.dart`),
/// but tide predictions need real instants. The zone for a coordinate comes
/// from the same offline lookup the importers use (`lat_lng_to_timezone`),
/// so a wall clock an importer derived for a site is read back in the same
/// zone.
abstract final class SiteTimeZone {
  /// Replaces [zoneIdFor] inside the conversions, for tests only.
  @visibleForTesting
  static String Function(double latitude, double longitude)?
  debugZoneIdOverride;

  static final Set<String> _loggedMissingZones = {};

  /// The UTC instant at which the site's clocks show [wallClock]'s digits.
  ///
  /// Only the calendar and clock components of [wallClock] are read, so a
  /// wall-clock-as-UTC value and a local `DateTime` with the same digits
  /// give the same answer. The offset comes from tzdata for that date. In a
  /// spring-forward gap the time rolls forward by the gap (02:30 reads as
  /// 03:30 daylight time); in a fall-back overlap the earlier, daylight-time
  /// occurrence is used. Both behaviors are `package:timezone`'s.
  static DateTime instantFromWallClock(
    DateTime wallClock,
    double latitude,
    double longitude,
  ) {
    final local = tz.TZDateTime(
      _locationFor(latitude, longitude),
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
      wallClock.millisecond,
    );
    return DateTime.fromMillisecondsSinceEpoch(
      local.millisecondsSinceEpoch,
      isUtc: true,
    );
  }

  /// The site's wall-clock digits at [instant], as a wall-clock-as-UTC value
  /// (the flavor every tide formatter prints verbatim).
  static DateTime wallClockFromInstant(
    DateTime instant,
    double latitude,
    double longitude,
  ) => wallClockConverterFor(latitude, longitude)(instant);

  /// [wallClockFromInstant] with the site's zone resolved once, for mapping
  /// many instants at the same coordinate. The closure keeps only the
  /// resolved location.
  static DateTime Function(DateTime instant) wallClockConverterFor(
    double latitude,
    double longitude,
  ) {
    final location = _locationFor(latitude, longitude);
    return (instant) => asWallClockUtc(tz.TZDateTime.from(instant, location));
  }

  static tz.Location _locationFor(double latitude, double longitude) {
    ensureTimeZoneDatabase();
    final id = (debugZoneIdOverride ?? zoneIdFor)(latitude, longitude);
    return _find(id) ?? _find(etcZoneForLongitude(longitude)) ?? tz.UTC;
  }

  static tz.Location? _find(String id) {
    final found = tz.timeZoneDatabase.locations[id];
    if (found == null && _loggedMissingZones.add(id)) {
      developer.log('Zone $id is missing from tzdata', name: 'SiteTimeZone');
    }
    return found;
  }

  /// IANA zone id for the coordinate. Offshore points resolve to the
  /// nearest land zone, keeping its daylight saving, as the importers do.
  /// Never throws: coordinates outside the valid range (which the lookup
  /// would still map to some zone) yield the `Etc/GMT` zone for their
  /// longitude.
  static String zoneIdFor(double latitude, double longitude) {
    final valid =
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
    if (!valid) return etcZoneForLongitude(longitude);
    final name = lat_lng_tz.latLngToTimezoneString(latitude, longitude);
    return name.isEmpty ? etcZoneForLongitude(longitude) : name;
  }

  /// The fixed-offset `Etc/GMT` zone nearest to [longitude]. POSIX zone
  /// names invert the sign: 15 degrees east is `Etc/GMT-1`.
  static String etcZoneForLongitude(double longitude) {
    if (!longitude.isFinite) return 'Etc/GMT';
    final hours = (longitude.clamp(-180.0, 180.0) / 15).round().clamp(-12, 12);
    if (hours == 0) return 'Etc/GMT';
    return hours > 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}';
  }
}
