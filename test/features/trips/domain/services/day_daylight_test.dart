import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/services/day_daylight.dart';

void main() {
  // Dive times are wall clocks flagged as UTC (see `wall_clock_utc.dart`).
  Dive diveAt(DateTime entry, {DiveSite? site, String? id}) =>
      Dive(id: id ?? entry.toIso8601String(), dateTime: entry, site: site);

  DiveSite siteAt(double latitude, double longitude) => DiveSite(
    id: '$latitude,$longitude',
    name: 'Site',
    location: GeoPoint(latitude, longitude),
  );

  // Bonaire on 1 March 2025: sunrise near 06:49, sunset near 18:42.
  final bonaire = siteAt(12.15, -68.27);

  Matcher nearWallClock(DateTime expected) => predicate<DateTime>(
    (actual) => actual.difference(expected).inSeconds.abs() <= 120,
    'within 2 minutes of $expected',
  );

  test("uses the site's sunrise and sunset", () {
    final daylight = computeDayDaylight([
      diveAt(DateTime.utc(2025, 3, 1, 9), site: bonaire),
    ]);
    expect(daylight.basis, DaylightBasis.site);
    expect(daylight.startsInDaylight, isFalse);
    expect(
      daylight.sunrise!.wallClock,
      nearWallClock(DateTime.utc(2025, 3, 1, 6, 49)),
    );
    expect(
      daylight.sunset!.wallClock,
      nearWallClock(DateTime.utc(2025, 3, 1, 18, 42)),
    );
    expect(daylight.sunrise!.fraction, closeTo((6 + 49 / 60) / 24, 0.002));
    expect(daylight.events.map((e) => e.isSunrise), [true, false]);
  });

  test('is a value: the same dives give an equal daylight', () {
    final dives = [diveAt(DateTime.utc(2025, 3, 1, 9), site: bonaire)];
    expect(computeDayDaylight(dives), computeDayDaylight(dives));
    expect(
      computeDayDaylight(dives).sunrise,
      computeDayDaylight(dives).sunrise,
    );
  });

  test('falls back to 06:00 and 18:00 without a placed site', () {
    final daylight = computeDayDaylight([diveAt(DateTime.utc(2025, 3, 1, 9))]);
    expect(daylight.basis, DaylightBasis.fallback);
    expect(daylight.startsInDaylight, isFalse);
    expect(daylight.events.map((e) => e.fraction), [0.25, 0.75]);
    expect(daylight.sunrise, isNull);
    expect(daylight.sunset, isNull);
  });

  test('treats a 0,0 site as unplaced', () {
    final daylight = computeDayDaylight([
      diveAt(DateTime.utc(2025, 3, 1, 9), site: siteAt(0, 0)),
    ]);
    expect(daylight.basis, DaylightBasis.fallback);
  });

  test('uses the first dive that has a placed site', () {
    final daylight = computeDayDaylight([
      diveAt(DateTime.utc(2025, 3, 1, 9), id: 'unplaced'),
      diveAt(DateTime.utc(2025, 3, 1, 14), site: bonaire),
    ]);
    expect(daylight.basis, DaylightBasis.site);
  });

  test('falls back under polar night', () {
    final daylight = computeDayDaylight([
      diveAt(DateTime.utc(2025, 12, 21, 12), site: siteAt(78.22, 15.65)),
    ]);
    expect(daylight.basis, DaylightBasis.fallback);
  });

  test('starts in daylight after a sunset past midnight', () {
    // Tromso, 27 July 2026: the sunset of the 26th falls at about 00:22 on
    // the 27th, the sun rises again at about 01:36, and the 27th's own
    // sunset falls after midnight on the 28th.
    final daylight = computeDayDaylight([
      diveAt(DateTime.utc(2026, 7, 27, 10), site: siteAt(69.65, 18.96)),
    ]);
    expect(daylight.basis, DaylightBasis.site);
    expect(daylight.startsInDaylight, isTrue);
    expect(daylight.events.map((e) => e.isSunrise), [false, true]);
    expect(daylight.sunset!.fraction, lessThan(0.1));
    expect(
      daylight.sunset!.wallClock,
      nearWallClock(DateTime.utc(2026, 7, 27, 0, 22)),
    );
  });

  group('skyStops', () {
    test('builds three stops per event', () {
      final stops = skyStops(
        computeDayDaylight([diveAt(DateTime.utc(2025, 3, 1, 9))]),
      );
      const minute = 1 / 1440;
      final expected = <SkyStop>[
        (fraction: 0, tone: SkyTone.night),
        (fraction: 0.25 - 40 * minute, tone: SkyTone.night),
        (fraction: 0.25, tone: SkyTone.sunriseGlow),
        (fraction: 0.25 + 30 * minute, tone: SkyTone.day),
        (fraction: 0.75 - 30 * minute, tone: SkyTone.day),
        (fraction: 0.75, tone: SkyTone.sunsetGlow),
        (fraction: 0.75 + 40 * minute, tone: SkyTone.night),
        (fraction: 1, tone: SkyTone.night),
      ];
      expect(stops.map((s) => s.tone), expected.map((s) => s.tone));
      for (var i = 0; i < stops.length; i++) {
        expect(stops[i].fraction, closeTo(expected[i].fraction, 1e-9));
      }
    });

    test('are non-decreasing when events crowd together', () {
      final stops = skyStops(
        computeDayDaylight([
          diveAt(DateTime.utc(2026, 7, 27, 10), site: siteAt(69.65, 18.96)),
        ]),
      );
      expect(stops.first.tone, SkyTone.day);
      expect(stops.last.tone, SkyTone.day);
      for (var i = 1; i < stops.length; i++) {
        expect(stops[i].fraction, greaterThanOrEqualTo(stops[i - 1].fraction));
      }
    });
  });
}
