import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/set_bundle_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_set_tile.dart';
import 'package:submersion/features/equipment/presentation/widgets/set_bundle_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Where a set's bundle is shown read-only (issue #4525): its page, its
/// list row and the picker.
void main() {
  final t = DateTime(2026, 11, 1);

  EquipmentItem gear(String id, String name) => EquipmentItem(
    id: id,
    diverId: 'd1',
    name: name,
    type: EquipmentType.regulator,
  );

  EquipmentSet set(
    String id,
    String name, {
    List<String> gear = const [],
    List<EquipmentItem>? items,
    List<String> includes = const [],
    List<String> presets = const [],
    List<String> configs = const [],
  }) => EquipmentSet(
    id: id,
    diverId: 'd1',
    name: name,
    equipmentIds: gear,
    items: items,
    includedSetIds: includes,
    weightPresetIds: presets,
    cylinderConfigIds: configs,
    createdAt: t,
    updatedAt: t,
  );

  final preset = WeightPreset(
    id: 'p6',
    diverId: 'd1',
    displayName: 'Pockets',
    notes: '',
    sortOrder: 0,
    createdAt: t,
    updatedAt: t,
    entries: const [
      WeightPresetEntry(
        id: 'e',
        presetId: 'p6',
        weightType: WeightType.belt,
        amountKg: 5.44,
      ),
    ],
  );
  final config = CylinderConfig(
    id: 'al80',
    diverId: 'd1',
    name: 'AL80 EAN32',
    createdAt: t,
    updatedAt: t,
    items: [
      CylinderConfigItem(
        id: 'i',
        configId: 'al80',
        tankRole: TankRole.backGas,
        createdAt: t,
        updatedAt: t,
      ),
    ],
  );
  final rig = set('rig', 'BP rig', gear: ['bp']);

  List<Override> overrides({
    List<EquipmentSet> sets = const [],
    Map<String, SetBundleSummary> summaries = const {},
  }) => [
    settingsProvider.overrideWith(
      (ref) => MockSettingsNotifier(
        const AppSettings(weightUnit: WeightUnit.pounds),
      ),
    ),
    equipmentSetsProvider.overrideWith((ref) async => sets),
    weightPresetsProvider.overrideWith((ref) async => [preset]),
    cylinderConfigsProvider.overrideWith((ref) async => [config]),
    setBundleSummaryProvider.overrideWith((ref, id) async => summaries[id]),
  ];

  Future<void> pump(
    WidgetTester tester,
    Widget child,
    List<Override> scope,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: scope,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SetBundleSummaryCard', () {
    testWidgets('lists included sets, presets with a total, and '
        'configurations', (tester) async {
      final outer = set(
        'outer',
        'BP + camera',
        gear: ['cam'],
        includes: ['rig'],
        presets: ['p6'],
        configs: ['al80'],
      );
      await pump(
        tester,
        Scaffold(body: SetBundleSummaryCard(set: outer)),
        overrides(sets: [rig, outer]),
      );
      expect(find.text('Included sets'), findsOneWidget);
      expect(find.text('BP rig'), findsOneWidget);
      expect(find.text('Pockets'), findsOneWidget);
      expect(find.text('12.0 lbs'), findsOneWidget);
      expect(find.text('AL80 EAN32'), findsOneWidget);
      expect(
        find.text('Applies in total: 2 items, 12.0 lbs lead, 1 cylinder'),
        findsOneWidget,
      );
    });

    testWidgets('shows nothing for a set that carries only its own gear', (
      tester,
    ) async {
      await pump(
        tester,
        Scaffold(body: SetBundleSummaryCard(set: rig)),
        overrides(sets: [rig]),
      );
      expect(find.text('Included sets'), findsNothing);
      expect(find.textContaining('Applies in total'), findsNothing);
    });
  });

  group('EquipmentSetTile', () {
    testWidgets('shows effective gear, and the lead total in pounds', (
      tester,
    ) async {
      final outer = set('outer', 'BP + camera', gear: ['cam']);
      await pump(
        tester,
        Scaffold(
          body: EquipmentSetTile(set: outer, onTap: () {}),
        ),
        overrides(
          summaries: const {
            'outer': SetBundleSummary(
              gearCount: 3,
              leadKg: 5.44,
              cylinderCount: 1,
            ),
          },
        ),
      );
      expect(find.text('3 items, 12.0 lbs lead, 1 cylinder'), findsOneWidget);
    });

    testWidgets('falls back to its own count with no bundle', (tester) async {
      final plain = set('plain', 'Plain', gear: ['a', 'b']);
      await pump(
        tester,
        Scaffold(
          body: EquipmentSetTile(set: plain, onTap: () {}),
        ),
        overrides(),
      );
      expect(find.text('2 items'), findsOneWidget);
    });
  });

  group('EquipmentSetPickerSheet', () {
    final lead = set('lead', 'Lead only', presets: ['p6']);

    Future<List<String>> pumpPicker(
      WidgetTester tester, {
      bool requireGear = false,
    }) async {
      final picked = <String>[];
      await pump(
        tester,
        Scaffold(
          body: EquipmentSetPickerSheet(
            scrollController: ScrollController(),
            requireGear: requireGear,
            onSetSelected: (set, items) => picked.add(set.id),
          ),
        ),
        [
          ...overrides(
            sets: [lead],
            summaries: const {
              'lead': SetBundleSummary(
                gearCount: 0,
                leadKg: 5.44,
                cylinderCount: 0,
              ),
            },
          ),
          equipmentSetWithItemsProvider.overrideWith(
            (ref, id) async => lead.copyWith(items: const []),
          ),
        ],
      );
      return picked;
    }

    testWidgets('offers a set with only weights', (tester) async {
      final picked = await pumpPicker(tester);
      expect(find.text('12.0 lbs lead'), findsOneWidget);
      await tester.tap(find.text('Lead only'));
      await tester.pump();
      expect(picked, ['lead']);
    });

    testWidgets('with requireGear a set with only weights cannot be picked', (
      tester,
    ) async {
      final picked = await pumpPicker(tester, requireGear: true);
      await tester.tap(find.text('Lead only'));
      await tester.pump();
      expect(picked, isEmpty);
    });
  });

  group('EquipmentSetDetailPage', () {
    testWidgets('marks gear that comes from an included set and counts '
        'all of it', (tester) async {
      final outer = set(
        'outer',
        'BP + camera',
        gear: ['cam'],
        includes: ['rig'],
        items: [gear('bp', 'Steel backplate'), gear('cam', 'Camera housing')],
      );
      await pump(tester, const EquipmentSetDetailPage(setId: 'outer'), [
        ...overrides(sets: [rig, outer]),
        equipmentSetProvider.overrideWith((ref, id) async => outer),
        equipmentSetGeofencesProvider.overrideWith((ref, id) async => []),
        equipmentArrangementProvider.overrideWithValue(
          EquipmentArrangement.defaults.copyWith(groupByType: false),
        ),
        equipmentComponentsIndexProvider.overrideWith(
          (ref) => Future.value(ComponentsIndex.fromRows(const [])),
        ),
      ]);
      expect(find.textContaining('From BP rig'), findsOneWidget);
      // The header counts what the set applies, not only its own gear.
      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('Included sets'), findsOneWidget);
    });
  });
}
