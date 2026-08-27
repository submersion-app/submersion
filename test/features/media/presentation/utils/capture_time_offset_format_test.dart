import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/presentation/utils/capture_time_offset_format.dart';

void main() {
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
