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
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
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

void main() {
  const own = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const stranger = '11111111-2222-4333-8444-555555555555';
  late String ownId;

  setUp(() async {
    await setUpTestDatabase();
    final item = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Faber 12',
        type: EquipmentType.tank,
        attributes: [
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: EquipmentAttrKeys.volumeL,
            valueNum: 12,
          ),
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: EquipmentAttrKeys.workingPressureBar,
            valueNum: 232,
          ),
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: EquipmentAttrKeys.tankMaterial,
            valueText: 'steel',
          ),
        ],
      ),
    );
    ownId = item.id;
    await CylinderPassportRepository().assignPassportId(
      equipmentId: ownId,
      passportId: own,
    );
    final t = DateTime(2026, 9, 20);
    await CylinderFillRepository().create(
      CylinderFill(
        id: '',
        passportId: own,
        equipmentId: ownId,
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
    required String? scanned,
    required void Function(DiveTank) onChanged,
    void Function(EquipmentItem)? onCylinderScanned,
    MockSettingsNotifier? settings,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presets = TankPresets.all.map(TankPresetEntity.fromBuiltIn).toList();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => settings ?? MockSettingsNotifier(),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          tankPresetListNotifierProvider.overrideWith(
            (ref) => _PresetListNotifier(presets),
          ),
          tankPresetsProvider.overrideWith((ref) => Future.value(presets)),
          activeEquipmentProvider.overrideWith((ref) async => const []),
          passportScanLauncherProvider.overrideWithValue(
            (context) async => scanned,
          ),
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
                onCylinderScanned: onCylinderScanned,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(TankEditor)));
  }

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('tank-scan-tag')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an own cylinder fills spec and mix and joins the dive gear', (
    tester,
  ) async {
    DiveTank? changed;
    EquipmentItem? scannedItem;
    await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$own',
      onChanged: (t) => changed = t,
      onCylinderScanned: (item) => scannedItem = item,
    );
    await scan(tester);
    expect(changed!.volume, 12);
    expect(changed!.workingPressure, 232);
    expect(changed!.material, TankMaterial.steel);
    expect(changed!.gasMix.o2, 32);
    expect(changed!.equipmentId, isNull);
    expect(scannedItem!.id, ownId);
  });

  testWidgets('a foreign cylinder fills the spec only', (tester) async {
    DiveTank? changed;
    EquipmentItem? scannedItem;
    await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$stranger&v=10&wp=300&m=al',
      onChanged: (t) => changed = t,
      onCylinderScanned: (item) => scannedItem = item,
    );
    await scan(tester);
    expect(changed!.volume, 10);
    expect(changed!.workingPressure, 300);
    expect(changed!.material, TankMaterial.aluminum);
    expect(changed!.gasMix.o2, 21);
    expect(scannedItem, isNull);
  });

  testWidgets('text that is not a tag changes nothing', (tester) async {
    DiveTank? changed;
    final l10n = await pump(
      tester,
      scanned: 'hello',
      onChanged: (t) => changed = t,
    );
    await scan(tester);
    expect(changed, isNull);
    expect(find.text(l10n.passport_tag_linkInvalid), findsOneWidget);
  });

  testWidgets('imperial units round trip to the same metric spec', (
    tester,
  ) async {
    final settings = MockSettingsNotifier()
      ..setPressureUnit(PressureUnit.psi)
      ..setVolumeUnit(VolumeUnit.cubicFeet);
    DiveTank? changed;
    await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$own',
      onChanged: (t) => changed = t,
      settings: settings,
    );
    await scan(tester);
    expect(changed!.volume, closeTo(12, 0.1));
    expect(changed!.workingPressure, closeTo(232, 0.5));
  });
}
