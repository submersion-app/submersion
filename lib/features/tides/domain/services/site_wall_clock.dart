import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';
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

DateTime Function(DateTime) _converter(GeoPoint location) =>
    SiteTimeZone.wallClockConverterFor(location.latitude, location.longitude);

/// [extremes] with their times moved to site wall clock, for display.
List<TideExtreme> extremesAtSiteWallClock(
  List<TideExtreme> extremes,
  GeoPoint location,
) {
  final toSite = _converter(location);
  return [for (final e in extremes) e.copyWith(time: toSite(e.time))];
}

/// [predictions] with their times moved to site wall clock, for display.
///
/// A fall-back night repeats an hour of the site's clock. The repeated
/// samples are dropped so the series stays in time order and a chart drawn
/// against it never doubles back; a spring-forward night simply skips.
List<TidePrediction> predictionsAtSiteWallClock(
  List<TidePrediction> predictions,
  GeoPoint location,
) {
  final toSite = _converter(location);
  final mapped = <TidePrediction>[];
  for (final prediction in predictions) {
    final time = toSite(prediction.time);
    if (mapped.isNotEmpty && !time.isAfter(mapped.last.time)) continue;
    mapped.add(prediction.copyWith(time: time));
  }
  return mapped;
}

extension TideRecordSiteWallClock on TideRecord {
  /// This record with its high and low times moved from real instants to
  /// site wall clock, for display. Storage always keeps instants.
  TideRecord toSiteWallClock(GeoPoint location) {
    final toSite = _converter(location);
    return copyWith(
      highTideTime: highTideTime == null ? null : toSite(highTideTime!),
      lowTideTime: lowTideTime == null ? null : toSite(lowTideTime!),
    );
  }
}
