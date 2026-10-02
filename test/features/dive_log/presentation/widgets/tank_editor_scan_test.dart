import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/tag_fill_importer.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
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

class _BrokenImporter extends TagFillImporter {
  @override
  Future<CylinderFill?> importIfNew({
    required CylinderPassportPayload tag,
    required String equipmentId,
    required String? diverId,
  }) async => throw StateError('database is locked');
}

class _MissingEquipment extends EquipmentRepository {
  @override
  Future<EquipmentItem?> getEquipmentById(String id) async => null;
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
    Future<void> Function(EquipmentItem)? onOwnCylinderUsed,
    MockSettingsNotifier? settings,
    DiveTank tank = const DiveTank(id: 'tank-1'),
    List<dynamic> extra = const [],
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
      onOwnCylinderUsed: (item) async => scannedItem = item,
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
      onOwnCylinderUsed: (item) async => scannedItem = item,
    );
    await scan(tester);
    expect(changed!.volume, 10);
    expect(changed!.workingPressure, 300);
    expect(changed!.material, TankMaterial.aluminum);
    expect(changed!.gasMix.o2, 21);
    expect(scannedItem, isNull);
  });

  testWidgets("a foreign cylinder's tag fill sets the mix", (tester) async {
    DiveTank? changed;
    await pump(
      tester,
      scanned:
          'https://submersion.app/c#f=1&p=$stranger&v=10'
          '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11'
          '&ft=2026-09-28T09%3A30%3A00Z&fo=21&fh=35',
      onChanged: (t) => changed = t,
    );
    await scan(tester);
    expect((changed!.gasMix.o2, changed!.gasMix.he), (21.0, 35.0));
  });

  testWidgets("an own cylinder's newer tag fill is stored and used", (
    tester,
  ) async {
    DiveTank? changed;
    await pump(
      tester,
      scanned:
          'https://submersion.app/c#f=1&p=$own'
          '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f12'
          '&ft=2030-01-01T00%3A00%3A00Z&fo=21&fh=35',
      onChanged: (t) => changed = t,
    );
    await scan(tester);
    expect((changed!.gasMix.o2, changed!.gasMix.he), (21.0, 35.0));
    final stored = await tester.runAsync(
      () => CylinderFillRepository().getById(
        '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f12',
      ),
    );
    expect(stored!.source, FillSource.nfc);
  });

  const al80Tank = DiveTank(
    id: 'tank-1',
    volume: 11.1,
    workingPressure: 207,
    material: TankMaterial.aluminum,
    presetName: 'al80',
  );

  testWidgets('a tag with no details changes nothing and says so', (
    tester,
  ) async {
    DiveTank? changed;
    final l10n = await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$stranger',
      onChanged: (t) => changed = t,
      tank: al80Tank,
    );
    await scan(tester);
    expect(changed, isNull);
    expect(find.text(l10n.passport_foreign_noDetails), findsOneWidget);
  });

  testWidgets('a tag without volume or pressure keeps the preset', (
    tester,
  ) async {
    DiveTank? changed;
    await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$stranger&m=st',
      onChanged: (t) => changed = t,
      tank: al80Tank,
    );
    await scan(tester);
    expect(changed!.material, TankMaterial.steel);
    expect(changed!.presetName, 'al80');
    expect(changed!.volume, 11.1);
  });

  testWidgets('an own cylinder whose row is gone says the scan failed', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$own',
      onChanged: (_) {},
      extra: [
        equipmentRepositoryProvider.overrideWithValue(_MissingEquipment()),
      ],
    );
    await scan(tester);
    expect(find.text(l10n.passport_scan_openFailed), findsOneWidget);
  });

  testWidgets('a failing gear add is reported, not left unhandled', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$own',
      onChanged: (_) {},
      onOwnCylinderUsed: (item) async => throw StateError('gear add failed'),
    );
    await scan(tester);
    expect(find.text(l10n.passport_scan_openFailed), findsOneWidget);
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

  testWidgets('a fill that fails to import still fills the tank', (
    tester,
  ) async {
    DiveTank? changed;
    await pump(
      tester,
      scanned:
          'https://submersion.app/c#f=1&p=$own'
          '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11'
          '&ft=2026-09-28T09%3A30%3A00Z&fo=36',
      onChanged: (t) => changed = t,
      extra: [tagFillImporterProvider.overrideWithValue(_BrokenImporter())],
    );
    await scan(tester);
    expect(changed!.volume, 12);
    expect(changed!.workingPressure, 232);
  });

  testWidgets('a pressure-only tag keeps the tank volume in cubic feet', (
    tester,
  ) async {
    final settings = MockSettingsNotifier();
    await settings.setVolumeUnit(VolumeUnit.cubicFeet);
    await settings.setPressureUnit(PressureUnit.psi);
    DiveTank? changed;
    await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$stranger&wp=300',
      onChanged: (t) => changed = t,
      settings: settings,
      tank: al80Tank,
    );
    await scan(tester);
    // The field showed the AL80's rated cuft; a new pressure must not turn
    // that number into a different water volume.
    expect(changed!.volume, closeTo(11.1, 0.05));
    expect(changed!.workingPressure, closeTo(300, 0.5));
  });

  group('a tag with a volume but no working pressure, in cubic feet', () {
    Future<DiveTank?> scanVolumeOnly(WidgetTester tester, DiveTank tank) async {
      final settings = MockSettingsNotifier();
      await settings.setVolumeUnit(VolumeUnit.cubicFeet);
      await settings.setPressureUnit(PressureUnit.psi);
      DiveTank? changed;
      await pump(
        tester,
        scanned: 'https://submersion.app/c#f=1&p=$stranger&v=10',
        onChanged: (t) => changed = t,
        settings: settings,
        tank: tank,
      );
      await scan(tester);
      return changed;
    }

    testWidgets('shows the tag volume in liters when no pressure is known', (
      tester,
    ) async {
      await scanVolumeOnly(tester, const DiveTank(id: 'tank-1'));
      // With no working pressure the field is in liters (suffix "L").
      expect(find.widgetWithText(TextFormField, '10'), findsOneWidget);
    });

    testWidgets('an edit keeps the liters of a tank with no pressure', (
      tester,
    ) async {
      // A 10 L tank with no working pressure, then a tag that only changes
      // the material: the volume must not be reread as cubic feet.
      final settings = MockSettingsNotifier();
      await settings.setVolumeUnit(VolumeUnit.cubicFeet);
      DiveTank? changed;
      await pump(
        tester,
        scanned: 'https://submersion.app/c#f=1&p=$stranger&m=st',
        onChanged: (t) => changed = t,
        settings: settings,
        tank: const DiveTank(id: 'tank-1', volume: 10),
      );
      await scan(tester);
      expect(changed!.volume, closeTo(10, 0.05));
    });

    testWidgets('keeps the volume on a tank with no pressure', (tester) async {
      final changed = await scanVolumeOnly(
        tester,
        const DiveTank(id: 'tank-1'),
      );
      expect(changed!.volume, closeTo(10, 0.05));
    });

    testWidgets('keeps the volume, converted at the tank pressure', (
      tester,
    ) async {
      final changed = await scanVolumeOnly(
        tester,
        const DiveTank(id: 'tank-1', volume: 12, workingPressure: 232),
      );
      expect(changed!.volume, closeTo(10, 0.05));
      expect(changed.workingPressure, closeTo(232, 0.5));
    });
  });
}
