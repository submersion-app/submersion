import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/tide_calculator.dart';
import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The real instant of a dive entry stored as site wall-clock
/// (wall-clock-as-UTC, see `wall_clock_utc.dart`).
DateTime diveEntryInstant(DateTime entryWallClock, GeoPoint location) =>
    SiteTimeZone.instantFromWallClock(
      entryWallClock,
      location.latitude,
      location.longitude,
    );

/// Tide status at a dive's entry. The engine is evaluated at the real
/// instant; the returned extremes are real UTC instants, to be mapped with
/// `toSiteWallClock` (site_wall_clock.dart) before display.
Future<TideStatus> tideStatusForDive({
  required TideCalculator calculator,
  required DateTime entryWallClock,
  required GeoPoint location,
}) => calculator.getStatusAsync(diveEntryInstant(entryWallClock, location));

/// Synchronous twin of [tideStatusForDive] for code already inside `build`.
TideStatus tideStatusForDiveSync({
  required TideCalculator calculator,
  required DateTime entryWallClock,
  required GeoPoint location,
}) => calculator.getStatus(diveEntryInstant(entryWallClock, location));
