import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

const _error = 'O2 and He must each be 0 to 100 and total 100 or less';

/// Issue #4714: the O2 and He fields took any number, so a typed 1000 was
/// stored as 1000% O2, a mix no gas can have. Like a mistype (#1900), an
/// impossible mix shows why and reports the last possible mix typed.
void main() {
  Future<DiveTank? Function()> pumpEditor(
    WidgetTester tester,
    DiveTank tank,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presets = TankPresets.all
        .map((p) => TankPresetEntity.fromBuiltIn(p))
        .toList();
    DiveTank? updated;

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
                onChanged: (t) => updated = t,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => updated;
  }

  testWidgets('an O2 over 100% says why and keeps the last possible mix', (
    tester,
  ) async {
    final updated = await pumpEditor(
      tester,
      const DiveTank(id: 't', volume: 12, gasMix: GasMix(o2: 32)),
    );

    await tester.enterText(find.widgetWithText(TextFormField, '32'), '1000');
    await tester.pump();

    expect(find.text(_error), findsOneWidget);
    expect(updated()!.gasMix, const GasMix(o2: 32));
  });

  testWidgets('shares adding up past 100% keep the last possible mix', (
    tester,
  ) async {
    final updated = await pumpEditor(
      tester,
      const DiveTank(id: 't', volume: 12, gasMix: GasMix(o2: 21, he: 35)),
    );

    await tester.enterText(find.widgetWithText(TextFormField, '35'), '90');
    await tester.pump();

    expect(find.text(_error), findsOneWidget);
    expect(updated()!.gasMix, const GasMix(o2: 21, he: 35));
  });

  testWidgets('a possible mix typed after an impossible one is taken', (
    tester,
  ) async {
    final updated = await pumpEditor(
      tester,
      const DiveTank(id: 't', volume: 12, gasMix: GasMix(o2: 32)),
    );
    final o2 = find.widgetWithText(TextFormField, '32');

    await tester.enterText(o2, '1000');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, '1000'), '100');
    await tester.pump();

    expect(find.text(_error), findsNothing);
    expect(updated()!.gasMix, const GasMix(o2: 100));
  });

  testWidgets('a cylinder stored impossible keeps what the diver types', (
    tester,
  ) async {
    // No possible mix to fall back to: keeping the stored 60/50 would drop
    // each edit until the fields happen to add up.
    final updated = await pumpEditor(
      tester,
      const DiveTank(id: 't', volume: 12, gasMix: GasMix(o2: 60, he: 50)),
    );

    await tester.enterText(find.widgetWithText(TextFormField, '50'), '45');
    await tester.pump();
    expect(updated()!.gasMix, const GasMix(o2: 60, he: 45));
    expect(find.text(_error), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '60'), '18');
    await tester.pump();
    expect(updated()!.gasMix, const GasMix(o2: 18, he: 45));
  });

  testWidgets('a trimix is taken without complaint', (tester) async {
    final updated = await pumpEditor(
      tester,
      const DiveTank(id: 't', volume: 12, gasMix: GasMix(o2: 18)),
    );

    await tester.enterText(find.widgetWithText(TextFormField, '0'), '45');
    await tester.pump();

    expect(find.text(_error), findsNothing);
    expect(updated()!.gasMix, const GasMix(o2: 18, he: 45));
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
