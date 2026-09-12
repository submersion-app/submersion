import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

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

const _apeks = EquipmentItem(
  id: 'reg-a',
  name: 'Apeks XTX',
  type: EquipmentType.regulator,
);

const _spareReg = EquipmentItem(
  id: 'reg-spare',
  name: 'Spare Octo',
  type: EquipmentType.regulator,
  status: EquipmentStatus.spare,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<EquipmentItem> equipment,
  DiveTank tank = const DiveTank(id: 'tank-1'),
  void Function(DiveTank)? onChanged,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final builtInPresets = TankPresets.all
      .map((p) => TankPresetEntity.fromBuiltIn(p))
      .toList();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        tankPresetListNotifierProvider.overrideWith(
          (ref) => _PresetListNotifier(builtInPresets),
        ),
        tankPresetsProvider.overrideWith((ref) => Future.value(builtInPresets)),
        activeEquipmentProvider.overrideWith((ref) async => equipment),
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
              onChanged: onChanged ?? (_) {},
              onRemove: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openRegulatorPicker(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('tank-regulator-picker')));
  await tester.tap(find.byKey(const Key('tank-regulator-picker')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('choosing a regulator reports it on the tank', (tester) async {
    DiveTank? changed;
    await _pump(
      tester,
      equipment: const [
        _apeks,
        EquipmentItem(id: 'mask', name: 'Mask', type: EquipmentType.mask),
      ],
      onChanged: (t) => changed = t,
    );

    await _openRegulatorPicker(tester);
    expect(find.text('Mask').hitTestable(), findsNothing);
    await tester.tap(find.text('Apeks XTX').hitTestable());
    await tester.pumpAndSettle();

    expect(changed?.regulatorEquipmentId, 'reg-a');
  });

  group('spare regulators (#1803)', () {
    testWidgets('are not offered for a tank that does not use one', (
      tester,
    ) async {
      await _pump(tester, equipment: const [_apeks, _spareReg]);

      await _openRegulatorPicker(tester);

      expect(find.text('Apeks XTX').hitTestable(), findsOneWidget);
      expect(find.text('Spare Octo').hitTestable(), findsNothing);
    });

    testWidgets('stay shown on a tank already breathing from one', (
      tester,
    ) async {
      // Marking a regulator Spare must not make an existing dive's tank read
      // "None" for a regulator it really used.
      await _pump(
        tester,
        equipment: const [_apeks, _spareReg],
        tank: const DiveTank(id: 'tank-1', regulatorEquipmentId: 'reg-spare'),
      );

      expect(find.text('Spare Octo'), findsOneWidget);
      expect(find.text('None'), findsNothing);
    });
  });
}
