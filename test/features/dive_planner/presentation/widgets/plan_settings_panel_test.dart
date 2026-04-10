import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/map_style.dart';
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
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

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

    testWidgets('shows error when reserve exceeds max tank pressure in psi', (
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

      // Default tank is 200 bar ≈ 2901 psi; entering 3000 should error
      final reserveField = find.widgetWithText(TextField, '500');
      await tester.enterText(reserveField, '3000');
      await tester.pumpAndSettle();

      expect(find.textContaining('Exceeds tank pressure'), findsOneWidget);
    });

    testWidgets(
      'no error when reserve equals max tank pressure in psi (2901)',
      (tester) async {
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

        // 200 bar displays as 2901 psi — entering 2901 should be valid
        final reserveField = find.widgetWithText(TextField, '500');
        await tester.enterText(reserveField, '2901');
        await tester.pumpAndSettle();

        expect(find.textContaining('Exceeds tank pressure'), findsNothing);
      },
    );

    testWidgets('shows default assumption message when field cleared in bar', (
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
      await tester.enterText(reserveField, '');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Not entered — assuming 50 bar'),
        findsOneWidget,
      );
    });

    testWidgets('shows default assumption message when field cleared in psi', (
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

      final reserveField = find.widgetWithText(TextField, '500');
      await tester.enterText(reserveField, '');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Not entered — assuming 500 psi'),
        findsOneWidget,
      );
    });
  });

  group('PlanSettingsPanel altitude input', () {
    testWidgets('shows altitude group chip when altitude entered', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 1000m — should be Altitude Group 2 (caution)
      final altitudeField = find.widgetWithText(TextField, '0');
      await tester.enterText(altitudeField, '1000');
      await tester.pumpAndSettle();

      expect(find.text('Altitude Group 2'), findsOneWidget);
      expect(find.textContaining('900-1800m'), findsOneWidget);
    });

    testWidgets('shows warning-level group chip for high altitude', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 2000m — should be Altitude Group 3 (warning)
      final altitudeField = find.widgetWithText(TextField, '0');
      await tester.enterText(altitudeField, '2000');
      await tester.pumpAndSettle();

      expect(find.text('Altitude Group 3'), findsOneWidget);
    });

    testWidgets('shows extreme altitude group chip for very high altitude', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 3000m — should be Extreme Altitude (severe)
      final altitudeField = find.widgetWithText(TextField, '0');
      await tester.enterText(altitudeField, '3000');
      await tester.pumpAndSettle();

      expect(find.text('Extreme Altitude'), findsOneWidget);
    });

    testWidgets('no group chip shown at sea level', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 100m — still sea level group, no chip
      final altitudeField = find.widgetWithText(TextField, '0');
      await tester.enterText(altitudeField, '100');
      await tester.pumpAndSettle();

      expect(find.text('Sea Level'), findsNothing);
      expect(find.text('Altitude Group 1'), findsNothing);
    });

    testWidgets('shows info-level group chip for low altitude', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 500m — should be Altitude Group 1 (info)
      final altitudeField = find.widgetWithText(TextField, '0');
      await tester.enterText(altitudeField, '500');
      await tester.pumpAndSettle();

      expect(find.text('Altitude Group 1'), findsOneWidget);
    });

    testWidgets('clearing altitude text resets to null', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pump();

      final altitudeField = find.widgetWithText(TextField, '0');
      await tester.enterText(altitudeField, '1000');
      await tester.pump();
      expect(find.text('Altitude Group 2'), findsOneWidget);

      // Clear the field
      await tester.enterText(altitudeField, '');
      await tester.pump();
      expect(find.text('Altitude Group 2'), findsNothing);
    });

    testWidgets('compact layout shows group chip', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanSettingsPanel()),
        ),
      );
      await tester.pump();

      final altitudeField = find.widgetWithText(TextField, '0');
      await tester.enterText(altitudeField, '1000');
      await tester.pump();

      expect(find.text('Altitude Group 2'), findsOneWidget);
    });
  });

  group('PlanSettingsPanel layout overflow', () {
    const devices = <String, Size>{
      'Narrow window': Size(300, 600),
      'iPhone SE': Size(375, 667),
      'iPhone 13': Size(390, 844),
      'iPhone 13 Pro Max': Size(428, 926),
      'iPad Mini portrait': Size(744, 1133),
    };

    for (final entry in devices.entries) {
      testWidgets('no overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final overflows = <FlutterErrorDetails>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed')) {
            overflows.add(details);
          } else {
            oldHandler?.call(details);
          }
        };
        addTearDown(() => FlutterError.onError = oldHandler);

        await tester.pumpWidget(
          testApp(
            overrides: [
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: const SingleChildScrollView(child: PlanSettingsPanel()),
          ),
        );
        // Use pump() instead of pumpAndSettle() — Slider tooltip animations
        // prevent settling and cause the 10-minute timeout.
        await tester.pump();

        // Restore before expect so the framework doesn't see a pending override.
        FlutterError.onError = oldHandler;

        expect(overflows, isEmpty, reason: 'Overflow on ${entry.key}');
      });
    }
  });
}
