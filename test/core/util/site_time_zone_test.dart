import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/features/universal_import/data/services/macdive_time_zone.dart';

void main() {
  tearDown(() => SiteTimeZone.debugZoneIdOverride = null);

  group('SiteTimeZone.zoneIdFor', () {
    // Public dive sites, offshore points and places where zone lookups have
    // historically disagreed.
    const sites = {
      'Socorro': (18.78, -110.95),
      'Roca Partida': (19.00, -112.07),
      'Bonaire': (12.15, -68.27),
      'Daedalus Reef': (24.93, 35.87),
      'Cozumel': (20.35, -87.03),
      'Monterey': (36.62, -121.90),
      'Komodo': (-8.55, 119.55),
      'Fiji Beqa': (-18.40, 178.10),
      'Silfra': (64.26, -21.12),
      'Open Atlantic': (30.0, -40.0),
    };

    test('agrees with the importers, which write the wall clocks it reads', () {
      // An importer turns a dive's instant into a wall clock with the site's
      // zone; tides turn that wall clock back into an instant. Any other
      // zone here would shift every tide by the difference.
      for (final site in sites.entries) {
        expect(
          SiteTimeZone.zoneIdFor(site.value.$1, site.value.$2),
          MacDiveTimeZone.nameForLocation(site.value.$1, site.value.$2),
          reason: site.key,
        );
      }
    });

    test('every zone it returns resolves in the bundled tzdata', () {
      // A lookup zone newer than package:timezone's data would silently fall
      // back to the whole-hour longitude offset.
      SiteTimeZone.instantFromWallClock(DateTime.utc(2026), 12.15, -68.27);
      final missing = <String>{
        for (var lat = -80.0; lat <= 80.0; lat += 4)
          for (var lon = -180.0; lon < 180.0; lon += 4)
            SiteTimeZone.zoneIdFor(lat, lon),
      }.where((zone) => !tz.timeZoneDatabase.locations.containsKey(zone));
      expect(missing, isEmpty);
    });

    test('invalid coordinates fall back to a longitude zone', () {
      expect(SiteTimeZone.zoneIdFor(95.0, -68.0), 'Etc/GMT+5');
      expect(SiteTimeZone.zoneIdFor(10.0, 200.0), 'Etc/GMT-12');
      expect(SiteTimeZone.zoneIdFor(double.nan, double.nan), 'Etc/GMT');
    });
  });

  group('SiteTimeZone conversions', () {
    const monterey = (36.62, -121.90);
    const sydney = (-33.86, 151.21);
    const adelaide = (-34.93, 138.60);
    const bonaire = (12.15, -68.27);
    const openAtlantic = (30.0, -40.0);
    const fiji = (-18.40, 178.10);

    DateTime instant((double, double) site, DateTime wallClock) =>
        SiteTimeZone.instantFromWallClock(wallClock, site.$1, site.$2);

    test('northern DST follows the date', () {
      expect(
        instant(monterey, DateTime.utc(2026, 1, 15, 10)),
        DateTime.utc(2026, 1, 15, 18),
      );
      expect(
        instant(monterey, DateTime.utc(2026, 7, 15, 10)),
        DateTime.utc(2026, 7, 15, 17),
      );
    });

    test('southern DST, half-hour zones, no-DST and open ocean', () {
      expect(
        instant(sydney, DateTime.utc(2026, 1, 15, 10)),
        DateTime.utc(2026, 1, 14, 23),
      );
      expect(
        instant(sydney, DateTime.utc(2026, 7, 15, 10)),
        DateTime.utc(2026, 7, 15, 0),
      );
      expect(
        instant(adelaide, DateTime.utc(2026, 7, 15, 10)),
        DateTime.utc(2026, 7, 15, 0, 30),
      );
      expect(
        instant(bonaire, DateTime.utc(2026, 3, 28, 10)),
        DateTime.utc(2026, 3, 28, 14),
      );
      // Offshore points take the nearest land zone: here the Azores, still
      // on UTC-1 the day before their daylight saving starts.
      expect(
        instant(openAtlantic, DateTime.utc(2026, 3, 28, 10)),
        DateTime.utc(2026, 3, 28, 11),
      );
    });

    test(
      'spring-forward gap rolls forward; fall-back overlap takes daylight time',
      () {
        // 02:30 does not exist on 2026-03-08 in Pacific time: it reads as 03:30 PDT.
        expect(
          instant(monterey, DateTime.utc(2026, 3, 8, 2, 30)),
          DateTime.utc(2026, 3, 8, 10, 30),
        );
        // 01:30 happens twice on 2026-11-01: the first (PDT) occurrence is used.
        expect(
          instant(monterey, DateTime.utc(2026, 11, 1, 1, 30)),
          DateTime.utc(2026, 11, 1, 8, 30),
        );
      },
    );

    test('a local DateTime with the same digits gives the same instant', () {
      expect(
        instant(bonaire, DateTime(2026, 3, 28, 10)),
        instant(bonaire, DateTime.utc(2026, 3, 28, 10)),
      );
    });

    test('wall clock round-trips and crosses the antimeridian', () {
      final wallClock = DateTime.utc(2026, 7, 15, 9, 45);
      final there = instant(sydney, wallClock);
      expect(
        SiteTimeZone.wallClockFromInstant(there, sydney.$1, sydney.$2),
        wallClock,
      );
      expect(
        SiteTimeZone.wallClockFromInstant(
          DateTime.utc(2026, 7, 15),
          fiji.$1,
          fiji.$2,
        ),
        DateTime.utc(2026, 7, 15, 12),
      );
      expect(
        SiteTimeZone.wallClockFromInstant(
          DateTime.utc(2026, 7, 15),
          bonaire.$1,
          bonaire.$2,
        ).isUtc,
        isTrue,
      );
    });

    test('a converter resolved once matches per-call conversion', () {
      final toSite = SiteTimeZone.wallClockConverterFor(
        monterey.$1,
        monterey.$2,
      );
      for (final instant in [
        DateTime.utc(2026, 1, 15, 18),
        DateTime.utc(2026, 7, 15, 17),
        DateTime.utc(2026, 11, 1, 9, 30),
      ]) {
        expect(
          toSite(instant),
          SiteTimeZone.wallClockFromInstant(instant, monterey.$1, monterey.$2),
        );
      }
    });

    test('a zone missing from tzdata falls back to the longitude zone', () {
      SiteTimeZone.debugZoneIdOverride = (_, _) => 'Nope/Zone';
      // Longitude -68.27 rounds to 5 hours west: Etc/GMT+5.
      expect(
        instant(bonaire, DateTime.utc(2026, 3, 28, 10)),
        DateTime.utc(2026, 3, 28, 15),
      );
    });
  });
}
