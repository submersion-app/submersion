import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_settings_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// Minimal [SettingsNotifier] stub. Uses [noSuchMethod] so we don't have to
/// implement every setter on the real notifier.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier({PressureUnit pressureUnit = PressureUnit.bar})
    : super(AppSettings(pressureUnit: pressureUnit));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PlanSettingsPanel reserve pressure field', () {
    testWidgets('displays reserve pressure field with bar unit for metric', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reserve:'), findsOneWidget);
      expect(find.text('bar'), findsOneWidget);
    });

    testWidgets('displays reserve pressure field with psi unit for imperial', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(pressureUnit: PressureUnit.psi),
            ),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reserve:'), findsOneWidget);
      expect(find.text('psi'), findsOneWidget);
    });

    testWidgets('defaults to 50 when pressure unit is bar', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, '50'),
      );
      expect(textField.controller?.text, '50');
    });

    testWidgets('defaults to 500 when pressure unit is psi', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(pressureUnit: PressureUnit.psi),
            ),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, '500'),
      );
      expect(textField.controller?.text, '500');
    });
  });
}
