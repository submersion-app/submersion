import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Loads the IANA zone database into the `timezone` package, once per
/// isolate.
///
/// Every feature that converts between named zones needs it: notification
/// scheduling on mobile, and importers that turn a stored instant into the
/// wall clock of the zone a dive was logged in. It is loaded on first use
/// rather than at startup, because decoding the full database costs time the
/// app should only spend when a feature asks for it. Safe to call repeatedly.
void ensureTimeZoneDatabase() {
  if (!tz.timeZoneDatabase.isInitialized) tz_data.initializeTimeZones();
}
