import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/rig_composer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold Water Reg',
    type: EquipmentType.regulator,
  );
  const first = EquipmentItem(
    id: 'first',
    name: 'DIN First Stage',
    type: EquipmentType.firstStage,
  );
  const second = EquipmentItem(
    id: 'second',
    name: 'Primary Second Stage',
    type: EquipmentType.secondStage,
  );
  final t0 = DateTime(2026);
  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: '$parent>$child',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );

  // Issue #2514: the rig's gear picker leaves out the components of an
  // assembly it offers, since adding the assembly brings them.
  testWidgets('the gear picker leaves out components of offered assemblies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final presets = TankPresets.all.map(TankPresetEntity.fromBuiltIn).toList();
    final controllers = List.generate(4, (_) => TextEditingController());
    addTearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tankPresetsProvider.overrideWith((ref) async => presets),
          activeEquipmentProvider.overrideWith(
            (ref) async => const [reg, first, second],
          ),
          allEquipmentProvider.overrideWith(
            (ref) async => const [reg, first, second],
          ),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) async => ComponentsIndex.fromRows([
              edge('reg', 'first'),
              edge('reg', 'second'),
            ]),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          allDiversProvider.overrideWith((ref) async => const []),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RigComposer(
                gear: const [],
                tanks: [presets.firstWhere((p) => p.name == 'al80')],
                waterType: WaterType.salt,
                bodyWeightController: controllers[0],
                heightCmController: controllers[1],
                heightFeetController: controllers[2],
                heightInchesController: controllers[3],
                units: const UnitFormatter(AppSettings()),
                showSaveBodyWeight: false,
                onGearAdded: (_) {},
                onGearSetAdded: (_, _) {},
                onGearRemoved: (_) {},
                onTankAdded: (_) {},
                onTankRemoved: (_) {},
                onTankChanged: (_, _) {},
                onWaterChanged: (_) {},
                onSaveBodyWeight: () {},
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add gear'));
    await tester.pumpAndSettle();

    final sheet = find.byType(EquipmentPickerSheet);
    expect(sheet, findsOneWidget);
    expect(
      tester.widget<EquipmentPickerSheet>(sheet).hideAssemblyParts,
      isTrue,
    );
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet('Cold Water Reg'), findsOneWidget);
    expect(inSheet('DIN First Stage'), findsNothing);
    expect(inSheet('Primary Second Stage'), findsNothing);
  });
}
