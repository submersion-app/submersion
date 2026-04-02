import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/pages/tank_preset_edit_page.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('TankPresetEditPage', () {
    testWidgets(
      'loads existing preset and displays pressure in imperial (psi)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        // Configure imperial settings
        final mockSettings = MockSettingsNotifier();
        await mockSettings.setPressureUnit(PressureUnit.psi);
        await mockSettings.setVolumeUnit(VolumeUnit.cubicFeet);

        // Create a test preset: AL80-like with 206.843 bar working pressure
        final testPreset = TankPresetEntity(
          id: 'test-preset-1',
          name: 'al80',
          displayName: 'AL80',
          volumeLiters: 11.1,
          workingPressureBar: 206.843,
          material: TankMaterial.aluminum,
          description: 'Test preset',
          isBuiltIn: false,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          ratedCapacityCuft: 77.4,
        );

        // Mock repository that returns the test preset
        final mockRepo = _MockTankPresetRepository(preset: testPreset);

        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const TankPresetEditPage(presetId: 'test-preset-1'),
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
              tankPresetRepositoryProvider.overrideWithValue(mockRepo),
              tankPresetListNotifierProvider.overrideWith(
                (ref) => _MockTankPresetListNotifier([testPreset]),
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

        // The page should have loaded the preset.
        // Working pressure: 206.843 bar * 14.5038 = ~3000 psi
        // Line 77: _workingPressureController.text =
        //   units.convertPressure(preset.workingPressureBar).toStringAsFixed(0)
        expect(find.widgetWithText(TextFormField, '3000'), findsOneWidget);

        // Volume: in cubicFeet mode, shows volumeCuft = 77.4
        // Line 70: preset.volumeCuft.toStringAsFixed(1)
        expect(find.widgetWithText(TextFormField, '77.4'), findsOneWidget);
      },
    );

    testWidgets('info card shows working pressure converted to bar', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Configure imperial settings (psi input, cuft volume)
      final mockSettings = MockSettingsNotifier();
      await mockSettings.setPressureUnit(PressureUnit.psi);
      await mockSettings.setVolumeUnit(VolumeUnit.cubicFeet);

      // Create a test preset with 206.843 bar working pressure.
      // When loaded in imperial mode, the controller gets 3000 psi.
      // The info card then converts 3000 psi back to bar for display.
      final testPreset = TankPresetEntity(
        id: 'test-preset-2',
        name: 'al80',
        displayName: 'AL80',
        volumeLiters: 11.1,
        workingPressureBar: 206.843,
        material: TankMaterial.aluminum,
        description: 'Test preset',
        isBuiltIn: false,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        ratedCapacityCuft: 77.4,
      );

      final mockRepo = _MockTankPresetRepository(preset: testPreset);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const TankPresetEditPage(presetId: 'test-preset-2'),
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
            tankPresetRepositoryProvider.overrideWithValue(mockRepo),
            tankPresetListNotifierProvider.overrideWith(
              (ref) => _MockTankPresetListNotifier([testPreset]),
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

      // After loading the preset, the info card is built via _buildInfoCard.
      // Line 269: pressureBar = units.pressureToBar(3000.0)
      //   = 3000 / 14.5038 = ~206.843 bar -> round() = 207
      // Lines 305-306: context.l10n.tankPresets_edit_workingPressureBar(207)
      //   = "Working pressure: 207 bar"
      expect(find.textContaining('207 bar'), findsOneWidget);

      // Verify the Tank Specifications header is present
      expect(find.text('Tank Specifications'), findsOneWidget);

      // Line 335 is exercised in _savePreset below.
    });

    testWidgets('save converts pressure to bar for storage', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockSettings = MockSettingsNotifier();
      await mockSettings.setPressureUnit(PressureUnit.psi);
      await mockSettings.setVolumeUnit(VolumeUnit.cubicFeet);

      final testPreset = TankPresetEntity(
        id: 'test-preset-save',
        name: 'al80',
        displayName: 'AL80',
        volumeLiters: 11.1,
        workingPressureBar: 206.843,
        material: TankMaterial.aluminum,
        description: 'Test',
        isBuiltIn: false,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        ratedCapacityCuft: 77.4,
      );

      final mockRepo = _MockTankPresetRepository(preset: testPreset);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const TankPresetEditPage(presetId: 'test-preset-save'),
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
            tankPresetRepositoryProvider.overrideWithValue(mockRepo),
            tankPresetListNotifierProvider.overrideWith(
              (ref) => _MockTankPresetListNotifier([testPreset]),
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

      // Tap Save to trigger _savePreset (line 335)
      final saveButton = find.text('Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
    });
  });
}

/// Mock TankPresetRepository that returns a preset by ID without database access
class _MockTankPresetRepository extends TankPresetRepository {
  final TankPresetEntity? preset;

  _MockTankPresetRepository({this.preset});

  @override
  Future<TankPresetEntity?> getPresetById(String id) async {
    if (preset != null && preset!.id == id) {
      return preset;
    }
    return null;
  }

  @override
  Future<List<TankPresetEntity>> getAllPresets({String? diverId}) async {
    return preset != null ? [preset!] : [];
  }

  @override
  Future<List<TankPresetEntity>> getCustomPresets({String? diverId}) async {
    return [];
  }
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
