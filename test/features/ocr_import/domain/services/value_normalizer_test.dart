import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/services/value_normalizer.dart';

void main() {
  group('parseQuantity', () {
    test('explicit metric depth with decimal', () {
      final q = parseQuantity('11.1m');
      expect(q!.value, 11.1);
      expect(q.unit, 'm');
    });

    test('imperial with space', () {
      final q = parseQuantity('60 ft');
      expect(q!.value, 60);
      expect(q.unit, 'ft');
    });

    test('pressure K shorthand expands to thousands, unit unknown', () {
      final q = parseQuantity('3K');
      expect(q!.value, 3000);
      expect(q.unit, isNull);
    });

    test('bar pressure', () {
      final q = parseQuantity('200 bar');
      expect(q!.value, 200);
      expect(q.unit, 'bar');
    });

    test('temperature with degree symbol', () {
      final q = parseQuantity('24°C');
      expect(q!.value, 24);
      expect(q.unit, 'c');
    });

    test('bare number has null unit', () {
      final q = parseQuantity('69');
      expect(q!.value, 69);
      expect(q.unit, isNull);
    });

    test('garbage returns null', () {
      expect(parseQuantity('The Wheel only'), isNull);
    });
  });

  group('parseDateToken', () {
    test('handwritten month name with two-digit year', () {
      expect(
        parseDateToken("6 Feb '06", preferDayFirst: false),
        DateTime(2006, 2, 6),
      );
    });

    test('slash date disambiguated by >12 rule', () {
      // 14 cannot be a month, so this is MM/DD even with preferDayFirst.
      expect(
        parseDateToken('05/14/2023', preferDayFirst: true),
        DateTime(2023, 5, 14),
      );
    });

    test('ambiguous slash date follows preferDayFirst', () {
      expect(
        parseDateToken('05/04/2023', preferDayFirst: true),
        DateTime(2023, 4, 5),
      );
      expect(
        parseDateToken('05/04/2023', preferDayFirst: false),
        DateTime(2023, 5, 4),
      );
    });

    test('day greater than twelve in first position', () {
      expect(
        parseDateToken('14/05/2023', preferDayFirst: false),
        DateTime(2023, 5, 14),
      );
    });

    test('ISO date', () {
      expect(
        parseDateToken('2023-05-14', preferDayFirst: true),
        DateTime(2023, 5, 14),
      );
    });

    test('future dates rejected', () {
      final nextYear = DateTime.now().year + 1;
      expect(parseDateToken('01/01/$nextYear', preferDayFirst: false), isNull);
    });
  });

  group('parseDurationToken', () {
    test('minutes with suffix', () {
      expect(parseDurationToken('45min'), const Duration(minutes: 45));
    });

    test('colon form is hours:minutes', () {
      expect(parseDurationToken('0:32'), const Duration(minutes: 32));
    });

    test('bare number treated as minutes', () {
      expect(parseDurationToken('32'), const Duration(minutes: 32));
    });
  });

  group('parseClockToken', () {
    test('AM shorthand', () {
      expect(parseClockToken('10:00A'), (hour: 10, minute: 0));
    });

    test('PM shorthand adds 12', () {
      expect(parseClockToken('2:15 PM'), (hour: 14, minute: 15));
    });

    test('plain 24h time', () {
      expect(parseClockToken('10:32'), (hour: 10, minute: 32));
    });

    test('rejects impossible time', () {
      expect(parseClockToken('31:00'), isNull);
    });
  });

  group('parseO2Percent', () {
    test('EAN prefix', () => expect(parseO2Percent('EAN32'), 32));
    test('percent form', () => expect(parseO2Percent('32%'), 32));
    test('nitrox word', () => expect(parseO2Percent('Nitrox 32'), 32));
    test(
      'out of range rejected',
      () => expect(parseO2Percent('EAN12'), isNull),
    );
  });
}
