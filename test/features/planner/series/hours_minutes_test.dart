import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/utils/hours_minutes.dart';

void main() {
  group('formatHoursMinutes', () {
    test('pads the minutes and lets the hours run past a day', () {
      expect(formatHoursMinutes(const Duration(hours: 1)), '1:00');
      expect(formatHoursMinutes(const Duration(minutes: 5)), '0:05');
      expect(
        formatHoursMinutes(const Duration(hours: 20, minutes: 10)),
        '20:10',
      );
      expect(formatHoursMinutes(const Duration(hours: 26)), '26:00');
    });
  });

  group('parseHoursMinutes', () {
    test('reads h:mm, :mm and bare hours', () {
      expect(parseHoursMinutes('1:30'), const Duration(minutes: 90));
      expect(parseHoursMinutes('0:05'), const Duration(minutes: 5));
      expect(parseHoursMinutes(':45'), const Duration(minutes: 45));
      expect(parseHoursMinutes('2'), const Duration(hours: 2));
      expect(parseHoursMinutes(' 1 : 5 '), const Duration(minutes: 65));
    });

    test('rejects anything else', () {
      expect(parseHoursMinutes(''), isNull);
      expect(parseHoursMinutes(':'), isNull);
      expect(parseHoursMinutes('1:60'), isNull);
      expect(parseHoursMinutes('-1:00'), isNull);
      expect(parseHoursMinutes('1h'), isNull);
      expect(parseHoursMinutes('1:2:3'), isNull);
      expect(parseHoursMinutes('99999999999999999999999'), isNull);
    });

    test('reads the most hours a dive can follow, and no more', () {
      expect(parseHoursMinutes('999999'), const Duration(hours: 999999));
      expect(parseHoursMinutes('1000000'), isNull);
      expect(parseHoursMinutes('99999999999999999999'), isNull);
      expect(parseHoursMinutes('9999999999999:00'), isNull);
    });
  });
}
