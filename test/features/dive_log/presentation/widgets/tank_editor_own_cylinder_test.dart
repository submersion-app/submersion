import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_owner_chip.dart';
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
  double? volumeL,
  double? workingPressureBar,
  String? material,
  EquipmentStatus status = EquipmentStatus.active,
}) => EquipmentItem(
  id: '',
  name: name,
  type: EquipmentType.tank,
  status: status,
  attributes: [
    if (volumeL != null)
      EquipmentAttribute(
        id: '',
        equipmentId: '',
        key: EquipmentAttrKeys.volumeL,
        valueNum: volumeL,
      ),
    if (workingPressureBar != null)
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

/// Issue #2599: the tank editor's "My cylinders" picker is the bridge from a
/// cylinder in the diver's gear to a dive tank. It copies the cylinder into
/// the tank (the tank never links to it) and hands it to the host, which
/// adds it to the dive's equipment.
void main() {
  late EquipmentItem faber;
  late EquipmentItem bare;
  late EquipmentItem spare;
  late EquipmentItem regulator;

  setUp(() async {
    await setUpTestDatabase();
    final repo = EquipmentRepository();
    faber = await repo.createEquipment(
      _tank(
        'Faber 12',
        volumeL: 12,
        workingPressureBar: 232,
        material: 'steel',
      ),
    );
    bare = await repo.createEquipment(
      _tank('Rental AL80', volumeL: 11.1, workingPressureBar: 207),
    );
    spare = await repo.createEquipment(
      _tank('Old twinset', volumeL: 24, status: EquipmentStatus.spare),
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
      equipmentId: faber.id,
      passportId: passportId,
    );
    final t = DateTime(2026, 9, 20);
    await CylinderFillRepository().create(
      CylinderFill(
        id: '',
        passportId: passportId,
        equipmentId: faber.id,
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
    required void Function(DiveTank) onChanged,
    Future<void> Function(EquipmentItem)? onOwnCylinderUsed,
    List<EquipmentItem>? gear,
    List<dynamic> extra = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presets = TankPresets.all.map(TankPresetEntity.fromBuiltIn).toList();
    final active = gear ?? [faber, bare, spare, regulator];
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
          activeEquipmentProvider.overrideWith((ref) async => active),
          ...extra,
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TankEditor(
                tank: const DiveTank(id: 'tank-1'),
                tankNumber: 1,
                onChanged: onChanged,
                onOwnCylinderUsed: onOwnCylinderUsed,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(TankEditor)));
  }

  final pickerButton = find.byKey(const Key('tank-from-own-cylinder'));

  Future<void> pick(WidgetTester tester, EquipmentItem item) async {
    await tester.tap(pickerButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item.name));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a picked cylinder fills spec and newest fill, and joins the '
      'dive gear', (tester) async {
    DiveTank? changed;
    EquipmentItem? used;
    await pump(
      tester,
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (item) async => used = item,
    );
    await pick(tester, faber);

    expect(changed!.volume, 12);
    expect(changed!.workingPressure, 232);
    expect(changed!.material, TankMaterial.steel);
    expect(changed!.gasMix.o2, 32);
    // A copy, never a link: the link belongs to the transmitter registry.
    expect(changed!.equipmentId, isNull);
    expect(used!.id, faber.id);
  });

  testWidgets('a cylinder with no fills keeps the tank mix', (tester) async {
    DiveTank? changed;
    await pump(
      tester,
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (_) async {},
    );
    await pick(tester, bare);

    expect(changed!.volume, 11.1);
    expect(changed!.workingPressure, 207);
    expect(changed!.gasMix.o2, 21);
  });

  testWidgets('offers only the tank gear in use, and says what picking does', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      onChanged: (_) {},
      onOwnCylinderUsed: (_) async {},
    );
    await tester.tap(pickerButton);
    await tester.pumpAndSettle();

    expect(find.text(l10n.diveLog_tank_ownCylinderTitle), findsOneWidget);
    expect(find.text(l10n.diveLog_tank_ownCylinderHint), findsOneWidget);
    expect(find.text(faber.name), findsOneWidget);
    expect(find.text(bare.name), findsOneWidget);
    // Spare gear is not offered (#1803), nor is gear that is not a tank.
    expect(find.text(spare.name), findsNothing);
    expect(find.text(regulator.name), findsNothing);
  });

  // Shared gear is usable on a dive (#2046), so a cylinder another diver
  // shared is offered, marked with its owner as the gear list marks it.
  testWidgets('a shared cylinder is offered with its owner', (tester) async {
    final shared = faber.copyWith(
      id: 'eq-shared',
      name: 'Sam 15',
      diverId: 'diver-2',
    );
    await pump(
      tester,
      onChanged: (_) {},
      onOwnCylinderUsed: (_) async {},
      gear: [bare, shared],
      extra: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
        hasMultipleDiversProvider.overrideWithValue(true),
        diverNamesByIdProvider.overrideWith(
          (ref) async => {'diver-1': 'Alex', 'diver-2': 'Sam'},
        ),
      ],
    );
    await tester.tap(pickerButton);
    await tester.pumpAndSettle();

    Finder tileOf(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(ListTile));
    final sharedTile = tileOf('Sam 15');
    expect(
      find.descendant(
        of: sharedTile,
        matching: find.byType(EquipmentOwnerChip),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tileOf(bare.name),
        matching: find.byType(EquipmentOwnerChip),
      ),
      findsNothing,
    );
  });

  testWidgets('no picker when the diver owns no cylinder', (tester) async {
    await pump(
      tester,
      onChanged: (_) {},
      onOwnCylinderUsed: (_) async {},
      gear: [regulator, spare],
    );
    expect(pickerButton, findsNothing);
  });

  testWidgets('no picker when the host does not record gear', (tester) async {
    await pump(tester, onChanged: (_) {});
    expect(pickerButton, findsNothing);
  });

  testWidgets('a failing gear add is reported, not left unhandled', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      onChanged: (_) {},
      onOwnCylinderUsed: (_) async => throw StateError('gear add failed'),
    );
    await pick(tester, faber);
    expect(find.text(l10n.diveLog_tank_ownCylinderFailed), findsOneWidget);
  });
}
