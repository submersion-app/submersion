import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as common_tzdata;
import 'package:timezone/data/latest_all.dart' as full_tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/util/site_time_zone.dart';

// Swaps the process-wide timezone database and tz.local; restores both in a
// tear-down so bundled runs stay isolated.
void main() {
  test('a hand-built tz.local survives the full-database reload', () {
    // Bundled CI runs share this isolate: put the full database and the
    // previous local zone back, even if an expectation fails.
    final previousLocal = tz.timeZoneDatabase.isInitialized ? tz.local : null;
    addTearDown(() {
      full_tzdata.initializeTimeZones();
      if (previousLocal != null) {
        tz.setLocalLocation(
          tz.timeZoneDatabase.locations[previousLocal.name] ?? previousLocal,
        );
      }
    });
    common_tzdata.initializeTimeZones();
    final custom = tz.Location('Custom/Local', [tz.minTime], [0], [
      const tz.TimeZone(Duration(hours: 1), isDst: false, abbreviation: 'CL'),
    ]);
    tz.setLocalLocation(custom);

    // Cocos is missing from the subset, so this lookup reloads the database.
    SiteTimeZone.instantFromWallClock(DateTime.utc(2026, 7, 15), -12.19, 96.83);

    expect(tz.local, same(custom));
  });
}
