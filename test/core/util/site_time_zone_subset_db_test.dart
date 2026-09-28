import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as common_tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/util/site_time_zone.dart';

// Own file: this test swaps the process-wide timezone database.
void main() {
  test('a subset database loaded elsewhere is upgraded, keeping tz.local', () {
    // Another caller loaded the common subset and chose a local zone.
    common_tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Denver'));
    expect(tz.timeZoneDatabase.locations.containsKey('Indian/Cocos'), isFalse);

    // Cocos Islands keep UTC+6:30; a whole-hour longitude guess gives +6.
    expect(
      SiteTimeZone.instantFromWallClock(
        DateTime.utc(2026, 7, 15, 12),
        -12.19,
        96.83,
      ),
      DateTime.utc(2026, 7, 15, 5, 30),
    );
    expect(tz.local.name, 'America/Denver');
  });
}
