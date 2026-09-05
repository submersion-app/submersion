import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/enums.dart';
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

      // AL100 (issue #1557): 100 cuft at its own 3300 psi service pressure,
      // listed alongside the 3000 psi aluminium tanks.
      expect(find.text('AL100'), findsOneWidget);
      expect(find.textContaining('3300 psi'), findsOneWidget);
    });

    testWidgets('a custom preset whose slug collides with a built-in keeps its '
        'own name', (tester) async {
      // TankPresetEntity.generateSlug('Steel 12L') is 'steel12l', but a diver
      // can land on a built-in slug exactly -- nothing rejects a custom preset
      // named so that it slugs to one. Only isBuiltIn rows may be relabelled
      // from the built-in translation table.
      final now = DateTime(2026);
      final presets = [
        TankPresetEntity.fromBuiltIn(TankPresets.steel12),
        TankPresetEntity(
          id: 'custom-1',
          name: 'steel12',
          displayName: 'My Steel 12L',
          volumeLiters: 12,
          workingPressureBar: 232,
          material: TankMaterial.steel,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockSettings = MockSettingsNotifier();

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
              (ref) => _MockTankPresetListNotifier(presets),
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

      expect(find.text('My Steel 12L'), findsOneWidget);
      expect(find.text('Steel 12L'), findsOneWidget);
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
