import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_form_values.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/set_bundle_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The set editor's sections for included sets, weight presets and cylinder
/// configurations (issue #4525).
void main() {
  final t = DateTime(2026, 11, 1);

  EquipmentSet set(
    String id,
    String name, {
    List<String> gear = const [],
    List<String> includes = const [],
  }) => EquipmentSet(
    id: id,
    diverId: 'd1',
    name: name,
    equipmentIds: gear,
    includedSetIds: includes,
    createdAt: t,
    updatedAt: t,
  );

  WeightPreset preset(String id, String name, double kg) => WeightPreset(
    id: id,
    diverId: 'd1',
    displayName: name,
    notes: '',
    sortOrder: 0,
    createdAt: t,
    updatedAt: t,
    entries: [
      WeightPresetEntry(
        id: '$id-e',
        presetId: id,
        weightType: WeightType.belt,
        amountKg: kg,
      ),
    ],
  );

  CylinderConfig config(String id, String name, int cylinders) =>
      CylinderConfig(
        id: id,
        diverId: 'd1',
        name: name,
        createdAt: t,
        updatedAt: t,
        items: [
          for (var i = 0; i < cylinders; i++)
            CylinderConfigItem(
              id: '$id-$i',
              configId: id,
              sortOrder: i,
              tankRole: TankRole.backGas,
              createdAt: t,
              updatedAt: t,
            ),
        ],
      );

  final sets = [
    set('edited', 'BP + camera', gear: ['cam']),
    set('rig', 'BP rig', gear: ['bp', 'reg']),
    set('cold', 'Cold water'),
    set('nested', 'Nested', includes: ['cold']),
  ];
  final presets = [preset('p6', 'Pockets', 2.72), preset('b6', 'Belt', 2.72)];
  final configs = [
    config('al80', 'AL80 EAN32', 1),
    config('twins', 'Twins', 2),
  ];

  Future<List<SetBundleListValues>> pump(
    WidgetTester tester,
    SetBundleListValues values, {
    Set<String> ownGearIds = const {'cam'},
    List<EquipmentSet>? allSets,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final reported = <SetBundleListValues>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              const AppSettings(weightUnit: WeightUnit.pounds),
            ),
          ),
          equipmentSetsProvider.overrideWith((ref) async => allSets ?? sets),
          weightPresetsProvider.overrideWith((ref) async => presets),
          cylinderConfigsProvider.overrideWith((ref) async => configs),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SetBundleSections(
                setId: 'edited',
                diverId: 'd1',
                ownGearIds: ownGearIds,
                values: values,
                onChanged: reported.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return reported;
  }

  testWidgets('lists each entry by name, with the lead total in pounds', (
    tester,
  ) async {
    await pump(
      tester,
      const SetBundleListValues(
        includedSetIds: ['rig'],
        weightPresetIds: ['p6', 'b6'],
        cylinderConfigIds: ['al80'],
      ),
    );
    expect(find.text('Included sets'), findsOneWidget);
    expect(find.text('BP rig'), findsOneWidget);
    expect(find.text('Pockets'), findsOneWidget);
    expect(find.text('Belt'), findsOneWidget);
    expect(find.text('AL80 EAN32'), findsOneWidget);
    // 2 x 2.72 kg.
    expect(find.text('Total 12.0 lbs'), findsOneWidget);
  });

  testWidgets('the total line counts included gear, lead and cylinders', (
    tester,
  ) async {
    await pump(
      tester,
      const SetBundleListValues(
        includedSetIds: ['rig'],
        weightPresetIds: ['p6'],
        cylinderConfigIds: ['twins'],
      ),
    );
    expect(
      find.text('Applies in total: 3 items, 6.0 lbs lead, 2 cylinders'),
      findsOneWidget,
    );
  });

  testWidgets('empty lists say so and show no total line', (tester) async {
    await pump(tester, SetBundleListValues.empty, ownGearIds: const {});
    expect(find.text('No included sets'), findsOneWidget);
    expect(find.text('No weight presets'), findsOneWidget);
    expect(find.text('No cylinder configurations'), findsOneWidget);
    expect(find.textContaining('Applies in total'), findsNothing);
  });

  testWidgets('removing an entry reports the list without it', (tester) async {
    final reported = await pump(
      tester,
      const SetBundleListValues(weightPresetIds: ['p6', 'b6']),
    );
    await tester.tap(find.byKey(const Key('set-bundle-remove-presets-p6')));
    await tester.pump();
    expect(reported.single.weightPresetIds, ['b6']);
  });

  testWidgets('adding a weight preset appends it, and offers only the rest', (
    tester,
  ) async {
    final reported = await pump(
      tester,
      const SetBundleListValues(weightPresetIds: ['p6']),
    );
    await tester.tap(find.byKey(const Key('set-bundle-add-presets')));
    await tester.pumpAndSettle();
    // Already in the list, so not offered again.
    expect(find.byKey(const Key('set-bundle-option-p6')), findsNothing);
    await tester.tap(find.byKey(const Key('set-bundle-option-b6')));
    await tester.pumpAndSettle();
    expect(reported.single.weightPresetIds, ['p6', 'b6']);
  });

  testWidgets('adding a cylinder configuration appends it', (tester) async {
    final reported = await pump(tester, SetBundleListValues.empty);
    await tester.tap(find.byKey(const Key('set-bundle-add-configs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-bundle-option-twins')));
    await tester.pumpAndSettle();
    expect(reported.single.cylinderConfigIds, ['twins']);
  });

  testWidgets('the set picker hides sets that cannot be included', (
    tester,
  ) async {
    final reported = await pump(tester, SetBundleListValues.empty);
    await tester.tap(find.byKey(const Key('set-bundle-add-includes')));
    await tester.pumpAndSettle();
    // Itself, and a set that already includes sets, are not offered.
    expect(find.byKey(const Key('set-bundle-option-edited')), findsNothing);
    expect(find.byKey(const Key('set-bundle-option-nested')), findsNothing);
    await tester.tap(find.byKey(const Key('set-bundle-option-rig')));
    await tester.pumpAndSettle();
    expect(reported.single.includedSetIds, ['rig']);
  });

  testWidgets('a set that another set includes cannot include any', (
    tester,
  ) async {
    await pump(
      tester,
      SetBundleListValues.empty,
      allSets: [
        ...sets,
        set('outer', 'Outer', includes: ['edited']),
      ],
    );
    await tester.tap(find.byKey(const Key('set-bundle-add-includes')));
    await tester.pumpAndSettle();
    expect(find.text('No other set can be included'), findsOneWidget);
  });

  testWidgets('reordering reports the new order', (tester) async {
    final reported = await pump(
      tester,
      const SetBundleListValues(weightPresetIds: ['p6', 'b6']),
    );
    final list = tester.widget<ReorderableListView>(
      find.byKey(const Key('set-bundle-list-presets')),
    );
    list.onReorderItem!(0, 1);
    expect(reported.single.weightPresetIds, ['b6', 'p6']);
  });

  testWidgets('lead with no gear shows the no-gear note', (tester) async {
    await pump(
      tester,
      const SetBundleListValues(weightPresetIds: ['p6']),
      ownGearIds: const {},
    );
    expect(find.textContaining('leaves no set tag on a dive'), findsOneWidget);
  });

  testWidgets('an entry whose target is gone is not listed', (tester) async {
    await pump(
      tester,
      const SetBundleListValues(weightPresetIds: ['gone', 'p6']),
    );
    expect(find.text('Pockets'), findsOneWidget);
    expect(
      find.byKey(const Key('set-bundle-remove-presets-gone')),
      findsNothing,
    );
  });
}
