import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';

/// The site's wall clock at [instant], as wall-clock-as-UTC.
DateTime siteWallClock(DateTime instant, GeoPoint location) =>
    SiteTimeZone.wallClockFromInstant(
      instant,
      location.latitude,
      location.longitude,
    );

/// Maps instants at [location] to its wall clock, with the zone resolved
/// once; for labelling many times at one site.
DateTime Function(DateTime instant) siteClockConverter(GeoPoint location) =>
    SiteTimeZone.wallClockConverterFor(location.latitude, location.longitude);

/// [extremes] with their times moved to site wall clock, for display.
List<TideExtreme> extremesAtSiteWallClock(
  List<TideExtreme> extremes,
  GeoPoint location,
) {
  final toSite = siteClockConverter(location);
  return [for (final e in extremes) e.copyWith(time: toSite(e.time))];
}

extension TideRecordSiteWallClock on TideRecord {
  /// This record with its high and low times moved from real instants to
  /// site wall clock, for display. Storage always keeps instants.
  TideRecord toSiteWallClock(GeoPoint location) {
    final toSite = siteClockConverter(location);
    return copyWith(
      highTideTime: highTideTime == null ? null : toSite(highTideTime!),
      lowTideTime: lowTideTime == null ? null : toSite(lowTideTime!),
    );
  }
}
