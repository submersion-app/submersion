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
          regulatorEquipmentId: 'reg-1',
          extraRegulatorIds: const ['reg-2'],
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
      expect(edited.regulatorIds, ['reg-1', 'reg-2']);
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
      expect(find.textContaining('Enter a valid number'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      expect(
        container.read(divePlanNotifierProvider).tanks.length,
        tanksBefore,
      );
    });

    testWidgets('an unreadable start pressure blocks save', (tester) async {
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

      final pressureField = find.widgetWithText(TextField, 'Start (bar)');
      await tester.enterText(pressureField, '2..00');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter a valid number'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      expect(
        container.read(divePlanNotifierProvider).tanks.length,
        tanksBefore,
        reason: 'an unreadable pressure used to save the tank with none',
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

      // A single field's range, not the combined O2 + He message.
      expect(find.text('Enter 0 to 100'), findsOneWidget);
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
  group('PlanTankList diluent checkbox', () {
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

    testWidgets('is absent on open circuit, where nothing is diluent', (
      tester,
    ) async {
      await pumpList(tester, mode: PlanMode.oc);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Diluent'), findsNothing);
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets(
      'travel gas is absent on CCR, where only diluent and bailout apply '
      '(#3131)',
      (tester) async {
        await pumpList(tester, mode: PlanMode.ccr);

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(find.text('Also used as travel gas'), findsNothing);
        expect(
          find.widgetWithText(CheckboxListTile, 'Diluent'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'on CCR, ticking it saves the tank with the diluent role; unticked '
      'defaults to bailout (#3135)',
      (tester) async {
        final container = await pumpList(tester, mode: PlanMode.ccr);

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        final tile = find.widgetWithText(CheckboxListTile, 'Diluent');
        expect(tile, findsOneWidget);
        expect(find.text('Unticked cylinders are bailout'), findsOneWidget);
        expect(tester.widget<CheckboxListTile>(tile).value, isFalse);

        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(tile).value, isTrue);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        final addedTank = container.read(divePlanNotifierProvider).tanks.last;
        expect(addedTank.role, TankRole.diluent);
        expect(addedTank.isTravelGas, isFalse);
      },
    );

    testWidgets(
      'on SCR, an unticked tile leaves the neutral placeholder role, which '
      'the resolver then defaults to bailout',
      (tester) async {
        final container = await pumpList(tester, mode: PlanMode.scr);

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        final tile = find.widgetWithText(CheckboxListTile, 'Diluent');
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
      },
    );

    testWidgets('editing a diluent tank shows the tile already ticked', (
      tester,
    ) async {
      final container = await pumpList(tester, mode: PlanMode.ccr);
      container
          .read(divePlanNotifierProvider.notifier)
          .addTank(
            const DiveTank(
              id: 'dil',
              name: 'Diluent 18/45',
              volume: 3.0,
              startPressure: 200,
              gasMix: GasMix(o2: 18, he: 45),
              role: TankRole.diluent,
              order: 1,
            ),
          );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InputChip, 'Diluent 18/45'));
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(CheckboxListTile, 'Diluent');
      expect(tester.widget<CheckboxListTile>(tile).value, isTrue);
    });
  });

  group('PlanTankList CCR loop slots (#3220)', () {
    Future<ProviderContainer> pumpCcr(WidgetTester tester) async {
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
      container
          .read(divePlanNotifierProvider.notifier)
          .updateMode(PlanMode.ccr);
      await tester.pumpAndSettle();
      return container;
    }

    Finder chipWithText(String text) =>
        find.ancestor(of: find.text(text), matching: find.byType(InputChip));

    InputChip chip(WidgetTester tester, String text) =>
        tester.widget<InputChip>(chipWithText(text));

    const bailout = DiveTank(
      id: 'bo',
      name: 'Bailout 50',
      volume: 11.1,
      startPressure: 200,
      gasMix: GasMix(o2: 50),
      order: 2,
    );

    testWidgets('groups the loop slots apart from bailout and says when no '
        'bailout is carried yet', (tester) async {
      final container = await pumpCcr(tester);
      expect(find.text('Loop'), findsOneWidget);
      expect(find.text('Bailout'), findsOneWidget);
      expect(find.text('No bailout cylinder yet'), findsOneWidget);
      // The default cylinder became the diluent, the oxygen slot was added.
      expect(find.textContaining('Diluent • '), findsOneWidget);
      expect(find.textContaining('O₂ Supply • '), findsOneWidget);

      container.read(divePlanNotifierProvider.notifier).addTank(bailout);
      await tester.pumpAndSettle();
      expect(find.text('No bailout cylinder yet'), findsNothing);
      expect(chipWithText('Bailout 50'), findsOneWidget);
    });

    testWidgets('the oxygen slot and the only diluent offer no delete; a '
        'bailout cylinder does', (tester) async {
      final container = await pumpCcr(tester);
      container.read(divePlanNotifierProvider.notifier).addTank(bailout);
      await tester.pumpAndSettle();

      expect(chip(tester, 'Primary').onDeleted, isNull);
      expect(chip(tester, 'O2').onDeleted, isNull);
      expect(chip(tester, 'Bailout 50').onDeleted, isNotNull);
    });

    testWidgets('a second diluent makes both deletable', (tester) async {
      final container = await pumpCcr(tester);
      container
          .read(divePlanNotifierProvider.notifier)
          .addTank(
            const DiveTank(
              id: 'deep',
              name: 'Deep dil',
              volume: 3,
              startPressure: 200,
              gasMix: GasMix(o2: 10, he: 70),
              role: TankRole.diluent,
              order: 2,
            ),
          );
      await tester.pumpAndSettle();
      expect(chip(tester, 'Primary').onDeleted, isNotNull);
      expect(chip(tester, 'Deep dil').onDeleted, isNotNull);
    });

    testWidgets('editing the oxygen slot offers neither mix fields nor the '
        'diluent tile, and saving keeps it the 100 % oxygen supply', (
      tester,
    ) async {
      final container = await pumpCcr(tester);
      await tester.tap(chipWithText('O2'));
      await tester.pumpAndSettle();

      expect(find.text('O₂ %'), findsNothing);
      expect(find.text('He %'), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Onboard');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final o2 = container
          .read(divePlanNotifierProvider)
          .tanks
          .firstWhere((t) => t.role == TankRole.oxygenSupply);
      expect(o2.name, 'Onboard');
      expect(o2.gasMix.o2, 100);
    });

    testWidgets('editing the only diluent shows the tile ticked and locked', (
      tester,
    ) async {
      await pumpCcr(tester);
      await tester.tap(chipWithText('Primary'));
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(CheckboxListTile, 'Diluent');
      expect(tester.widget<CheckboxListTile>(tile).value, isTrue);
      expect(tester.widget<CheckboxListTile>(tile).onChanged, isNull);
    });

    testWidgets('a new cylinder on a CCR plan is bailout unless ticked', (
      tester,
    ) async {
      final container = await pumpCcr(tester);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Stage');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(chip(tester, 'Stage').onDeleted, isNotNull);
      expect(find.text('No bailout cylinder yet'), findsNothing);
      final added = container.read(divePlanNotifierProvider).tanks.last;
      expect(added.role, TankRole.backGas);
    });
  });

  // Issue #3567: each plan tank's MOD, overridable in its dialog.
  group('PlanTankList MOD', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
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
      return ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
    }

    const deco = DiveTank(
      id: 'deco',
      name: 'Deco 1',
      volume: 11.1,
      startPressure: 200,
      gasMix: GasMix(o2: 50),
      order: 1,
    );

    Finder modField() => find.widgetWithText(TextField, 'MOD');

    testWidgets('the dialog shows the default for the tank role', (
      tester,
    ) async {
      final container = await pump(tester);
      container.read(divePlanNotifierProvider.notifier).addTank(deco);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InputChip, 'Deco 1'));
      await tester.pumpAndSettle();

      // Richer than the bottom gas, so a deco gas: 22 m at 1.6.
      expect(tester.widget<TextField>(modField()).controller!.text, '22');
    });

    testWidgets('a MOD typed in the dialog is saved on the tank', (
      tester,
    ) async {
      final container = await pump(tester);
      container.read(divePlanNotifierProvider.notifier).addTank(deco);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InputChip, 'Deco 1'));
      await tester.pumpAndSettle();
      await tester.enterText(modField(), '18');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = container
          .read(divePlanNotifierProvider)
          .tanks
          .firstWhere((t) => t.id == 'deco');
      expect(saved.decoSwitchDepth, 18);
    });

    testWidgets('a cleared MOD saves as none', (tester) async {
      final container = await pump(tester);
      container
          .read(divePlanNotifierProvider.notifier)
          .addTank(deco.copyWith(decoSwitchDepth: 18));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InputChip, 'Deco 1'));
      await tester.pumpAndSettle();
      await tester.enterText(modField(), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = container
          .read(divePlanNotifierProvider)
          .tanks
          .firstWhere((t) => t.id == 'deco');
      expect(saved.decoSwitchDepth, isNull);
    });

    testWidgets('a tank chip names a MOD set by hand, and no other', (
      tester,
    ) async {
      final container = await pump(tester);
      container
          .read(divePlanNotifierProvider.notifier)
          .addTank(deco.copyWith(decoSwitchDepth: 18));
      await tester.pumpAndSettle();

      expect(find.textContaining('MOD 18m'), findsOneWidget);
      expect(find.textContaining('MOD'), findsOneWidget);
    });

    testWidgets('a chip whose MOD is too deep is flagged', (tester) async {
      final container = await pump(tester);
      container
          .read(divePlanNotifierProvider.notifier)
          .addTank(deco.copyWith(decoSwitchDepth: 24));
      await tester.pumpAndSettle();

      expect(find.textContaining('MOD 24m'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(InputChip, 'Deco 1'),
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      "a diluent chip's MOD override is checked against its Dil MOD limit, "
      'not the bottom limit (issue #3567)',
      (tester) async {
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
        container
            .read(divePlanNotifierProvider.notifier)
            .updateMode(PlanMode.ccr);
        await tester.pumpAndSettle();
        container
            .read(divePlanNotifierProvider.notifier)
            .addTank(
              const DiveTank(
                id: 'dil',
                name: 'EAN40 dil',
                volume: 11.1,
                startPressure: 200,
                gasMix: GasMix(o2: 40),
                role: TankRole.diluent,
                // ppO2 1.52: above the 1.4 bottom limit, within the 1.6
                // Dil MOD limit settings gives a diluent (#TestSettingsNotifier
                // default).
                decoSwitchDepth: 28,
                order: 2,
              ),
            );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.widgetWithText(InputChip, 'EAN40 dil'),
            matching: find.byIcon(Icons.warning_amber_rounded),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('the CCR oxygen slot has no MOD to set', (tester) async {
      final container = await pump(tester);
      container
          .read(divePlanNotifierProvider.notifier)
          .updateMode(PlanMode.ccr);
      await tester.pumpAndSettle();

      await tester.tap(
        find.ancestor(of: find.text('O2'), matching: find.byType(InputChip)),
      );
      await tester.pumpAndSettle();

      expect(modField(), findsNothing);
    });
  });
}
