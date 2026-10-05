import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

class _PresetListNotifier
    extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _PresetListNotifier(List<TankPresetEntity> presets)
    : super(AsyncValue.data(presets));

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

EquipmentItem _tank(
  String name, {
  required double volumeL,
  required double workingPressureBar,
  String? material,
  EquipmentStatus status = EquipmentStatus.active,
}) => EquipmentItem(
  id: '',
  name: name,
  type: EquipmentType.tank,
  status: status,
  attributes: [
    EquipmentAttribute(
      id: '',
      equipmentId: '',
      key: EquipmentAttrKeys.volumeL,
      valueNum: volumeL,
    ),
    EquipmentAttribute(
      id: '',
      equipmentId: '',
      key: EquipmentAttrKeys.workingPressureBar,
      valueNum: workingPressureBar,
    ),
    if (material != null)
      EquipmentAttribute(
        id: '',
        equipmentId: '',
        key: EquipmentAttrKeys.tankMaterial,
        valueText: material,
      ),
  ],
);

final _customPreset = TankPresetEntity(
  id: 'custom-1',
  diverId: 'diver-1',
  name: 'my_twin_7',
  displayName: 'My Twin 7s',
  volumeLiters: 14,
  workingPressureBar: 232,
  material: TankMaterial.steel,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Issue #163: the diver's own cylinders are offered in the tank preset
/// dropdown, above custom and built-in presets. Picking one does what the
/// "My cylinders" button does (#2599): it copies the cylinder into the tank
/// and hands it to the host to join the dive's gear. The dropdown then shows
/// the built-in preset the copied size matches, as reopening the dive would.
void main() {
  late EquipmentItem rentalAl80;
  late EquipmentItem faber;
  late EquipmentItem spare;
  late EquipmentItem nameOnly;
  late EquipmentItem regulator;

  setUp(() async {
    await setUpTestDatabase();
    final repo = EquipmentRepository();
    rentalAl80 = await repo.createEquipment(
      _tank(
        'Rental AL80',
        volumeL: 11.1,
        workingPressureBar: 207,
        material: 'aluminum',
      ),
    );
    faber = await repo.createEquipment(
      _tank(
        'Faber 12',
        volumeL: 12,
        workingPressureBar: 232,
        material: 'steel',
      ),
    );
    spare = await repo.createEquipment(
      _tank(
        'Old twinset',
        volumeL: 24,
        workingPressureBar: 232,
        status: EquipmentStatus.spare,
      ),
    );
    nameOnly = await repo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Unlabelled tank',
        type: EquipmentType.tank,
      ),
    );
    regulator = await repo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Apeks XTX50',
        type: EquipmentType.regulator,
      ),
    );
    const passportId = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
    await CylinderPassportRepository().assignPassportId(
      equipmentId: rentalAl80.id,
      passportId: passportId,
    );
    final t = DateTime(2026, 9, 20);
    await CylinderFillRepository().create(
      CylinderFill(
        id: '',
        passportId: passportId,
        equipmentId: rentalAl80.id,
        filledAt: t,
        o2Percent: 32,
        createdAt: t,
        updatedAt: t,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    void Function(DiveTank)? onChanged,
    Future<void> Function(EquipmentItem)? onOwnCylinderUsed,
    DiveTank tank = const DiveTank(id: 'tank-1'),
    List<dynamic> extra = const [],
  }) async {
    // Tall enough for the whole open menu: a menu opened on a chosen preset
    // scrolls to it, which would push the cylinders above it out of view.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presets = [
      _customPreset,
      ...TankPresets.all.map(TankPresetEntity.fromBuiltIn),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          tankPresetListNotifierProvider.overrideWith(
            (ref) => _PresetListNotifier(presets),
          ),
          tankPresetsProvider.overrideWith((ref) => Future.value(presets)),
          activeEquipmentProvider.overrideWith(
            (ref) async => [rentalAl80, faber, spare, nameOnly, regulator],
          ),
          ...extra,
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Feeds each change back in as the dive edit page does, so the
          // editor sees the tank it reported.
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SingleChildScrollView(
                child: TankEditor(
                  tank: tank,
                  tankNumber: 1,
                  onChanged: (t) {
                    setState(() => tank = t);
                    onChanged?.call(t);
                  },
                  onOwnCylinderUsed: onOwnCylinderUsed,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(TankEditor)));
  }

  final presetField = find.byKey(const Key('tank-preset-dropdown'));

  Future<void> openDropdown(WidgetTester tester) async {
    await tester.tap(presetField);
    await tester.pumpAndSettle();
  }

  /// Chooses the menu entry labelled [label]. The open menu draws on top of
  /// the field, so its entry is the last match.
  Future<void> choose(WidgetTester tester, String label) async {
    await openDropdown(tester);
    await tester.tap(find.text(label).last);
    // Reading the cylinder's fills is real database work.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  /// The label the closed dropdown shows, leaving out the field's own label.
  String shownPreset(WidgetTester tester) {
    final l10n = AppLocalizations.of(tester.element(find.byType(TankEditor)));
    final texts = tester.widgetList<Text>(
      find.descendant(of: presetField, matching: find.byType(Text)),
    );
    return texts
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s != l10n.diveLog_tank_label_tankPreset)
        .last;
  }

  testWidgets('lists the tank gear in use above custom and built-in presets', (
    tester,
  ) async {
    await pump(tester, onOwnCylinderUsed: (_) async {});
    await openDropdown(tester);

    final cylinderY = tester.getTopLeft(find.text(faber.name).last).dy;
    final rentalY = tester.getTopLeft(find.text(rentalAl80.name).last).dy;
    final customY = tester.getTopLeft(find.text('My Twin 7s').last).dy;
    final builtInY = tester.getTopLeft(find.text('AL100').last).dy;
    expect(rentalY, lessThan(customY));
    expect(cylinderY, lessThan(customY));
    expect(customY, lessThan(builtInY));
    expect(find.byKey(Key('tank-preset-cylinder-${faber.id}')), findsOneWidget);
    // Spare gear is not offered (#1803), nor is gear that is not a tank.
    expect(find.text(spare.name), findsNothing);
    expect(find.text(regulator.name), findsNothing);
  });

  // Choosing a cylinder that records no size or material would fill
  // nothing, yet still add it to the dive's gear. The "My cylinders" button
  // still offers it, since its picker says that picking adds it to the gear.
  testWidgets('leaves out a cylinder that records no spec', (tester) async {
    await pump(tester, onOwnCylinderUsed: (_) async {});
    await openDropdown(tester);

    expect(find.text(faber.name), findsWidgets);
    expect(find.text(nameOnly.name), findsNothing);
  });

  testWidgets('no cylinders listed when the host does not record gear', (
    tester,
  ) async {
    await pump(tester);
    await openDropdown(tester);

    expect(find.text(faber.name), findsNothing);
    expect(find.text(rentalAl80.name), findsNothing);
    expect(find.text('My Twin 7s'), findsWidgets);
  });

  testWidgets('a chosen cylinder fills spec and newest fill, joins the dive '
      'gear, and the dropdown shows the matching preset', (tester) async {
    DiveTank? changed;
    EquipmentItem? used;
    final l10n = await pump(
      tester,
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (item) async => used = item,
    );
    await choose(tester, rentalAl80.name);

    expect(changed!.volume, 11.1);
    expect(changed!.workingPressure, 207);
    expect(changed!.material, TankMaterial.aluminum);
    expect(changed!.gasMix.o2, 32);
    expect(changed!.presetName, 'al80');
    // A copy, never a link: the link belongs to the transmitter registry.
    expect(changed!.equipmentId, isNull);
    expect(used!.id, rentalAl80.id);
    expect(shownPreset(tester), 'AL80');
    expect(
      find.text(l10n.passport_scan_filledFrom(rentalAl80.name)),
      findsOneWidget,
    );
  });

  testWidgets('a cylinder matching no preset leaves "Select preset" shown', (
    tester,
  ) async {
    DiveTank? changed;
    final l10n = await pump(
      tester,
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (_) async {},
    );
    await choose(tester, faber.name);

    expect(changed!.volume, 12);
    expect(changed!.workingPressure, 232);
    expect(changed!.presetName, isNull);
    expect(shownPreset(tester), l10n.diveLog_tank_selectPreset);
  });

  // The preset already shown matches the cylinder chosen, so nothing about
  // the matched preset changes. The dropdown must still drop the cylinder
  // entry it was just given and show the preset again.
  testWidgets('a cylinder matching the preset already shown keeps showing '
      'that preset', (tester) async {
    await pump(tester, onOwnCylinderUsed: (_) async {});
    await choose(tester, 'AL80');
    expect(shownPreset(tester), 'AL80');

    await choose(tester, rentalAl80.name);
    expect(shownPreset(tester), 'AL80');
    expect(find.text(rentalAl80.name), findsNothing);
  });

  testWidgets('choosing a preset after a cylinder still applies the preset', (
    tester,
  ) async {
    DiveTank? changed;
    await pump(
      tester,
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (_) async {},
    );
    await choose(tester, faber.name);
    await choose(tester, 'AL80');

    expect(changed!.presetName, 'al80');
    expect(changed!.volume, closeTo(11.1, 0.01));
    expect(shownPreset(tester), 'AL80');
  });

  // The tank already uses a preset, so the field falls back to the tank's
  // own presetName once the chosen cylinder clears the selection.
  testWidgets('a cylinder matching no preset clears a preset the tank had', (
    tester,
  ) async {
    DiveTank? changed;
    final l10n = await pump(
      tester,
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (_) async {},
      tank: const DiveTank(
        id: 'tank-1',
        volume: 11.1,
        workingPressure: 207,
        presetName: 'al80',
      ),
    );
    expect(shownPreset(tester), 'AL80');

    await choose(tester, faber.name);
    expect(changed!.presetName, isNull);
    expect(shownPreset(tester), l10n.diveLog_tank_selectPreset);
  });

  // Choosing a cylinder adds it to the dive's gear, which choosing a preset
  // does not, so a screen reader must tell the two apart.
  testWidgets('a cylinder entry is announced as one of my cylinders', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final l10n = await pump(tester, onOwnCylinderUsed: (_) async {});
    await openDropdown(tester);

    expect(
      find.bySemanticsLabel(RegExp(l10n.diveLog_tank_ownCylinderTitle)),
      findsWidgets,
    );
    handle.dispose();
  });

  // A cylinder's fills load before it fills the tank. A preset chosen in
  // that window is the newer choice, so the cylinder must not overwrite it
  // when its fills arrive, nor join the dive's gear.
  testWidgets('a preset chosen while a cylinder loads is not overwritten', (
    tester,
  ) async {
    final fills = Completer<List<CylinderFill>>();
    DiveTank? changed;
    EquipmentItem? used;
    await pump(
      tester,
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (item) async => used = item,
      extra: [
        fillsForEquipmentProvider(faber.id).overrideWith((ref) => fills.future),
      ],
    );
    await openDropdown(tester);
    await tester.tap(find.text(faber.name).last);
    await tester.pumpAndSettle();
    await choose(tester, 'AL80');

    fills.complete(const []);
    await tester.pumpAndSettle();

    expect(changed!.presetName, 'al80');
    expect(changed!.volume, closeTo(11.1, 0.01));
    expect(changed!.workingPressure, 207);
    expect(used, isNull);
    expect(shownPreset(tester), 'AL80');
  });

  testWidgets('a failing gear add is reported, not left unhandled', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      onOwnCylinderUsed: (_) async => throw StateError('gear add failed'),
    );
    await choose(tester, faber.name);
    expect(find.text(l10n.diveLog_tank_ownCylinderFailed), findsOneWidget);
  });
}
