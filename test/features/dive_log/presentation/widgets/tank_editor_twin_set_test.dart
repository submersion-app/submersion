import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
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

/// Issue #4242: picking a cylinder linked as a twin set asks whether the
/// tank is the twin set or that cylinder alone. The twin set is one tank
/// with the Twin Set role, the pair's volume and the lower working pressure,
/// naming both cylinders, and both join the dive's gear.
void main() {
  late EquipmentItem a;
  late EquipmentItem b;
  const passportA = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  setUp(() async {
    await setUpTestDatabase();
    final repo = EquipmentRepository();
    a = await repo.createEquipment(
      _tank(
        'Faber 12 A',
        volumeL: 12,
        workingPressureBar: 232,
        material: 'steel',
      ),
    );
    b = await repo.createEquipment(
      _tank(
        'Faber 12 B',
        volumeL: 12,
        workingPressureBar: 300,
        material: 'steel',
      ),
    );
    await CylinderPassportRepository().assignPassportId(
      equipmentId: a.id,
      passportId: passportA,
    );
    final t = DateTime(2026, 9, 20);
    await CylinderFillRepository().create(
      CylinderFill(
        id: '',
        passportId: passportA,
        equipmentId: a.id,
        filledAt: t,
        o2Percent: 32,
        createdAt: t,
        updatedAt: t,
      ),
    );
    await CylinderPairingRepository().createPairing(
      cylinderAId: a.id,
      cylinderBId: b.id,
      pairedOn: DateTime(2026, 1, 1),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required void Function(DiveTank) onChanged,
    Future<void> Function(EquipmentItem)? onOwnCylinderUsed,
    List<EquipmentItem>? gear,
    List<dynamic> extra = const [],
    DiveTank tank = const DiveTank(id: 'tank-1'),
    DateTime? diveDate,
    AppSettings? settings,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presets = TankPresets.all.map(TankPresetEntity.fromBuiltIn).toList();
    final active = gear ?? [a, b];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(settings ?? const AppSettings()),
          ),
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
                tank: tank,
                tankNumber: 1,
                onChanged: onChanged,
                onOwnCylinderUsed: onOwnCylinderUsed,
                diveDate: diveDate,
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
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a linked cylinder asks, and the twin set fills one tank for '
      'both', (tester) async {
    DiveTank? changed;
    final used = <String>[];
    final l10n = await pump(
      tester,
      gear: [a, b],
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (item) async => used.add(item.id),
    );
    await pick(tester, a);
    expect(find.text(l10n.twinSet_choiceTitle), findsOneWidget);
    final pairLabel = l10n.twinSet_choicePair(
      'Faber 12 A',
      'Faber 12 B',
      '24 L',
    );
    expect(find.text(pairLabel), findsOneWidget);
    expect(find.text(l10n.twinSet_choiceSingle('Faber 12 A')), findsOneWidget);

    await choose(tester, pairLabel);
    expect(changed!.role, TankRole.twinSet);
    expect(changed!.volume, 24);
    expect(changed!.workingPressure, 232);
    expect(changed!.gasMix.o2, 32);
    expect(changed!.passportId, passportA);
    final passportB = await tester.runAsync(
      () => CylinderPassportRepository().getPassportId(b.id),
    );
    expect(passportB, isNotNull);
    expect(changed!.twinPassportId, passportB);
    expect(used, [a.id, b.id]);
  });

  testWidgets('in cubic feet the pair\'s volume is added in liters', (
    tester,
  ) async {
    DiveTank? changed;
    final l10n = await pump(
      tester,
      gear: [a, b],
      settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (_) async {},
    );
    await pick(tester, a);
    await choose(
      tester,
      l10n.twinSet_choicePair(
        'Faber 12 A',
        'Faber 12 B',
        const UnitFormatter(
          AppSettings(volumeUnit: VolumeUnit.cubicFeet),
        ).formatTankVolume(24, 232),
      ),
    );
    expect(changed!.volume, closeTo(24, 0.1));
  });

  testWidgets('Just A keeps today\'s single cylinder', (tester) async {
    DiveTank? changed;
    final used = <String>[];
    final l10n = await pump(
      tester,
      gear: [a, b],
      tank: const DiveTank(id: 'tank-1', twinPassportId: 'stale'),
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (item) async => used.add(item.id),
    );
    await pick(tester, a);
    await choose(tester, l10n.twinSet_choiceSingle('Faber 12 A'));
    expect(changed!.volume, 12);
    expect(changed!.role, isNot(TankRole.twinSet));
    expect(changed!.passportId, passportA);
    expect(changed!.twinPassportId, isNull);
    expect(used, [a.id]);
  });

  testWidgets('a dive from before the pairing does not ask', (tester) async {
    DiveTank? changed;
    final l10n = await pump(
      tester,
      gear: [a, b],
      diveDate: DateTime(2025, 6, 1),
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (_) async {},
    );
    await pick(tester, a);
    expect(find.text(l10n.twinSet_choiceTitle), findsNothing);
    expect(changed!.volume, 12);
  });

  testWidgets('a picked cylinder with no passport gets one, so both count '
      'the dive', (tester) async {
    DiveTank? changed;
    final l10n = await pump(
      tester,
      gear: [a, b],
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (_) async {},
    );
    await pick(tester, b);
    await choose(
      tester,
      l10n.twinSet_choicePair('Faber 12 B', 'Faber 12 A', '24 L'),
    );
    final passportB = await tester.runAsync(
      () => CylinderPassportRepository().getPassportId(b.id),
    );
    expect(passportB, isNotNull);
    expect(changed!.passportId, passportB);
    expect(changed!.twinPassportId, passportA);
  });

  testWidgets('Just A on a tank that was a twin set goes back to back gas', (
    tester,
  ) async {
    DiveTank? changed;
    final l10n = await pump(
      tester,
      gear: [a, b],
      tank: const DiveTank(
        id: 'tank-1',
        role: TankRole.twinSet,
        volume: 24,
        passportId: 'p-a',
        twinPassportId: 'p-b',
      ),
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (_) async {},
    );
    await pick(tester, a);
    await choose(tester, l10n.twinSet_choiceSingle('Faber 12 A'));
    expect(changed!.role, TankRole.backGas);
    expect(changed!.volume, 12);
  });

  testWidgets('a pair with a cylinder of unknown size is not offered', (
    tester,
  ) async {
    final repo = EquipmentRepository();
    final sized = await tester.runAsync(
      () => repo.createEquipment(_tank('Sized', volumeL: 10)),
    );
    final unsized = await tester.runAsync(
      () => repo.createEquipment(_tank('Unsized')),
    );
    await tester.runAsync(
      () => CylinderPairingRepository().createPairing(
        cylinderAId: sized!.id,
        cylinderBId: unsized!.id,
        pairedOn: DateTime(2026, 1, 1),
      ),
    );
    DiveTank? changed;
    final l10n = await pump(
      tester,
      gear: [sized!, unsized!],
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (_) async {},
    );
    await pick(tester, sized);
    expect(find.text(l10n.twinSet_choiceTitle), findsNothing);
    expect(changed!.volume, 10);
  });

  testWidgets('doubles kept as one gear item keep their Twin Set role', (
    tester,
  ) async {
    final doubles = await tester.runAsync(
      () => EquipmentRepository().createEquipment(
        _tank('Doubles', volumeL: 24, workingPressureBar: 232),
      ),
    );
    DiveTank? changed;
    await pump(
      tester,
      gear: [doubles!],
      tank: const DiveTank(id: 'tank-1', role: TankRole.twinSet),
      onChanged: (t) => changed = t,
      onOwnCylinderUsed: (_) async {},
    );
    await pick(tester, doubles);
    expect(changed!.volume, 24);
    expect(changed!.role, TankRole.twinSet);
  });
}
