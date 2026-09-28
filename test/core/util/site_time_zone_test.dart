import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/core/util/tz_lookup_data.dart';

void main() {
  tearDown(() => SiteTimeZone.debugZoneIdOverride = null);

  group('SiteTimeZone.zoneIdFor', () {
    final fixture =
        json.decode(
              File(
                p.join(
                  'test',
                  'core',
                  'util',
                  'fixtures',
                  'tz_lookup_parity.json',
                ),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final points = (fixture['points'] as List).cast<Map<String, dynamic>>();

    test('matches upstream tz.js at every fixture point', () {
      expect(points.length, greaterThan(200));
      for (final point in points) {
        expect(
          SiteTimeZone.zoneIdFor(
            (point['lat'] as num).toDouble(),
            (point['lon'] as num).toDouble(),
          ),
          point['zone'],
          reason: '${point['name']} (${point['lat']}, ${point['lon']})',
        );
      }
    });

    test('every lookup zone resolves in the bundled tzdata', () {
      // A zone newer than package:timezone's data would silently fall back
      // to the whole-hour longitude offset; regenerate against both together.
      SiteTimeZone.instantFromWallClock(DateTime.utc(2026), 12.15, -68.27);
      final missing = tzLookupZones.where(
        (zone) => !tz.timeZoneDatabase.locations.containsKey(zone),
      );
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
      expect(
        instant(openAtlantic, DateTime.utc(2026, 3, 28, 10)),
        DateTime.utc(2026, 3, 28, 13),
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
