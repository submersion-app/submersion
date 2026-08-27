import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/cylinder_config_item_editor.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

import '../../../helpers/test_app.dart';

/// Drives [CylinderConfigItemEditor] through a host that owns the item and
/// rebuilds on every `onChanged`, which is how the edit page uses it: the
/// widget is controlled, not self-storing.
void main() {
  final now = DateTime.utc(2026, 8, 5);

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
  }) => CylinderConfigItem(
    id: 'i1',
    configId: 'c1',
    tankRole: role,
    o2Percent: o2,
    hePercent: he,
    label: label,
    volumeL: volumeL,
    workingPressureBar: workingPressureBar,
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
  }) {
    current = item;
    removed = false;
    return testApp(
      // Pinned: an unpinned locale makes text finders machine-dependent.
      locale: const Locale('en'),
      overrides: [tankPresetsProvider.overrideWith((ref) async => presets)],
      child: StatefulBuilder(
        builder: (context, setState) => CylinderConfigItemEditor(
          item: current,
          units: units,
          onChanged: (updated) => setState(() => current = updated),
          onRemove: () => setState(() => removed = true),
        ),
      ),
    );
  }

  testWidgets('whole-number gas fractions render without a decimal point', (
    tester,
  ) async {
    await tester.pumpWidget(host(item: seed(o2: 18, he: 45)));
    await tester.pumpAndSettle();

    expect(find.text('18'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('18.0'), findsNothing);
  });

  testWidgets('a fractional gas fraction keeps its decimals', (tester) async {
    await tester.pumpWidget(host(item: seed(o2: 32.5)));
    await tester.pumpAndSettle();

    expect(find.text('32.5'), findsOneWidget);
  });

  testWidgets('choosing a different role reports it upward', (tester) async {
    await tester.pumpWidget(host(item: seed(role: TankRole.diluent)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Diluent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bailout').last);
    await tester.pumpAndSettle();

    expect(current.tankRole, TankRole.bailout);
  });

  testWidgets('editing O2 and He reports the parsed fractions', (tester) async {
    await tester.pumpWidget(host(item: seed()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'O2 %'), '18');
    await tester.enterText(find.widgetWithText(TextField, 'He %'), '45');
    await tester.pumpAndSettle();

    expect(current.o2Percent, 18);
    expect(current.hePercent, 45);
  });

  testWidgets('a half-typed number does not clobber the stored mix', (
    tester,
  ) async {
    // "." is a transient state on the way to "32.5". Writing null (or 0) into
    // the model here would silently rewrite the gas on a saved configuration.
    await tester.pumpWidget(host(item: seed(o2: 32)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'O2 %'), '.');
    await tester.pumpAndSettle();

    expect(current.o2Percent, 32);
  });

  testWidgets('the label round-trips and an empty label clears it', (
    tester,
  ) async {
    await tester.pumpWidget(host(item: seed(label: 'Bailout 1')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Bailout 1'), findsOneWidget);

    // Found by its decoration rather than its value: the value changes as the
    // test types, and a finder keyed on it goes stale after the first entry.
    final label = find.widgetWithText(TextField, 'Label');
    await tester.enterText(label, 'Deco 50');
    await tester.pumpAndSettle();
    expect(current.label, 'Deco 50');

    // Whitespace-only reads as "no label", not as a label of spaces.
    await tester.enterText(label, '   ');
    await tester.pumpAndSettle();
    expect(current.label, isNull);
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

  testWidgets('the spec summary respects the diver metric units', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(item: seed(volumeL: 11.1, workingPressureBar: 207)),
    );
    await tester.pumpAndSettle();

    expect(find.text('11.1 L - 207 bar'), findsOneWidget);
  });

  testWidgets('the spec summary respects the diver imperial units', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(item: seed(volumeL: 11.1, workingPressureBar: 207), units: imperial),
    );
    await tester.pumpAndSettle();

    // Imperial divers name a cylinder by its gas capacity, not its physical
    // volume: 11.1 L @ 207 bar is the AL80's 77 cuft, not 0.39 cuft of
    // aluminum. 207 bar -> 3002 psi.
    expect(find.text('77 cuft - 3002 psi'), findsOneWidget);
  });

  testWidgets('a cylinder with only a volume shows just that', (tester) async {
    await tester.pumpWidget(host(item: seed(volumeL: 12)));
    await tester.pumpAndSettle();

    expect(find.text('12 L'), findsOneWidget);
  });

  testWidgets('an unspecified cylinder shows no spec summary', (tester) async {
    await tester.pumpWidget(host(item: seed()));
    await tester.pumpAndSettle();

    expect(find.textContaining(' L'), findsNothing);
    expect(find.textContaining(' bar'), findsNothing);
  });

  testWidgets('the preset button does nothing when there are no presets', (
    tester,
  ) async {
    await tester.pumpWidget(host(item: seed(), presets: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('From preset'));
    await tester.pumpAndSettle();

    // No sheet, and nothing written to the model.
    expect(find.byType(ListTile), findsNothing);
    expect(current.volumeL, isNull);
  });

  testWidgets('picking a preset seeds the spec and the empty label', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        item: seed(),
        presets: [
          preset(),
          preset(id: 'lp85'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('From preset'));
    await tester.pumpAndSettle();

    // The sheet describes each preset in the diver's units.
    expect(find.text('11.1 L - 207 bar'), findsWidgets);

    await tester.tap(find.text('AL80').first);
    await tester.pumpAndSettle();

    expect(current.volumeL, 11.1);
    expect(current.workingPressureBar, 207);
    expect(current.tankMaterial, TankMaterial.aluminum);
    expect(current.label, 'AL80');
    // The controller is seeded too, so the field is not left stale.
    expect(find.widgetWithText(TextField, 'AL80'), findsOneWidget);
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

    await tester.tap(find.text('From preset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AL80').first);
    await tester.pumpAndSettle();

    expect(current.label, 'Bailout 1');
    expect(current.volumeL, 11.1);
  });
}
