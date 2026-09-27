import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/macdive_time_zone.dart';

void main() {
  late Uint8List losAngelesBplist;

  setUpAll(() async {
    // Real MacDive ZTIMEZONE BLOB: an NSKeyedArchiver-encoded NSTimeZone
    // whose NS.name is America/Los_Angeles.
    losAngelesBplist = Uint8List.fromList(
      await File(
        'test/fixtures/macdive_sqlite/bplist_samples/macdive_ztimezone.bplist',
      ).readAsBytes(),
    );
  });

  /// The wall-clock digits [instant] shows on the device running the test,
  /// as wall-clock-UTC. Keeps the fallback assertions independent of the
  /// machine's zone.
  DateTime deviceWallClock(DateTime instant) =>
      asWallClockUtc(instant.toLocal());

  group('MacDiveTimeZone.nameFromBplist', () {
    test('reads NS.name from a real MacDive ZTIMEZONE BLOB', () {
      expect(
        MacDiveTimeZone.nameFromBplist(losAngelesBplist),
        'America/Los_Angeles',
      );
    });

    test('returns null for a missing BLOB', () {
      expect(MacDiveTimeZone.nameFromBplist(null), isNull);
    });

    test('returns null for bytes that are not a bplist', () {
      expect(
        MacDiveTimeZone.nameFromBplist(Uint8List.fromList([1, 2, 3, 4])),
        isNull,
      );
    });

    test('returns null for a corrupt archive rather than throwing', () {
      // A zero reference size in the trailer makes every reference point
      // at the root, which the decoder used to follow until the stack
      // overflowed, aborting the whole import.
      final corrupt = Uint8List.fromList(losAngelesBplist);
      corrupt[corrupt.length - 32 + 7] = 0;
      expect(MacDiveTimeZone.nameFromBplist(corrupt), isNull);
    });
  });

  group('MacDiveTimeZone.locationNamed', () {
    test('resolves an IANA zone name', () {
      expect(
        MacDiveTimeZone.locationNamed('America/Los_Angeles')?.name,
        'America/Los_Angeles',
      );
    });

    test('resolves the fixed-offset names NSTimeZone archives', () {
      // `NSTimeZone(forSecondsFromGMT:)` is named like this, and the tz
      // database has no such zones.
      final instant = DateTime.utc(2025, 6, 1, 12);
      expect(
        MacDiveTimeZone.toWallClockUtc(
          instant,
          MacDiveTimeZone.locationNamed('GMT+0100'),
        ),
        DateTime.utc(2025, 6, 1, 13),
      );
      expect(
        MacDiveTimeZone.toWallClockUtc(
          instant,
          MacDiveTimeZone.locationNamed('GMT-0530'),
        ),
        DateTime.utc(2025, 6, 1, 6, 30),
      );
      expect(
        MacDiveTimeZone.toWallClockUtc(
          instant,
          MacDiveTimeZone.locationNamed('GMT+05:45'),
        ),
        DateTime.utc(2025, 6, 1, 17, 45),
      );
    });

    test('returns null for a name it cannot resolve', () {
      expect(MacDiveTimeZone.locationNamed(null), isNull);
      expect(MacDiveTimeZone.locationNamed(''), isNull);
      expect(MacDiveTimeZone.locationNamed('Not/AZone'), isNull);
      expect(MacDiveTimeZone.locationNamed('unknown'), isNull);
      expect(MacDiveTimeZone.locationNamed('GMT+2500'), isNull);
      expect(MacDiveTimeZone.locationNamed('GMT+0175'), isNull);
    });
  });

  group('MacDiveTimeZone.nameForLocation', () {
    test('finds the zone of a dive site from its coordinates', () {
      // Eden Rock, Grand Cayman; Gull Rock, Maine; Moorea, French Polynesia.
      expect(
        MacDiveTimeZone.nameForLocation(19.293, -81.388),
        'America/Cayman',
      );
      expect(
        MacDiveTimeZone.nameForLocation(43.179, -70.602),
        'America/New_York',
      );
      expect(
        MacDiveTimeZone.nameForLocation(-17.536, -149.829),
        'Pacific/Tahiti',
      );
    });

    test('returns null without coordinates', () {
      expect(MacDiveTimeZone.nameForLocation(null, null), isNull);
      expect(MacDiveTimeZone.nameForLocation(43.179, null), isNull);
    });

    test('returns null for the 0,0 stand-in for "no GPS set"', () {
      expect(MacDiveTimeZone.nameForLocation(0, 0), isNull);
    });
  });

  group('MacDiveTimeZone.toWallClockUtc', () {
    test('shifts the absolute instant into the dive zone', () {
      // Curacao is UTC-4 year round: 15:54Z was 11:54 on the diver's watch.
      expect(
        MacDiveTimeZone.toWallClockUtc(
          DateTime.utc(2026, 9, 15, 15, 54),
          MacDiveTimeZone.locationNamed('America/Curacao'),
        ),
        DateTime.utc(2026, 9, 15, 11, 54),
      );
    });

    test('applies daylight saving for the dive date', () {
      final zone = MacDiveTimeZone.locationNamed('America/Los_Angeles');
      expect(
        MacDiveTimeZone.toWallClockUtc(DateTime.utc(2024, 7, 1, 17), zone),
        DateTime.utc(2024, 7, 1, 10),
        reason: 'PDT is UTC-7',
      );
      expect(
        MacDiveTimeZone.toWallClockUtc(DateTime.utc(2024, 1, 15, 18), zone),
        DateTime.utc(2024, 1, 15, 10),
        reason: 'PST is UTC-8',
      );
    });

    test('rolls the calendar day back when the offset crosses midnight', () {
      expect(
        MacDiveTimeZone.toWallClockUtc(
          DateTime.utc(2026, 9, 16, 2, 30),
          MacDiveTimeZone.locationNamed('America/Curacao'),
        ),
        DateTime.utc(2026, 9, 15, 22, 30),
      );
    });

    test('leaves a GMT dive unchanged', () {
      final instant = DateTime.utc(2025, 3, 1, 9, 15);
      expect(
        MacDiveTimeZone.toWallClockUtc(
          instant,
          MacDiveTimeZone.locationNamed('GMT'),
        ),
        instant,
      );
    });

    test('falls back to the device zone when the dive has no zone', () {
      final instant = DateTime.utc(2025, 6, 1, 12);
      expect(
        MacDiveTimeZone.toWallClockUtc(instant, null),
        deviceWallClock(instant),
      );
    });

    test('applies daylight saving for a zone found from a site', () {
      // A Maine dive: EDT (UTC-4) in July, EST (UTC-5) in January.
      final zone = MacDiveTimeZone.locationNamed(
        MacDiveTimeZone.nameForLocation(43.179, -70.602),
      );
      expect(
        MacDiveTimeZone.toWallClockUtc(DateTime.utc(2012, 7, 14, 14), zone),
        DateTime.utc(2012, 7, 14, 10),
      );
      expect(
        MacDiveTimeZone.toWallClockUtc(DateTime.utc(2012, 1, 14, 15), zone),
        DateTime.utc(2012, 1, 14, 10),
      );
    });

    test('returns a UTC DateTime', () {
      expect(
        MacDiveTimeZone.toWallClockUtc(
          DateTime.utc(2026, 9, 15, 15, 54),
          MacDiveTimeZone.locationNamed('America/Curacao'),
        ).isUtc,
        isTrue,
      );
    });
  });
  group('MacDiveZoneResolver', () {
    const tahiti = MacDiveRawSite(
      pk: 7,
      uuid: 'site-7',
      latitude: -17.536,
      longitude: -149.829,
    );
    // 12:00Z: 05:00 PDT, 02:00 in Tahiti.
    final instant = DateTime.utc(2024, 7, 1, 12);

    test('uses the stored zone first', () {
      final zones = MacDiveZoneResolver();
      expect(
        zones.wallClockUtc(instant, archive: losAngelesBplist, site: tahiti),
        DateTime.utc(2024, 7, 1, 5),
      );
      expect(zones.deviceZoneDives, 0);
    });

    test('falls back to the site zone when there is no stored zone', () {
      final zones = MacDiveZoneResolver();
      expect(
        zones.wallClockUtc(instant, site: tahiti),
        DateTime.utc(2024, 7, 1, 2),
      );
      expect(zones.deviceZoneDives, 0);
    });

    test('falls back to the site zone when the stored zone is unreadable', () {
      final zones = MacDiveZoneResolver();
      expect(
        zones.wallClockUtc(
          instant,
          archive: Uint8List.fromList([1, 2, 3, 4]),
          site: tahiti,
        ),
        DateTime.utc(2024, 7, 1, 2),
      );
    });

    test('uses the device zone, and counts the dive, with neither', () {
      final zones = MacDiveZoneResolver();
      const noFix = MacDiveRawSite(pk: 8, uuid: 'site-8', name: 'Somewhere');
      expect(zones.wallClockUtc(instant), deviceWallClock(instant));
      expect(
        zones.wallClockUtc(instant, site: noFix),
        deviceWallClock(instant),
      );
      expect(zones.deviceZoneDives, 2);
    });

    test('gives the same answer for a repeated archive and site', () {
      // Every dive in a logbook carries its own copy of the archive, and
      // most sites are shared by several dives; both are resolved once.
      final zones = MacDiveZoneResolver();
      final copy = Uint8List.fromList(losAngelesBplist);
      final first = zones.wallClockUtc(instant, archive: losAngelesBplist);
      expect(zones.wallClockUtc(instant, archive: copy), first);
      expect(
        zones.wallClockUtc(instant, site: tahiti),
        zones.wallClockUtc(instant, site: tahiti),
      );
    });
  });
}
