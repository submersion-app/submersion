import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

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
  DateTime deviceWallClock(DateTime instant) {
    final local = instant.toLocal();
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

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
          'America/Curacao',
        ),
        DateTime.utc(2026, 9, 15, 11, 54),
      );
    });

    test('applies daylight saving for the dive date', () {
      const zone = 'America/Los_Angeles';
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
          'America/Curacao',
        ),
        DateTime.utc(2026, 9, 15, 22, 30),
      );
    });

    test('leaves a GMT dive unchanged', () {
      final instant = DateTime.utc(2025, 3, 1, 9, 15);
      expect(MacDiveTimeZone.toWallClockUtc(instant, 'GMT'), instant);
    });

    test('falls back to the device zone when the dive has no zone', () {
      final instant = DateTime.utc(2025, 6, 1, 12);
      expect(
        MacDiveTimeZone.toWallClockUtc(instant, null),
        deviceWallClock(instant),
      );
    });

    test('falls back to the device zone for an unknown zone name', () {
      final instant = DateTime.utc(2025, 6, 1, 12);
      expect(
        MacDiveTimeZone.toWallClockUtc(instant, 'Not/AZone'),
        deviceWallClock(instant),
      );
    });

    test('applies daylight saving for a zone found from a site', () {
      // A Maine dive: EDT (UTC-4) in July, EST (UTC-5) in January.
      final zone = MacDiveTimeZone.nameForLocation(43.179, -70.602);
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
          'America/Curacao',
        ).isUtc,
        isTrue,
      );
    });
  });
}
