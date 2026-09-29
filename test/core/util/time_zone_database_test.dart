import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/util/time_zone_database.dart';

void main() {
  test('loads the zone database so named zones resolve', () {
    ensureTimeZoneDatabase();

    expect(tz.timeZoneDatabase.isInitialized, isTrue);
    expect(tz.getLocation('Pacific/Tahiti').name, 'Pacific/Tahiti');
  });

  test('a second call keeps the local zone another feature set', () {
    // Loading the database resets `tz.local` to UTC, so reloading it after
    // the notification service set the device zone would silently move
    // every scheduled reminder.
    ensureTimeZoneDatabase();
    final tahiti = tz.getLocation('Pacific/Tahiti');
    tz.setLocalLocation(tahiti);
    addTearDown(() => tz.setLocalLocation(tz.UTC));

    ensureTimeZoneDatabase();

    expect(tz.local, same(tahiti));
    expect(tz.getLocation('Pacific/Tahiti'), same(tahiti));
  });
}
