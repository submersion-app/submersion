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

void main() {
  testWidgets('choosing a regulator reports it on the tank', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final builtInPresets = TankPresets.all
        .map((p) => TankPresetEntity.fromBuiltIn(p))
        .toList();
    const regs = [
      EquipmentItem(
        id: 'reg-a',
        name: 'Apeks XTX',
        type: EquipmentType.regulator,
      ),
      EquipmentItem(id: 'mask', name: 'Mask', type: EquipmentType.mask),
    ];
    DiveTank? changed;

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
          tankPresetsProvider.overrideWith(
            (ref) => Future.value(builtInPresets),
          ),
          activeEquipmentProvider.overrideWith((ref) async => regs),
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
                onChanged: (t) => changed = t,
                onRemove: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('tank-regulator-picker')));
    await tester.tap(find.byKey(const Key('tank-regulator-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Mask').hitTestable(), findsNothing);
    await tester.tap(find.text('Apeks XTX').hitTestable());
    await tester.pumpAndSettle();

    expect(changed?.regulatorEquipmentId, 'reg-a');
  });
}
