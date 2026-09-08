import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_mix_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// [BlenderMixRow.errorText] reports one condition only: an O2/He pair that is
/// not a valid mix. The row's other fields (pressure, and the optional price)
/// have nothing to do with that, so the message must not be repeated under
/// them -- three copies of "invalid mix" would read as three separate problems.
void main() {
  const mixError = 'O2 and He must not exceed 100%';

  Future<void> pumpRow(
    WidgetTester tester, {
    required bool withPressure,
    String? errorText,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlenderMixRow(
            pressureSymbol: 'bar',
            pressureController: withPressure
                ? TextEditingController(text: '200')
                : null,
            onPressure: withPressure ? (_) {} : null,
            o2Controller: TextEditingController(text: '80'),
            heController: TextEditingController(text: '80'),
            onMix: () {},
            errorText: errorText,
            priceController: TextEditingController(text: '1.20'),
            priceLabel: 'Price',
            onPriceChanged: (_) {},
          ),
        ),
      ),
    );
  }

  /// The decoration each field was built with, keyed by its label.
  Map<String, String?> errorsByLabel(WidgetTester tester) {
    return {
      for (final field in tester.widgetList<TextField>(find.byType(TextField)))
        field.decoration!.labelText!: field.decoration!.errorText,
    };
  }

  testWidgets('shows the mix error under O2 and He only', (tester) async {
    await pumpRow(tester, withPressure: true, errorText: mixError);

    expect(errorsByLabel(tester), {
      'Pressure (bar)': null,
      'O₂ (%)': mixError,
      'He (%)': mixError,
      'Price': null,
    });
    expect(find.text(mixError), findsNWidgets(2));
  });

  testWidgets('shows no error text anywhere when the mix is valid', (
    tester,
  ) async {
    await pumpRow(tester, withPressure: true);

    expect(
      errorsByLabel(tester).values.every((error) => error == null),
      isTrue,
    );
  });

  testWidgets('still scopes the error to O2/He without a pressure field', (
    tester,
  ) async {
    await pumpRow(tester, withPressure: false, errorText: mixError);

    expect(errorsByLabel(tester), {
      'O₂ (%)': mixError,
      'He (%)': mixError,
      'Price': null,
    });
  });
}
