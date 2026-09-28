import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as common_tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/util/site_time_zone.dart';

// Own file: this test swaps the process-wide timezone database, and the
// full-database reload it exercises happens once per process.
void main() {
  test('a hand-built tz.local survives the full-database reload', () {
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
