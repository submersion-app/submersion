import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/presentation/utils/capture_time_offset_format.dart';

void main() {
  group('formatShiftMagnitude', () {
    test('reads as minutes:seconds under an hour', () {
      expect(formatShiftMagnitude(0), '0:00');
      expect(formatShiftMagnitude(87), '1:27');
      expect(formatShiftMagnitude(3599), '59:59');
    });

    test('drops the sign', () {
      expect(formatShiftMagnitude(-87), '1:27');
      expect(formatShiftMagnitude(-21600), '6h 00m');
    });

    // A camera left on another time zone.
    test('rolls into hours from an hour up', () {
      expect(formatShiftMagnitude(3600), '1h 00m');
      expect(formatShiftMagnitude(21600), '6h 00m');
      expect(formatShiftMagnitude(21612), '6h 00m 12s');
    });

    // A camera on another date, or an item with no real capture time: the
    // amount has to read as days, not as a six-digit count of minutes.
    test('rolls into days from a day up', () {
      expect(formatShiftMagnitude(86400), '1d 0h 00m');
      expect(formatShiftMagnitude(90061), '1d 1h 01m 01s');
      expect(formatShiftMagnitude(3652 * 86400), '3652d 0h 00m');
    });
  });

  group('formatSignedOffset', () {
    test('zero has no sign', () {
      expect(formatSignedOffset(Duration.zero), '0m');
    });

    test('positive whole hours pad the minutes', () {
      expect(formatSignedOffset(const Duration(hours: 5)), '+5h 00m');
    });

    test('negative offsets keep the sign on the hours', () {
      expect(
        formatSignedOffset(const Duration(hours: -1, minutes: -15)),
        '-1h 15m',
      );
    });

    test('sub-hour offsets omit the hour part', () {
      expect(formatSignedOffset(const Duration(minutes: 45)), '+45m');
      expect(formatSignedOffset(const Duration(minutes: -15)), '-15m');
    });
  });

  group('formatOffsetMagnitude', () {
    test('drops the sign', () {
      expect(
        formatOffsetMagnitude(const Duration(hours: -3, minutes: -38)),
        '3h 38m',
      );
      expect(
        formatOffsetMagnitude(const Duration(hours: 3, minutes: 38)),
        '3h 38m',
      );
    });

    test('sub-hour magnitudes omit the hour part', () {
      expect(formatOffsetMagnitude(const Duration(minutes: -45)), '45m');
    });

    test('a whole hour pads its minutes', () {
      expect(formatOffsetMagnitude(const Duration(hours: 1)), '1h 00m');
    });
  });
}
