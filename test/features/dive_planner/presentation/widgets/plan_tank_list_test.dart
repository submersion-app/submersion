import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier({
    PressureUnit pressureUnit = PressureUnit.bar,
    VolumeUnit volumeUnit = VolumeUnit.liters,
  }) : super(AppSettings(pressureUnit: pressureUnit, volumeUnit: volumeUnit));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PlanTankList tank dialog pressure unit', () {
    testWidgets('saves start pressure converted to bar when unit is psi', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(pressureUnit: PressureUnit.psi),
            ),
          ],
          child: const SingleChildScrollView(child: PlanTankList()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the add-tank button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Find the start pressure field by its label and enter 3000 psi
      final pressureField = find.widgetWithText(TextField, 'Start (psi)');
      await tester.enterText(pressureField, '3000');

      // Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The newly added tank should have ~207 bar (3000 / 14.5038)
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      final tanks = container.read(divePlanNotifierProvider).tanks;
      final addedTank = tanks.last;
      expect(addedTank.startPressure, closeTo(207, 1));
    });
  });

  group('PlanTankList tank dialog volume unit', () {
    testWidgets('saves volume converted to liters when unit is cuft', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(volumeUnit: VolumeUnit.cubicFeet),
            ),
          ],
          child: const SingleChildScrollView(child: PlanTankList()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the add-tank button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Find the volume field and enter 80 cuft
      final volumeField = find.widgetWithText(TextField, 'Volume (cuft)');
      await tester.enterText(volumeField, '80');

      // Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // 80 cuft should be stored as ~2265 liters (80 / 0.0353147)
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      final tanks = container.read(divePlanNotifierProvider).tanks;
      final addedTank = tanks.last;
      expect(addedTank.volume, closeTo(80 / 0.0353147, 1));
    });
  });

  group('PlanTankList edit dialog displays converted values', () {
    testWidgets('shows existing pressure in psi and volume in cuft', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(
                pressureUnit: PressureUnit.psi,
                volumeUnit: VolumeUnit.cubicFeet,
              ),
            ),
          ],
          child: const SingleChildScrollView(child: PlanTankList()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the default "Primary" tank chip to open edit dialog
      await tester.tap(find.widgetWithText(InputChip, 'Primary'));
      await tester.pumpAndSettle();

      // Default tank: startPressure=200 bar -> ~2901 psi
      final pressureField = find.widgetWithText(TextField, 'Start (psi)');
      final pressureController = (tester.widget<TextField>(
        pressureField,
      )).controller!;
      expect(int.parse(pressureController.text), closeTo(2901, 1));

      // Default tank: volume=11.1 L -> ~0.4 cuft
      final volumeField = find.widgetWithText(TextField, 'Volume (cuft)');
      final volumeController = (tester.widget<TextField>(
        volumeField,
      )).controller!;
      expect(double.parse(volumeController.text), closeTo(0.4, 0.1));
    });
  });
}
