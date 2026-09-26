import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_field_parsing.dart';

void main() {
  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  group('mixPercentOrKeep', () {
    test('reads a typed percentage', () {
      expect(mixPercentOrKeep('32', 21), 32);
    });

    test('keeps the previous percentage for blank or unreadable text', () {
      expect(mixPercentOrKeep('', 21), 21);
      expect(mixPercentOrKeep('3..2', 21), 21);
    });
  });

  group('pressureOrKeep', () {
    test('reads a typed pressure', () {
      expect(pressureOrKeep('200'), 200);
    });

    test('blank is an empty cylinder', () {
      expect(pressureOrKeep(''), 0);
    });

    test(
      'unreadable text is null so the caller keeps its pressure (#1900)',
      () {
        // It used to read as 0 bar: a mistyped fill pressure silently became
        // an empty cylinder while the field showed its error.
        expect(pressureOrKeep('2..00'), isNull);
      },
    );
  });
}
