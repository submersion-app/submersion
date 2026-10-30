import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The dive editor's MOD line takes the ppO2 limit the tank's role calls
/// for on the dive, as the dive's Cylinders card does (issue #3752), not the
/// bottom limit for every tank.
void main() {
  const air = GasMix(o2: 21);
  const ean50 = GasMix(o2: 50);

  Future<void> pumpEditor(
    WidgetTester tester,
    DiveTank tank, {
    DiveMode diveMode = DiveMode.oc,
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presets = TankPresets.all
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
            (ref) => _Presets(presets),
          ),
          tankPresetsProvider.overrideWith((ref) => Future.value(presets)),
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
                onChanged: (_) {},
                diveMode: diveMode,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a deco tank shows its MOD at the deco limit', (tester) async {
    // EAN50 at the deco 1.6 is 22 m; at the bottom 1.4 it was 18 m.
    await pumpEditor(
      tester,
      const DiveTank(id: 't', volume: 7, gasMix: ean50, role: TankRole.deco),
    );

    expect(find.textContaining('MOD: 22m (ppO₂ 1.6)'), findsOneWidget);
  });

  testWidgets('picking a role moves the MOD to that role\'s limit', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      const DiveTank(id: 't', volume: 7, gasMix: ean50, role: TankRole.stage),
    );
    expect(find.textContaining('MOD: 18m (ppO₂ 1.4)'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<TankRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deco').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('MOD: 22m (ppO₂ 1.6)'), findsOneWidget);
  });

  testWidgets('a diluent takes the Dil MOD limit on a CCR dive', (
    tester,
  ) async {
    // Air at the Dil MOD 1.6 is 66.2 m; at the bottom 1.4 it is 56.7 m.
    await pumpEditor(
      tester,
      const DiveTank(id: 't', volume: 3, gasMix: air, role: TankRole.diluent),
      diveMode: DiveMode.ccr,
    );

    expect(find.textContaining('MOD: 66m (ppO₂ 1.6)'), findsOneWidget);
  });

  testWidgets('a diluent on an open-circuit dive takes the bottom limit', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      const DiveTank(id: 't', volume: 3, gasMix: air, role: TankRole.diluent),
    );

    expect(find.textContaining('MOD: 56m (ppO₂ 1.4)'), findsOneWidget);
  });
}

class _Presets extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _Presets(List<TankPresetEntity> presets) : super(AsyncValue.data(presets));

  @override
  Future<void> refresh() async {}

  @override
  Future<TankPresetEntity> addPreset(TankPresetEntity preset) async => preset;

  @override
  Future<void> updatePreset(TankPresetEntity preset) async {}

  @override
  Future<void> deletePreset(String id) async {}
}
