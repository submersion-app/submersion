import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';

void main() {
  group('DateFormatPreference', () {
    test('ddmmyyyyDots renders a dot-separated example', () {
      expect(DateFormatPreference.ddmmyyyyDots.example, '15.01.2024');
    });

    test(
      'ddmmyyyyDots uses the DD.MM.YYYY display name and dd.MM.yyyy pattern',
      () {
        expect(DateFormatPreference.ddmmyyyyDots.displayName, 'DD.MM.YYYY');
        expect(DateFormatPreference.ddmmyyyyDots.pattern, 'dd.MM.yyyy');
      },
    );

    test('ddmmyyyyDots is day-first', () {
      expect(DateFormatPreference.ddmmyyyyDots.isDayFirst, isTrue);
    });

    test('ddmmyyyyDots round-trips through name-based serialization', () {
      final name = DateFormatPreference.ddmmyyyyDots.name;
      final restored = DateFormatPreference.values.firstWhere(
        (e) => e.name == name,
      );
      expect(restored, DateFormatPreference.ddmmyyyyDots);
    });
  });
}
