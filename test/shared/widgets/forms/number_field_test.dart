import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  Future<List<NumberRead>> pump(
    WidgetTester tester, {
    GlobalKey<FormState>? formKey,
    bool integer = false,
  }) async {
    final reads = <NumberRead>[];
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: Form(
            key: formKey,
            child: NumberField(
              controller: controller,
              integer: integer,
              onChanged: reads.add,
            ),
          ),
        ),
      ),
    );
    return reads;
  }

  testWidgets('reports values and shows no error for readable text', (
    tester,
  ) async {
    Intl.defaultLocale = 'en_US';
    final reads = await pump(tester);
    await tester.enterText(find.byType(TextFormField), '12.5');
    await tester.pump();
    expect(reads.last, const NumberValue(12.5));
    expect(find.textContaining('Enter a valid number'), findsNothing);
  });

  testWidgets('shows the error and reports NumberInvalid for garbage', (
    tester,
  ) async {
    Intl.defaultLocale = 'en_US';
    final reads = await pump(tester);
    await tester.enterText(find.byType(TextFormField), '1.2.3');
    await tester.pump();
    expect(reads.last, const NumberInvalid());
    expect(
      find.text('Enter a valid number (decimal separator: ".")'),
      findsOneWidget,
    );
  });

  testWidgets('blocks Form.validate while unreadable', (tester) async {
    Intl.defaultLocale = 'en_US';
    final formKey = GlobalKey<FormState>();
    await pump(tester, formKey: formKey);
    await tester.enterText(find.byType(TextFormField), '1.2.3');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(TextFormField), '');
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('integer field asks for a whole number', (tester) async {
    Intl.defaultLocale = 'en_US';
    final reads = await pump(tester, integer: true);
    await tester.enterText(find.byType(TextFormField), '12.5');
    await tester.pump();
    expect(reads.last, const NumberInvalid());
    expect(find.text('Enter a whole number'), findsOneWidget);
  });

  testWidgets('lets the error wrap rather than cutting off the separator '
      'hint in a narrow field', (tester) async {
    Intl.defaultLocale = 'en_US';
    await pump(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.errorMaxLines, 3);
  });

  testWidgets('filters out letters', (tester) async {
    Intl.defaultLocale = 'en_US';
    final reads = await pump(tester);
    await tester.enterText(find.byType(TextFormField), '1a2');
    await tester.pump();
    expect(reads.last, const NumberValue(12));
  });

  group('numberInputFormatters', () {
    String filter(String text, {bool allowNegative = false}) {
      var value = TextEditingValue(text: text);
      for (final f in numberInputFormatters(allowNegative: allowNegative)) {
        value = f.formatEditUpdate(TextEditingValue.empty, value);
      }
      return value.text;
    }

    test('keeps the locale\'s own separators, so validation sees them '
        '(#1900 review)', () {
      Intl.defaultLocale = 'ar_EG';
      // Stripping U+066B would turn "1٫3" into 13 without a word.
      expect(filter('1\u066B3'), '1\u066B3');
      Intl.defaultLocale = 'fr';
      expect(filter('1\u202F250,5'), '1\u202F250,5');
    });

    test('keeps the locale minus sign, direction mark included', () {
      Intl.defaultLocale = 'he';
      expect(filter('\u200E-5', allowNegative: true), '\u200E-5');
      expect(filter('\u200E-5'), '5');
    });

    test('still drops letters', () {
      Intl.defaultLocale = 'en_US';
      expect(filter('1a2'), '12');
    });
  });
}
