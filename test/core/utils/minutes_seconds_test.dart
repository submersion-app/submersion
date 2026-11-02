import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/minutes_seconds.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

void main() {
  group('parseMinutesSeconds', () {
    test('reads minutes and seconds, or bare minutes', () {
      expect(parseMinutesSeconds('12:30'), 750);
      expect(parseMinutesSeconds('7'), 420);
      expect(parseMinutesSeconds('1:7'), 67);
    });

    test('refuses text that is not a time', () {
      expect(parseMinutesSeconds('ab'), isNull);
      expect(parseMinutesSeconds('1:60'), isNull);
      expect(parseMinutesSeconds(''), isNull);
    });

    test('refuses a minutes run too long to be a time', () {
      // Past int.parse's range, and past what times 60 can hold: both read
      // as "not a time" rather than throwing or wrapping negative.
      expect(parseMinutesSeconds('99999999999999999999'), isNull);
      expect(parseMinutesSeconds('9223372036854775807'), isNull);
      expect(parseMinutesSeconds('99999'), 99999 * 60);
    });
  });

  group('formatMinutesSeconds', () {
    test('pads the seconds', () {
      expect(formatMinutesSeconds(750), '12:30');
      expect(formatMinutesSeconds(67), '1:07');
      expect(formatMinutesSeconds(0), '0:00');
    });

    test('is the shape a gas switch formats its own time in', () {
      final gasSwitch = GasSwitch(
        id: 'gs',
        diveId: 'dive',
        timestamp: 67,
        tankId: 'tank',
        createdAt: DateTime.utc(2026),
      );
      expect(gasSwitch.timestampFormatted, formatMinutesSeconds(67));
    });
  });
}
