import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/cylinder_config_item_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_role_option.dart';
import 'package:submersion/features/planner/presentation/widgets/tank_mod_field.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';

import '../../../helpers/test_app.dart';

/// Drives [CylinderConfigItemEditor] through a host that owns the item and
/// rebuilds on every `onChanged`, which is how the edit page uses it: the
/// widget is controlled, not self-storing.
///
/// Laid out like the dive log's tank card (issue #3576), without the fields
/// a saved cylinder has no use for, and with the MOD where N2 was (#3567).
void main() {
  final now = DateTime.utc(2026, 8, 5);

  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  const metric = UnitFormatter(
    AppSettings(volumeUnit: VolumeUnit.liters, pressureUnit: PressureUnit.bar),
  );
  const imperial = UnitFormatter(
    AppSettings(
      volumeUnit: VolumeUnit.cubicFeet,
      pressureUnit: PressureUnit.psi,
    ),
  );

  CylinderConfigItem seed({
    TankRole role = TankRole.diluent,
    double o2 = 21,
    double he = 0,
    String? label,
    double? volumeL,
    double? workingPressureBar,
    TankMaterial? material,
    double? startPressure,
    double? mod,
  }) => CylinderConfigItem(
    id: 'i1',
    configId: 'c1',
    tankRole: role,
    o2Percent: o2,
    hePercent: he,
    label: label,
    volumeL: volumeL,
    workingPressureBar: workingPressureBar,
    tankMaterial: material,
    defaultStartPressureBar: startPressure,
    decoSwitchDepth: mod,
    createdAt: now,
    updatedAt: now,
  );

  TankPresetEntity preset({
    String id = 'al80',
    String displayName = 'AL80',
    double volumeLiters = 11.1,
    double workingPressureBar = 207,
    TankMaterial material = TankMaterial.aluminum,
  }) => TankPresetEntity(
    id: id,
    name: id,
    displayName: displayName,
    volumeLiters: volumeLiters,
    workingPressureBar: workingPressureBar,
    material: material,
    createdAt: now,
    updatedAt: now,
  );

  /// Latest item the editor reported, and whether it asked to be removed.
  late CylinderConfigItem current;
  late bool removed;

  Widget host({
    required CylinderConfigItem item,
    UnitFormatter units = metric,
    List<TankPresetEntity> presets = const [],
    int number = 1,
  }) {
    current = item;
    removed = false;
    return testApp(
      // Pinned: an unpinned locale makes text finders machine-dependent.
      locale: const Locale('en'),
      overrides: [tankPresetsProvider.overrideWith((ref) async => presets)],
      child: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, setState) => CylinderConfigItemEditor(
            item: current,
            number: number,
            units: units,
            onChanged: (updated) => setState(() => current = updated),
            onRemove: () => setState(() => removed = true),
          ),
        ),
      ),
    );
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  String textOf(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  group('layout', () {
    testWidgets('sits in a card headed by its gas, with no number badge', (
      tester,
    ) async {
      await tester.pumpWidget(host(item: seed(o2: 50), number: 2));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('EAN50'), findsWidgets);
    });

    testWidgets('centres the delete button on the label field', (tester) async {
      await tester.pumpWidget(host(item: seed(o2: 50)));
      await tester.pumpAndSettle();

      final label = tester.getRect(
        find.byKey(CylinderConfigItemEditor.labelFieldKey),
      );
      final delete = tester.getRect(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(delete.center.dy, moreOrLessEquals(label.center.dy, epsilon: 1));
    });

    testWidgets('leaves room at the end for a drag handle when asked', (
      tester,
    ) async {
      Future<double> fieldEnd({required bool reserve}) async {
        await tester.pumpWidget(
          testApp(
            locale: const Locale('en'),
            overrides: [
              tankPresetsProvider.overrideWith((ref) async => const []),
            ],
            child: SingleChildScrollView(
              child: CylinderConfigItemEditor(
                item: seed(),
                number: 1,
                units: metric,
                reserveDragHandle: reserve,
                onChanged: (_) {},
                onRemove: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getRect(field('Working P')).right;
      }

      final plain = await fieldEnd(reserve: false);
      final cardEnd = tester.getRect(find.byType(Card)).right;
      final reserved = await fieldEnd(reserve: true);

      expect(plain, moreOrLessEquals(cardEnd - 16, epsilon: 1));
      expect(
        reserved,
        moreOrLessEquals(
          cardEnd - CylinderConfigItemEditor.dragHandleInset,
          epsilon: 1,
        ),
      );
    });

    testWidgets('has no material, regulator, N2 or pressure fields', (
      tester,
    ) async {
      await tester.pumpWidget(host(item: seed()));
      await tester.pumpAndSettle();

      expect(find.text('Material'), findsNothing);
      expect(find.text('Regulator'), findsNothing);
      expect(find.text('N2'), findsNothing);
      expect(find.text('Start Pressure'), findsNothing);
      expect(find.text('End Pressure'), findsNothing);
    });

    testWidgets('offers the MND only for a mix with helium', (tester) async {
      await tester.pumpWidget(host(item: seed()));
      await tester.pumpAndSettle();
      expect(field('MND'), findsNothing);

      await tester.pumpWidget(host(item: seed(o2: 18, he: 45)));
      await tester.pumpAndSettle();
      expect(field('MND'), findsOneWidget);
    });
  });

  group('label', () {
    testWidgets('round-trips, and an empty label clears it', (tester) async {
      await tester.pumpWidget(host(item: seed(label: 'Bailout 1')));
      await tester.pumpAndSettle();

      expect(textOf(tester, 'Label'), 'Bailout 1');

      await tester.enterText(field('Label'), 'Deco 50');
      await tester.pumpAndSettle();
      expect(current.label, 'Deco 50');

      // Whitespace-only reads as "no label", not as a label of spaces.
      await tester.enterText(field('Label'), '   ');
      await tester.pumpAndSettle();
      expect(current.label, isNull);
    });

    testWidgets('an empty label shows its number as a hint', (tester) async {
      await tester.pumpWidget(host(item: seed(), number: 3));
      await tester.pumpAndSettle();

      final label = tester.widget<TextField>(field('Label'));
      expect(label.decoration?.hintText, 'Tank 3');
      expect(label.controller!.text, isEmpty);
    });
  });

  group('role and gas', () {
    testWidgets('choosing a different role reports it upward', (tester) async {
      await tester.pumpWidget(host(item: seed(role: TankRole.diluent)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Diluent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bailout').last);
      await tester.pumpAndSettle();

      expect(current.tankRole, TankRole.bailout);
    });

    // A MOD set by hand is measured against its role's ppO2 limit (issue
    // #3567). A role on the other limit sets it aside for that role's
    // default; going back restores it, so a slip of the dropdown costs
    // nothing.
    group('a MOD set by hand across a role change', () {
      Future<void> pickRole(WidgetTester tester, String from, String to) async {
        await tester.tap(find.text(from));
        await tester.pumpAndSettle();
        await tester.tap(find.text(to).last);
        await tester.pumpAndSettle();
      }

      testWidgets('gives way to the default on a role with the other limit', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(item: seed(role: TankRole.deco, o2: 50, mod: 15)),
        );
        await tester.pumpAndSettle();

        await pickRole(tester, 'Deco', 'Stage');

        expect(current.tankRole, TankRole.stage);
        expect(current.decoSwitchDepth, isNull);
        // EAN50 at the 1.4 bottom limit.
        expect(textOf(tester, 'MOD'), '18');
      });

      testWidgets('comes back when the role is changed back', (tester) async {
        await tester.pumpWidget(
          host(item: seed(role: TankRole.deco, o2: 50, mod: 15)),
        );
        await tester.pumpAndSettle();

        await pickRole(tester, 'Deco', 'Stage');
        await pickRole(tester, 'Stage', 'Deco');

        expect(current.tankRole, TankRole.deco);
        expect(current.decoSwitchDepth, 15);
        expect(textOf(tester, 'MOD'), '15');
      });

      testWidgets('comes back for any role on its limit', (tester) async {
        await tester.pumpWidget(
          host(item: seed(role: TankRole.deco, o2: 50, mod: 15)),
        );
        await tester.pumpAndSettle();

        await pickRole(tester, 'Deco', 'Stage');
        await pickRole(tester, 'Stage', 'O₂ Supply');

        expect(current.tankRole, TankRole.oxygenSupply);
        expect(current.decoSwitchDepth, 15);
      });

      testWidgets('one set on the other limit is kept for that limit', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(item: seed(role: TankRole.deco, o2: 50, mod: 15)),
        );
        await tester.pumpAndSettle();

        await pickRole(tester, 'Deco', 'Stage');
        await tester.enterText(field('MOD'), '12');
        await tester.pumpAndSettle();
        await pickRole(tester, 'Stage', 'Deco');
        expect(current.decoSwitchDepth, 15);

        await pickRole(tester, 'Deco', 'Stage');
        expect(current.decoSwitchDepth, 12);
      });

      testWidgets(
        'a mix that moves a bailout to the other limit sets it aside',
        (tester) async {
          // A bailout richer than air follows the deco limit, leaner the
          // bottom one, so the mix moves it between limits as a role does.
          await tester.pumpWidget(
            host(item: seed(role: TankRole.bailout, o2: 21, mod: 50)),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.widgetWithText(FilterChip, 'EAN50'));
          await tester.pumpAndSettle();
          expect(current.o2Percent, 50);
          expect(current.decoSwitchDepth, isNull);

          await tester.tap(find.widgetWithText(FilterChip, 'Air'));
          await tester.pumpAndSettle();
          expect(current.o2Percent, 21);
          expect(current.decoSwitchDepth, 50);
        },
      );

      testWidgets('stays on a role with the same limit', (tester) async {
        await tester.pumpWidget(
          host(item: seed(role: TankRole.backGas, o2: 32, mod: 30)),
        );
        await tester.pumpAndSettle();

        await pickRole(tester, 'Back Gas', 'Stage');

        expect(current.tankRole, TankRole.stage);
        expect(current.decoSwitchDepth, 30);
      });

      testWidgets('leaves a cylinder on its default alone', (tester) async {
        await tester.pumpWidget(host(item: seed(role: TankRole.deco, o2: 50)));
        await tester.pumpAndSettle();

        await pickRole(tester, 'Deco', 'Stage');
        await pickRole(tester, 'Stage', 'Deco');

        expect(current.decoSwitchDepth, isNull);
      });

      testWidgets(
        'a diluent is its own limit, not lumped with the bottom one',
        (tester) async {
          // A Dil MOD distinct from both the bottom and the deco limit, so
          // nothing here can pass by sharing a limit value with another role.
          const distinctDil = UnitFormatter(
            AppSettings(ccrDiluentModPpO2: 1.3),
          );
          await tester.pumpWidget(
            host(
              item: seed(role: TankRole.backGas, o2: 32, mod: 25),
              units: distinctDil,
            ),
          );
          await tester.pumpAndSettle();

          await pickRole(tester, 'Back Gas', 'Diluent');
          expect(
            current.decoSwitchDepth,
            isNull,
            reason:
                "a bottom-limit MOD must not carry onto the diluent's "
                'own limit',
          );

          await tester.enterText(field('MOD'), '20');
          await tester.pumpAndSettle();
          await pickRole(tester, 'Diluent', 'Stage');
          expect(
            current.decoSwitchDepth,
            25,
            reason:
                'Stage shares the bottom limit with Back Gas, not with '
                'the diluent it was set on',
          );

          await pickRole(tester, 'Stage', 'Diluent');
          expect(current.decoSwitchDepth, 20);
        },
      );

      testWidgets(
        'a diluent stays its own limit even sharing the bottom ppO2 value',
        (tester) async {
          // Dil MOD and the bottom limit set to the same 1.4: a role is
          // still the limit it is, not the number it happens to resolve to.
          const sameValue = UnitFormatter(
            AppSettings(ppO2MaxWorking: 1.4, ccrDiluentModPpO2: 1.4),
          );
          await tester.pumpWidget(
            host(
              item: seed(role: TankRole.backGas, o2: 32, mod: 25),
              units: sameValue,
            ),
          );
          await tester.pumpAndSettle();

          await pickRole(tester, 'Back Gas', 'Diluent');
          expect(
            current.decoSwitchDepth,
            isNull,
            reason:
                'back gas and diluent are different limits even when both '
                'happen to be set to 1.4',
          );
        },
      );
    });

    testWidgets('the role field and every role option carry the role glyph', (
      tester,
    ) async {
      await tester.pumpWidget(host(item: seed(role: TankRole.sidemountLeft)));
      await tester.pumpAndSettle();

      expect(find.byIcon(TankRole.sidemountLeft.icon), findsOneWidget);

      await tester.tap(find.text('Sidemount Left'));
      await tester.pumpAndSettle();

      for (final role in TankRole.values) {
        expect(
          find.descendant(
            of: find.byType(DropdownMenuItem<TankRole>),
            matching: find.byWidgetPredicate(
              (w) => w is TankRoleOption && w.role == role,
            ),
          ),
          findsWidgets,
          reason: role.name,
        );
      }
    });

    testWidgets('whole-number gas fractions render without a decimal point', (
      tester,
    ) async {
      await tester.pumpWidget(host(item: seed(o2: 18, he: 45)));
      await tester.pumpAndSettle();

      expect(textOf(tester, 'O2'), '18');
      expect(textOf(tester, 'He'), '45');
    });

    testWidgets('a fractional gas fraction keeps its decimals', (tester) async {
      await tester.pumpWidget(host(item: seed(o2: 32.5)));
      await tester.pumpAndSettle();

      expect(textOf(tester, 'O2'), '32.5');
    });

    testWidgets('editing O2 and He reports the parsed fractions', (
      tester,
    ) async {
      await tester.pumpWidget(host(item: seed()));
      await tester.pumpAndSettle();

      await tester.enterText(field('O2'), '18');
      await tester.enterText(field('He'), '45');
      await tester.pumpAndSettle();

      expect(current.o2Percent, 18);
      expect(current.hePercent, 45);
    });

    testWidgets('a half-typed number does not clobber the stored mix', (
      tester,
    ) async {
      await tester.pumpWidget(host(item: seed(o2: 32)));
      await tester.pumpAndSettle();

      await tester.enterText(field('O2'), '.');
      await tester.pumpAndSettle();

      expect(current.o2Percent, 32);
    });

    testWidgets('an unreadable O2 says why and keeps the stored mix (#1900)', (
      tester,
    ) async {
      await tester.pumpWidget(host(item: seed(o2: 32)));
      await tester.pumpAndSettle();

      await tester.enterText(field('O2'), '3..2');
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter a valid number'), findsOneWidget);
      expect(current.o2Percent, 32);
    });

    testWidgets('a gas chip sets the mix and both fields', (tester) async {
      await tester.pumpWidget(host(item: seed()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'EAN50'));
      await tester.pumpAndSettle();

      expect(current.o2Percent, 50);
      expect(current.hePercent, 0);
      expect(textOf(tester, 'O2'), '50');
    });

    testWidgets('setting the MND works out the helium', (tester) async {
      await tester.pumpWidget(host(item: seed(o2: 18, he: 45)));
      await tester.pumpAndSettle();

      await tester.enterText(field('MND'), '40');
      await tester.pumpAndSettle();

      expect(current.hePercent, isNot(45));
      expect(current.o2Percent, 18);
    });
  });

  group('MOD', () {
    testWidgets('shows the role default from the diver ppO2 limits', (
      tester,
    ) async {
      await tester.pumpWidget(host(item: seed(role: TankRole.deco, o2: 50)));
      await tester.pumpAndSettle();

      expect(find.byType(TankModField), findsOneWidget);
      expect(
        tester
            .widget<NumberField>(find.byKey(TankModField.fieldKey))
            .controller
            .text,
        '22',
      );
    });

    testWidgets('typing a depth stores it on the cylinder, and Reset clears '
        'it', (tester) async {
      await tester.pumpWidget(host(item: seed(role: TankRole.deco, o2: 50)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(TankModField.fieldKey), '18');
      await tester.pumpAndSettle();
      expect(current.decoSwitchDepth, 18);

      await tester.tap(find.byKey(TankModField.resetKey));
      await tester.pumpAndSettle();
      expect(current.decoSwitchDepth, isNull);
    });
  });

  testWidgets('the MOD explanation spans the card, not the MOD column', (
    tester,
  ) async {
    // Overridden, so the line holds the default and Reset as well as the
    // ppO2: the most it ever has to fit.
    await tester.pumpWidget(
      host(item: seed(role: TankRole.deco, o2: 50, mod: 18)),
    );
    await tester.pumpAndSettle();

    final field = tester.getRect(find.byKey(TankModField.fieldKey));
    final details = tester.getRect(find.byType(TankModDetails));
    expect(details.width, greaterThan(field.width * 2));
    expect(details.top, greaterThanOrEqualTo(field.bottom));
  });

  group('cylinder size', () {
    testWidgets('volume and working pressure show in metric units', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(item: seed(volumeL: 11.1, workingPressureBar: 207)),
      );
      await tester.pumpAndSettle();

      expect(textOf(tester, 'Volume'), '11.1');
      expect(textOf(tester, 'Working P'), '207');
    });

    testWidgets('volume and working pressure show in imperial units', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          item: seed(volumeL: 11.1, workingPressureBar: 207),
          units: imperial,
        ),
      );
      await tester.pumpAndSettle();

      // Imperial divers name a cylinder by its gas capacity: 11.1 L at
      // 207 bar is the AL80's 77 cuft. 207 bar is 3002 psi.
      expect(textOf(tester, 'Volume'), '77');
      expect(textOf(tester, 'Working P'), '3002');
    });

    testWidgets('editing them stores litres and bar', (tester) async {
      await tester.pumpWidget(host(item: seed()));
      await tester.pumpAndSettle();

      await tester.enterText(field('Working P'), '232');
      await tester.enterText(field('Volume'), '12');
      await tester.pumpAndSettle();

      expect(current.volumeL, 12);
      expect(current.workingPressureBar, 232);
    });

    testWidgets('fields it does not show are kept as they were', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(item: seed(material: TankMaterial.steel, startPressure: 200)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(field('O2'), '32');
      await tester.pumpAndSettle();

      expect(current.tankMaterial, TankMaterial.steel);
      expect(current.defaultStartPressureBar, 200);
    });
  });

  group('preset', () {
    Future<void> pickPreset(WidgetTester tester, String name) async {
      await tester.tap(find.text('Select Preset...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    testWidgets('picking a preset seeds the size and the empty label', (
      tester,
    ) async {
      await tester.pumpWidget(host(item: seed(), presets: [preset()]));
      await tester.pumpAndSettle();

      await pickPreset(tester, 'AL80');

      expect(current.volumeL, 11.1);
      expect(current.workingPressureBar, 207);
      expect(current.tankMaterial, TankMaterial.aluminum);
      expect(current.label, 'AL80');
      expect(textOf(tester, 'Label'), 'AL80');
      expect(textOf(tester, 'Volume'), '11.1');
    });

    testWidgets('picking a preset never overwrites a label the diver typed', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          item: seed(label: 'Bailout 1'),
          presets: [preset()],
        ),
      );
      await tester.pumpAndSettle();

      await pickPreset(tester, 'AL80');

      expect(current.label, 'Bailout 1');
      expect(current.volumeL, 11.1);
    });
  });

  testWidgets('the delete affordance asks the parent to remove the row', (
    tester,
  ) async {
    await tester.pumpWidget(host(item: seed()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(removed, isTrue);
  });
}
