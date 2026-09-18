import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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
  // parseUserDecimal and the field seeding read the process-global
  // Intl.defaultLocale, which MaterialApp.locale does not set and which leaks
  // across tests in an isolate. Pin it so "77.4" always parses as a dot
  // decimal, and restore it afterwards.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

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

  group('PlanTankList tank dialog volume unit (issue #2027)', () {
    Future<ProviderContainer> pumpImperial(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
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
      return ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
    }

    testWidgets('a new tank reads cuft as gas capacity at its start '
        'pressure, not as water volume', (tester) async {
      final container = await pumpImperial(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Volume (cuft)'),
        '90',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Start (psi)'),
        '3000',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final added = container.read(divePlanNotifierProvider).tanks.last;
      // 90 cuft of gas at 3000 psi (206.8 bar): 90 * 28.3168 / 206.8 L. 90
      // sits near no preset, so the chip shows it rather than a preset rating.
      expect(added.volume, closeTo(12.32, 0.01));
      // The start pressure anchors the capacity, so it is kept as the
      // working pressure and the chip reads back what was typed.
      expect(added.workingPressure, closeTo(206.84, 0.01));
      expect(find.textContaining('90 cuft'), findsOneWidget);
    });

    testWidgets('a rated capacity at a preset pressure resolves to that '
        "preset's physical volume", (tester) async {
      final container = await pumpImperial(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Volume (cuft)'),
        '77.4',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Start (psi)'),
        '3000',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // 77.4 cuft at 3000 psi is an AL80: exactly 11.1 L.
      final added = container.read(divePlanNotifierProvider).tanks.last;
      expect(added.volume, 11.1);
    });

    testWidgets('editing the primary tank to 100 cuft shows 100 cuft, '
        'not 200 times it', (tester) async {
      final container = await pumpImperial(tester);

      await tester.tap(find.widgetWithText(InputChip, 'Primary'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Volume (cuft)'),
        '100',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final primary = container.read(divePlanNotifierProvider).tanks.first;
      // The default tank's 207 bar working pressure anchors the capacity.
      expect(primary.volume, closeTo(100 * 28.3168 / 207, 0.01));
      expect(primary.workingPressure, 207.0);
      expect(find.textContaining('100 cuft'), findsOneWidget);
      expect(find.textContaining('20000'), findsNothing);
    });

    testWidgets('saving without touching the volume keeps it exactly', (
      tester,
    ) async {
      final container = await pumpImperial(tester);
      final before = container.read(divePlanNotifierProvider).tanks.first;

      await tester.tap(find.widgetWithText(InputChip, 'Primary'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final after = container.read(divePlanNotifierProvider).tanks.first;
      expect(after.volume, before.volume);
      expect(after.workingPressure, before.workingPressure);
    });

    testWidgets('a new tank keeps the start pressure entered as its working '
        'pressure when the volume is left at its default', (tester) async {
      final container = await pumpImperial(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      final seeded = (tester.widget<TextField>(
        find.widgetWithText(TextField, 'Volume (cuft)'),
      )).controller!.text;
      await tester.enterText(
        find.widgetWithText(TextField, 'Start (psi)'),
        '3000',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final added = container.read(divePlanNotifierProvider).tanks.last;
      expect(added.workingPressure, closeTo(206.84, 0.01));
      // The seeded capacity is what the diver saw, so the chip reads it back.
      expect(seeded, '78.4');
      expect(find.textContaining('78 cuft'), findsOneWidget);
    });

    testWidgets('an existing tank without a volume keeps none when saved '
        'untouched', (tester) async {
      final container = await pumpImperial(tester);
      final notifier = container.read(divePlanNotifierProvider.notifier);
      final original = container.read(divePlanNotifierProvider).tanks.first;
      notifier.updateTank(
        original.id,
        DiveTank(
          id: original.id,
          name: original.name,
          startPressure: original.startPressure,
          gasMix: original.gasMix,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InputChip, 'Primary'));
      await tester.pumpAndSettle();
      final seeded = (tester.widget<TextField>(
        find.widgetWithText(TextField, 'Volume (cuft)'),
      )).controller!.text;
      expect(seeded, isEmpty);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = container.read(divePlanNotifierProvider).tanks.first;
      expect(saved.volume, isNull);
      expect(saved.workingPressure, isNull);
    });

    testWidgets('a cleared cuft field saves no volume', (tester) async {
      final container = await pumpImperial(tester);

      await tester.tap(find.widgetWithText(InputChip, 'Primary'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Volume (cuft)'),
        '',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final primary = container.read(divePlanNotifierProvider).tanks.first;
      expect(primary.volume, isNull);
      expect(primary.workingPressure, 207.0);
    });

    testWidgets('metric volume is still stored as entered', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanTankList()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Volume (L)'),
        '12',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      expect(container.read(divePlanNotifierProvider).tanks.last.volume, 12);
    });

    testWidgets('a metric edit keeps the working pressure', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanTankList()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InputChip, 'Primary'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Volume (L)'),
        '12',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      final primary = container.read(divePlanNotifierProvider).tanks.first;
      expect(primary.volume, 12);
      expect(primary.workingPressure, 207.0);
    });
  });

  group('PlanTankList edit dialog keeps fields it does not show', () {
    testWidgets('material, preset, deco switch depth and equipment link '
        'survive an edit', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
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
      final notifier = container.read(divePlanNotifierProvider.notifier);
      final original = container.read(divePlanNotifierProvider).tanks.first;
      notifier.updateTank(
        original.id,
        original.copyWith(
          material: TankMaterial.aluminum,
          presetName: 'al80',
          decoSwitchDepth: 21,
          equipmentId: 'eq-1',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InputChip, 'Primary'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'O₂ %'), '32');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final edited = container.read(divePlanNotifierProvider).tanks.first;
      expect(edited.gasMix.o2, 32);
      expect(edited.workingPressure, 207.0);
      expect(edited.material, TankMaterial.aluminum);
      expect(edited.presetName, 'al80');
      expect(edited.decoSwitchDepth, 21);
      expect(edited.equipmentId, 'eq-1');
    });
  });

  group('PlanTankList gas percent validation (issue #1900)', () {
    testWidgets('an unparseable O2% blocks save instead of silently '
        'becoming air', (tester) async {
      await tester.pumpWidget(
        testApp(
          // Pinned: this test asserts on exact English labels and the
          // English error string below (test/helpers/test_app.dart:17-19).
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanTankList()),
        ),
      );
      await tester.pumpAndSettle();

      final tanksBefore = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      ).read(divePlanNotifierProvider).tanks.length;

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final o2Field = find.widgetWithText(TextFormField, 'O₂ %');
      await tester.enterText(o2Field, 'abc');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The dialog stayed open (the tank list is unchanged) and shows the
      // validator's error instead of silently saving 21% air.
      expect(find.text('Enter a valid number'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      expect(
        container.read(divePlanNotifierProvider).tanks.length,
        tanksBefore,
      );
    });

    testWidgets('an O2+He sum over 100% blocks save (Copilot review)', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanTankList()),
        ),
      );
      await tester.pumpAndSettle();

      final tanksBefore = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      ).read(divePlanNotifierProvider).tanks.length;

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final o2Field = find.widgetWithText(TextFormField, 'O₂ %');
      final heField = find.widgetWithText(TextFormField, 'He %');
      await tester.enterText(o2Field, '60');
      await tester.enterText(heField, '60');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('O₂ + He cannot exceed 100%.'),
        findsWidgets,
        reason: 'GasMix derives N2 as the remainder of the two',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      expect(
        container.read(divePlanNotifierProvider).tanks.length,
        tanksBefore,
      );
    });

    testWidgets('a negative gas percentage blocks save (Copilot review)', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanTankList()),
        ),
      );
      await tester.pumpAndSettle();

      final tanksBefore = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      ).read(divePlanNotifierProvider).tanks.length;

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final o2Field = find.widgetWithText(TextFormField, 'O₂ %');
      await tester.enterText(o2Field, '-5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid number'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      expect(
        container.read(divePlanNotifierProvider).tanks.length,
        tanksBefore,
      );
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

      // Default tank: 11.1 L at 207 bar is an AL80, whose rated gas capacity
      // is 77.4 cuft (the number on its chip), not 11.1 L of water in cuft.
      final volumeField = find.widgetWithText(TextField, 'Volume (cuft)');
      final volumeController = (tester.widget<TextField>(
        volumeField,
      )).controller!;
      expect(volumeController.text, '77.4');
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
