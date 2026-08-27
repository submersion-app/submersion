import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('TankEditor', () {
    testWidgets('renders pressure values in metric (bar)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockSettings = MockSettingsNotifier();
      // Default is metric (bar)

      final builtInPresets = TankPresets.all
          .map((p) => TankPresetEntity.fromBuiltIn(p))
          .toList();

      const tank = DiveTank(
        id: 'tank-1',
        volume: 11.1,
        workingPressure: 206.843, // bar
        startPressure: 200.0,
        endPressure: 50.0,
        gasMix: GasMix(o2: 21.0, he: 0.0),
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
            tankPresetsProvider.overrideWith(
              (ref) => Future.value(builtInPresets),
            ),
          ].cast(),
          child: MaterialApp(
            // Pinned: an unpinned MaterialApp resolves against the host
            // machine's locale list, so English label assertions below fail
            // on a non-English dev machine.
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: TankEditor(
                  tank: tank,
                  tankNumber: 1,
                  onChanged: (_) {},
                  onRemove: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Working pressure: 206.843 bar -> "207" (toStringAsFixed(0))
      expect(find.widgetWithText(TextFormField, '207'), findsOneWidget);
      // Start pressure: 200.0 bar -> "200"
      expect(find.widgetWithText(TextFormField, '200'), findsOneWidget);
      // End pressure: 50.0 bar -> "50"
      expect(find.widgetWithText(TextFormField, '50'), findsOneWidget);
    });

    testWidgets('renders pressure values in imperial (psi)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockSettings = MockSettingsNotifier();
      await mockSettings.setPressureUnit(PressureUnit.psi);
      await mockSettings.setVolumeUnit(VolumeUnit.cubicFeet);

      final builtInPresets = TankPresets.all
          .map((p) => TankPresetEntity.fromBuiltIn(p))
          .toList();

      // AL80: 11.1L at 206.843 bar (3000 psi)
      const tank = DiveTank(
        id: 'tank-2',
        volume: 11.1,
        workingPressure: 206.843, // bar -> 3000 psi
        startPressure: 200.0, // bar -> 2901 psi
        endPressure: 50.0, // bar -> 725 psi
        gasMix: GasMix(o2: 32.0, he: 0.0),
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
            tankPresetsProvider.overrideWith(
              (ref) => Future.value(builtInPresets),
            ),
          ].cast(),
          child: MaterialApp(
            // Pinned: an unpinned MaterialApp resolves against the host
            // machine's locale list, so English label assertions below fail
            // on a non-English dev machine.
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: TankEditor(
                  tank: tank,
                  tankNumber: 1,
                  onChanged: (_) {},
                  onRemove: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Working pressure: 206.843 bar * 14.5038 = ~3000 psi
      expect(find.widgetWithText(TextFormField, '3000'), findsOneWidget);
      // Start pressure: 200.0 bar * 14.5038 = ~2901 psi
      expect(find.widgetWithText(TextFormField, '2901'), findsOneWidget);
      // End pressure: 50.0 bar * 14.5038 = ~725 psi
      expect(find.widgetWithText(TextFormField, '725'), findsOneWidget);
    });

    testWidgets('notifyChange converts pressure back to bar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockSettings = MockSettingsNotifier();
      await mockSettings.setPressureUnit(PressureUnit.psi);
      await mockSettings.setVolumeUnit(VolumeUnit.cubicFeet);

      final builtInPresets = TankPresets.all
          .map((p) => TankPresetEntity.fromBuiltIn(p))
          .toList();

      const tank = DiveTank(
        id: 'tank-3',
        volume: 11.1,
        workingPressure: 206.843,
        startPressure: 200.0,
        endPressure: 50.0,
        gasMix: GasMix(o2: 21.0, he: 0.0),
      );

      DiveTank? updatedTank;

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
            tankPresetsProvider.overrideWith(
              (ref) => Future.value(builtInPresets),
            ),
          ].cast(),
          child: MaterialApp(
            // Pinned: an unpinned MaterialApp resolves against the host
            // machine's locale list, so English label assertions below fail
            // on a non-English dev machine.
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: TankEditor(
                  tank: tank,
                  tankNumber: 1,
                  onChanged: (t) => updatedTank = t,
                  onRemove: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Edit the working pressure field to trigger _notifyChange
      // The field currently shows "3000" (psi). Change it to "3500".
      final wpField = find.widgetWithText(TextFormField, '3000');
      expect(wpField, findsOneWidget);
      await tester.enterText(wpField, '3500');
      await tester.pump();

      // The onChanged callback should receive a tank with working pressure
      // converted back to bar: 3500 psi / 14.5038 = ~241.3 bar
      expect(updatedTank, isNotNull);
      expect(updatedTank!.workingPressure, closeTo(241.3, 0.5));

      // Start pressure should also be converted back to bar
      // 2901 psi (displayed) -> ~200 bar
      expect(updatedTank!.startPressure, closeTo(200.0, 0.5));

      // End pressure: 725 psi -> ~50 bar
      expect(updatedTank!.endPressure, closeTo(50.0, 0.5));
    });

    testWidgets('applyPreset shows volumeCuft in imperial mode', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockSettings = MockSettingsNotifier();
      await mockSettings.setPressureUnit(PressureUnit.psi);
      await mockSettings.setVolumeUnit(VolumeUnit.cubicFeet);

      final builtInPresets = TankPresets.all
          .map((p) => TankPresetEntity.fromBuiltIn(p))
          .toList();

      // Start with a blank tank (no preset applied)
      const tank = DiveTank(id: 'tank-4', gasMix: GasMix(o2: 21.0, he: 0.0));

      DiveTank? updatedTank;

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
            tankPresetsProvider.overrideWith(
              (ref) => Future.value(builtInPresets),
            ),
          ].cast(),
          child: MaterialApp(
            // Pinned: an unpinned MaterialApp resolves against the host
            // machine's locale list, so English label assertions below fail
            // on a non-English dev machine.
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: TankEditor(
                  tank: tank,
                  tankNumber: 1,
                  onChanged: (t) => updatedTank = t,
                  onRemove: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the preset dropdown and select AL80
      final presetDropdown = find.byType(
        DropdownButtonFormField<TankPresetEntity?>,
      );
      expect(presetDropdown, findsOneWidget);
      await tester.tap(presetDropdown);
      await tester.pumpAndSettle();

      // Find and tap the AL80 preset in the dropdown menu
      final al80Item = find.text('AL80').last;
      await tester.tap(al80Item);
      await tester.pumpAndSettle();

      // After applying the AL80 preset in imperial mode,
      // volume should show volumeCuft: 77.4 -> "77.4"
      // (line 703: preset.volumeCuft.toStringAsFixed(1))
      expect(find.widgetWithText(TextFormField, '77.4'), findsOneWidget);

      // Working pressure should show 3000 psi
      expect(find.widgetWithText(TextFormField, '3000'), findsOneWidget);

      // The onChanged callback should use the preset's authoritative
      // volumeLiters (11.1), not a back-calculated value from cuft
      expect(updatedTank, isNotNull);
      expect(updatedTank!.presetName, 'al80');
      expect(updatedTank!.volume, 11.1);
    });

    testWidgets('Save as preset creates a custom preset from current specs', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final builtInPresets = TankPresets.all
          .map((p) => TankPresetEntity.fromBuiltIn(p))
          .toList();
      final notifier = _MockTankPresetListNotifier(builtInPresets);

      const tank = DiveTank(
        id: 'tank-1',
        volume: 11.1,
        workingPressure: 232.0, // bar (metric default)
        gasMix: GasMix(o2: 21.0, he: 0.0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            tankPresetListNotifierProvider.overrideWith((ref) => notifier),
            tankPresetsProvider.overrideWith(
              (ref) => Future.value(builtInPresets),
            ),
          ].cast(),
          child: MaterialApp(
            // Pinned: an unpinned MaterialApp resolves against the host
            // machine's locale list, so English label assertions below fail
            // on a non-English dev machine.
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: TankEditor(tank: tank, tankNumber: 1, onChanged: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save as preset'));
      await tester.pumpAndSettle();

      // Name dialog: enter a name and confirm.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'My AL80',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final added = notifier.lastAddedPreset;
      expect(added, isNotNull);
      expect(added!.displayName, 'My AL80');
      expect(added.volumeLiters, closeTo(11.1, 0.01));
      expect(added.workingPressureBar, closeTo(232.0, 0.01));
      expect(added.isBuiltIn, isFalse);
      expect(find.textContaining('Saved preset'), findsOneWidget);
    });

    testWidgets('Save as preset reports a failed save instead of throwing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final builtInPresets = TankPresets.all
          .map((p) => TankPresetEntity.fromBuiltIn(p))
          .toList();
      final notifier = _MockTankPresetListNotifier(builtInPresets)
        ..addPresetError = Exception('db is down');

      const tank = DiveTank(
        id: 'tank-1',
        volume: 11.1,
        workingPressure: 232.0,
        gasMix: GasMix(o2: 21.0, he: 0.0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            tankPresetListNotifierProvider.overrideWith((ref) => notifier),
            tankPresetsProvider.overrideWith(
              (ref) => Future.value(builtInPresets),
            ),
          ].cast(),
          child: MaterialApp(
            // Pinned: an unpinned MaterialApp resolves against the host
            // machine's locale list, so English label assertions below fail
            // on a non-English dev machine.
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: TankEditor(tank: tank, tankNumber: 1, onChanged: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save as preset'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'My AL80',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // The failure is reported to the user, not raised as a framework error,
      // and no preset is selected.
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Error saving preset'), findsOneWidget);
      expect(find.textContaining('Saved preset'), findsNothing);
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

  TankPresetEntity? lastAddedPreset;

  /// When set, [addPreset] throws this instead of succeeding, standing in for
  /// a failed database write.
  Object? addPresetError;

  @override
  Future<TankPresetEntity> addPreset(TankPresetEntity preset) async {
    if (addPresetError != null) throw addPresetError!;
    lastAddedPreset = preset;
    return preset;
  }

  @override
  Future<void> updatePreset(TankPresetEntity preset) async {}

  @override
  Future<void> deletePreset(String id) async {}
}
