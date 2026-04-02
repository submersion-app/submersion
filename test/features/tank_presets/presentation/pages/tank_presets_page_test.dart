import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/pages/tank_presets_page.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('TankPresetsPage', () {
    testWidgets('renders built-in presets with imperial volume and pressure', (
      tester,
    ) async {
      final builtInPresets = TankPresets.all
          .map((p) => TankPresetEntity.fromBuiltIn(p))
          .toList();

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Create a mock settings notifier with imperial units
      final mockSettings = MockSettingsNotifier();
      await mockSettings.setVolumeUnit(VolumeUnit.cubicFeet);
      await mockSettings.setPressureUnit(PressureUnit.psi);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const TankPresetsPage(),
          ),
          GoRoute(
            path: '/tank-presets/new',
            builder: (context, state) => const Scaffold(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => mockSettings),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            tankPresetListNotifierProvider.overrideWith(
              (ref) => _MockTankPresetListNotifier(builtInPresets),
            ),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the page renders
      expect(find.byType(TankPresetsPage), findsOneWidget);

      // AL80 should show 77 cuft (ratedCapacityCuft=77.4, decimals=0)
      expect(find.textContaining('77 cuft'), findsOneWidget);

      // AL80 working pressure 206.843 bar = ~3000 psi, displayed as "3000 psi"
      expect(find.textContaining('3000 psi'), findsWidgets);
    });
  });
}

/// Simple mock that directly holds preset data in state
class _MockTankPresetListNotifier
    extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _MockTankPresetListNotifier(List<TankPresetEntity> presets)
    : super(AsyncValue.data(presets));

  @override
  Future<void> refresh() async {}

  @override
  Future<TankPresetEntity> addPreset(TankPresetEntity preset) async => preset;

  @override
  Future<void> updatePreset(TankPresetEntity preset) async {}

  @override
  Future<void> deletePreset(String id) async {}
}
