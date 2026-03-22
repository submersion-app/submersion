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

  group('PlanSettingsPanel reserve pressure validation', () {
    testWidgets('shows error when reserve pressure is 0', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pumpAndSettle();

      // Clear and enter 0
      final reserveField = find.widgetWithText(TextField, '50');
      await tester.enterText(reserveField, '0');
      await tester.pumpAndSettle();

      // Should show error text
      expect(find.textContaining('Must be greater than 0'), findsOneWidget);
    });

    testWidgets('shows error when reserve pressure is negative', (
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

      final reserveField = find.widgetWithText(TextField, '50');
      await tester.enterText(reserveField, '-10');
      await tester.pumpAndSettle();

      expect(find.textContaining('Must be greater than 0'), findsOneWidget);
    });

    testWidgets('shows error when reserve exceeds max tank pressure in bar', (
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

      // Default tank startPressure is 200 bar; entering 201 should error
      final reserveField = find.widgetWithText(TextField, '50');
      await tester.enterText(reserveField, '201');
      await tester.pumpAndSettle();

      expect(find.textContaining('Exceeds tank pressure'), findsOneWidget);
    });

    testWidgets('no error when reserve equals max tank pressure in bar', (
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

      // 200 bar is exactly the tank's startPressure — should be valid
      final reserveField = find.widgetWithText(TextField, '50');
      await tester.enterText(reserveField, '200');
      await tester.pumpAndSettle();

      expect(find.textContaining('Must be greater than 0'), findsNothing);
      expect(find.textContaining('Exceeds tank pressure'), findsNothing);
    });

    testWidgets('no error for valid reserve pressure', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pumpAndSettle();

      final reserveField = find.widgetWithText(TextField, '50');
      await tester.enterText(reserveField, '30');
      await tester.pumpAndSettle();

      expect(find.textContaining('Must be greater than 0'), findsNothing);
      expect(find.textContaining('Exceeds tank pressure'), findsNothing);
    });

    testWidgets(
      'shows error when reserve exceeds max tank pressure in psi',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            overrides: [
              settingsProvider.overrideWith(
                (ref) =>
                    _TestSettingsNotifier(pressureUnit: PressureUnit.psi),
              ),
            ],
            child: const SingleChildScrollView(child: PlanSettingsPanel()),
          ),
        );
        await tester.pumpAndSettle();

        // Default tank is 200 bar ≈ 2901 psi; entering 3000 should error
        final reserveField = find.widgetWithText(TextField, '500');
        await tester.enterText(reserveField, '3000');
        await tester.pumpAndSettle();

        expect(find.textContaining('Exceeds tank pressure'), findsOneWidget);
      },
    );

    testWidgets(
      'no error when reserve equals max tank pressure in psi (2901)',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            overrides: [
              settingsProvider.overrideWith(
                (ref) =>
                    _TestSettingsNotifier(pressureUnit: PressureUnit.psi),
              ),
            ],
            child: const SingleChildScrollView(child: PlanSettingsPanel()),
          ),
        );
        await tester.pumpAndSettle();

        // 200 bar displays as 2901 psi — entering 2901 should be valid
        final reserveField = find.widgetWithText(TextField, '500');
        await tester.enterText(reserveField, '2901');
        await tester.pumpAndSettle();

        expect(find.textContaining('Exceeds tank pressure'), findsNothing);
      },
    );
  });
}
