import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/conditions_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';

void main() {
  Widget host({
    required List<Widget> topRows,
    required List<Widget> weatherRows,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConditionsSection(
            expanded: true,
            onToggle: () {},
            summary: '',
            isEmpty: true,
            temperatureSymbol: 'C',
            waterTempController: TextEditingController(),
            airTempController: TextEditingController(),
            topRows: topRows,
            environmentRows: const [],
            weatherRows: weatherRows,
          ),
        ),
      ),
    );
  }

  testWidgets('renders topRows above the temperature fields', (tester) async {
    await tester.pumpWidget(
      host(
        topRows: [
          FormOverline(
            label: 'Auto-fill',
            actions: [
              FormOverlineAction(label: 'Fetch weather', onPressed: () {}),
            ],
          ),
        ],
        weatherRows: const [FormOverline(label: 'Weather')],
      ),
    );
    await tester.pumpAndSettle();

    // FormRow.text stays collapsed until tapped, so anchor the ordering on
    // the water temperature row's label rather than a materialized TextField.
    final autofillY = tester.getTopLeft(find.text('AUTO-FILL')).dy;
    final weatherY = tester.getTopLeft(find.text('WEATHER')).dy;
    final waterTempY = tester.getTopLeft(find.text('Water Temp')).dy;

    expect(find.text('Fetch weather'), findsOneWidget);
    expect(autofillY, lessThan(waterTempY));
    expect(waterTempY, lessThan(weatherY));
  });

  testWidgets('topRows defaults to empty and renders nothing extra', (
    tester,
  ) async {
    await tester.pumpWidget(host(topRows: const [], weatherRows: const []));
    await tester.pumpAndSettle();

    expect(find.byType(FormOverline), findsNothing);
  });
}
