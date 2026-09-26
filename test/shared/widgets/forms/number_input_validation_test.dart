import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  group('readNumber', () {
    test('blank is NumberBlank', () {
      Intl.defaultLocale = 'en_US';
      expect(readNumber('   '), const NumberBlank());
    });

    test('readable text is NumberValue', () {
      Intl.defaultLocale = 'en_US';
      expect(readNumber('14.8'), const NumberValue(14.8));
    });

    test('de corrects a lone wrong separator', () {
      Intl.defaultLocale = 'de';
      expect(readNumber('14.8'), const NumberValue(14.8));
      expect(readNumber('14,8'), const NumberValue(14.8));
    });

    test('de flags genuinely malformed text', () {
      Intl.defaultLocale = 'de';
      expect(readNumber('1.234,5.6'), const NumberInvalid());
      expect(readNumber('abc'), const NumberInvalid());
    });

    test('integer mode rejects a fraction rather than rounding', () {
      Intl.defaultLocale = 'de';
      expect(readNumber('12,5', integer: true), const NumberInvalid());
      expect(readNumber('12', integer: true), const NumberValue(12));
    });
  });

  group('LiveNumber', () {
    test('reports readable values and remembers them', () {
      Intl.defaultLocale = 'en_US';
      final live = LiveNumber(18);
      expect(live.resolve('20'), 20);
      expect(live.resolve('2..0'), 20);
    });

    test('unreadable text before any edit keeps the seeded value', () {
      Intl.defaultLocale = 'en_US';
      expect(LiveNumber(18).resolve('x'), 18);
    });

    test('blank reports the caller-chosen blank value', () {
      Intl.defaultLocale = 'en_US';
      final live = LiveNumber(18);
      expect(live.resolve(''), isNull);
      expect(live.resolve('', blank: 21), 21);
    });

    test('garbage after a clear restores the last readable value, not the '
        'blank value', () {
      Intl.defaultLocale = 'en_US';
      final live = LiveNumber(18);
      live.resolve('25');
      live.resolve('');
      expect(live.resolve('2..5'), 25);
    });

    test('integer mode treats a fraction as unreadable', () {
      Intl.defaultLocale = 'en_US';
      final live = LiveNumber(90, integer: true);
      expect(live.resolve('12.5'), 90);
      expect(live.resolve('120'), 120);
    });
  });

  group('numberValidator', () {
    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        localizedMaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('blank is valid unless required', (tester) async {
      Intl.defaultLocale = 'en_US';
      final context = await pumpContext(tester);
      expect(numberValidator(context)(''), isNull);
      expect(numberValidator(context, required: true)(''), 'Required');
    });

    testWidgets('unreadable text names the separator', (tester) async {
      Intl.defaultLocale = 'en_US';
      final context = await pumpContext(tester);
      expect(
        numberValidator(context)('1.2.3'),
        'Enter a valid number (decimal separator: ".")',
      );
    });

    testWidgets('integer fields ask for a whole number', (tester) async {
      Intl.defaultLocale = 'en_US';
      final context = await pumpContext(tester);
      expect(
        numberValidator(context, integer: true)('12.5'),
        'Enter a whole number',
      );
    });

    testWidgets('check runs only on readable values', (tester) async {
      Intl.defaultLocale = 'en_US';
      final context = await pumpContext(tester);
      final validator = numberValidator(
        context,
        check: (v) => v <= 0 ? 'must be positive' : null,
      );
      expect(validator('-1'), 'must be positive');
      expect(validator('5'), isNull);
      expect(validator(''), isNull);
      expect(validator('x'), startsWith('Enter a valid number'));
    });

    testWidgets('invalidNumberText is null for blank and readable text', (
      tester,
    ) async {
      Intl.defaultLocale = 'en_US';
      final context = await pumpContext(tester);
      expect(invalidNumberText(context, ''), isNull);
      expect(invalidNumberText(context, '3'), isNull);
      expect(invalidNumberText(context, 'x'), isNotNull);
    });
  });
}
