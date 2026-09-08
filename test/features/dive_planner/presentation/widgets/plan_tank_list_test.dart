import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier({
    PressureUnit pressureUnit = PressureUnit.bar,
    VolumeUnit volumeUnit = VolumeUnit.liters,
  }) : super(AppSettings(pressureUnit: pressureUnit, volumeUnit: volumeUnit));

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

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

  group('PlanTankList travel gas checkbox', () {
    testWidgets('saves isTravelGas when the checkbox is checked', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanTankList()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      final addedTank = container.read(divePlanNotifierProvider).tanks.last;
      expect(addedTank.isTravelGas, isTrue);
    });

    testWidgets('shows the existing value when editing a travel-gas tank', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanTankList()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      final addedTank = container.read(divePlanNotifierProvider).tanks.last;

      await tester.tap(
        find.widgetWithText(InputChip, addedTank.gasMix.name).last,
      );
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isTrue);
    });
  });
  group('PlanTankList bailout checkbox', () {
    Future<ProviderContainer> pumpList(
      WidgetTester tester, {
      required PlanMode mode,
    }) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanTankList()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      container.read(divePlanNotifierProvider.notifier).updateMode(mode);
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('is absent on open circuit, where nothing is bailout', (
      tester,
    ) async {
      await pumpList(tester, mode: PlanMode.oc);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Bailout gas'), findsNothing);
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('on CCR, ticking it saves the tank with the bailout role', (
      tester,
    ) async {
      final container = await pumpList(tester, mode: PlanMode.ccr);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(CheckboxListTile, 'Bailout gas');
      expect(tile, findsOneWidget);
      expect(
        find.text('Open-circuit gas carried in case the loop fails'),
        findsOneWidget,
      );
      expect(tester.widget<CheckboxListTile>(tile).value, isFalse);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(tile).value, isTrue);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final addedTank = container.read(divePlanNotifierProvider).tanks.last;
      expect(addedTank.role, TankRole.bailout);
      expect(addedTank.isTravelGas, isFalse);
    });

    testWidgets('on SCR, an unticked tile leaves the role to be derived', (
      tester,
    ) async {
      final container = await pumpList(tester, mode: PlanMode.scr);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      final tile = find.widgetWithText(CheckboxListTile, 'Bailout gas');
      expect(tile, findsOneWidget);

      // Tick and untick: the checkbox round-trips.
      await tester.tap(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(tile).value, isFalse);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final addedTank = container.read(divePlanNotifierProvider).tanks.last;
      expect(addedTank.role, TankRole.backGas);
    });

    testWidgets('editing a bailout tank shows the tile already ticked', (
      tester,
    ) async {
      final container = await pumpList(tester, mode: PlanMode.ccr);
      container
          .read(divePlanNotifierProvider.notifier)
          .addTank(
            const DiveTank(
              id: 'bo',
              name: 'Bailout 50',
              volume: 11.1,
              startPressure: 200,
              gasMix: GasMix(o2: 50, he: 0),
              role: TankRole.bailout,
              order: 1,
            ),
          );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InputChip, 'Bailout 50'));
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(CheckboxListTile, 'Bailout gas');
      expect(tester.widget<CheckboxListTile>(tile).value, isTrue);
    });
  });
}
