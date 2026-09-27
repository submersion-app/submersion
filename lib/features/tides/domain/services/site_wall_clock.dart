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

/// [extremes] with their times moved to site wall clock, for display.
List<TideExtreme> extremesAtSiteWallClock(
  List<TideExtreme> extremes,
  GeoPoint location,
) => [
  for (final e in extremes) e.copyWith(time: siteWallClock(e.time, location)),
];

/// [predictions] with their times moved to site wall clock, for display.
List<TidePrediction> predictionsAtSiteWallClock(
  List<TidePrediction> predictions,
  GeoPoint location,
) => [
  for (final prediction in predictions)
    prediction.copyWith(time: siteWallClock(prediction.time, location)),
];

extension TideRecordSiteWallClock on TideRecord {
  /// This record with its high and low times moved from real instants to
  /// site wall clock, for display. Storage always keeps instants.
  TideRecord toSiteWallClock(GeoPoint location) => copyWith(
    highTideTime: highTideTime == null
        ? null
        : siteWallClock(highTideTime!, location),
    lowTideTime: lowTideTime == null
        ? null
        : siteWallClock(lowTideTime!, location),
  );
}
