import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ccr_settings_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/scr_settings_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Locale-aware numeric entry for tanks, gas mixes and rebreather panels
/// (#1091).
///
/// Two behaviours are pinned per widget:
///
/// 1. A comma-decimal diver's input is accepted rather than discarded.
/// 2. Opening an existing record and notifying without touching a field is a
///    no-op. Under de the '.' is the grouping separator, so a field still
///    seeded with `toStringAsFixed` would read back ten times too large; that
///    is the regression these guard.
void main() {
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  group('TankEditor', () {
    testWidgets('accepts a comma decimal for volume and gas O2 under fr', (
      tester,
    ) async {
      Intl.defaultLocale = 'fr';

      const tank = DiveTank(
        id: 'tank-fr',
        volume: 12.5,
        workingPressure: 232.0,
        gasMix: GasMix(o2: 21.0, he: 0.0),
      );

      DiveTank? updated;
      await _pumpTankEditor(tester, tank, (t) => updated = t);

      // Seeded through the diver's locale, so the field already reads "12,5".
      await tester.enterText(
        find.widgetWithText(TextFormField, '12,5'),
        '15,3',
      );
      await tester.pump();
      expect(updated!.volume, closeTo(15.3, 0.001));

      await tester.enterText(find.widgetWithText(TextFormField, '21'), '31,5');
      await tester.pump();
      expect(updated!.gasMix.o2, closeTo(31.5, 0.001));
    });

    testWidgets('an untouched fractional volume survives a save under de', (
      tester,
    ) async {
      Intl.defaultLocale = 'de';

      const tank = DiveTank(
        id: 'tank-de',
        volume: 12.5,
        workingPressure: 232.0,
        startPressure: 200.0,
        endPressure: 50.0,
        gasMix: GasMix(o2: 21.0, he: 0.0),
      );

      DiveTank? updated;
      await _pumpTankEditor(tester, tank, (t) => updated = t);

      expect(find.widgetWithText(TextFormField, '12,5'), findsOneWidget);

      // Tapping a gas template notifies without going near the tank specs, so
      // whatever comes back for volume is purely the seed/parse round trip.
      final chip = find.byType(FilterChip).first;
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.volume, closeTo(12.5, 0.001));
      expect(updated!.workingPressure, closeTo(232.0, 0.01));
      expect(updated!.startPressure, closeTo(200.0, 0.01));
      expect(updated!.endPressure, closeTo(50.0, 0.01));
    });
  });

  group('CcrSettingsPanel', () {
    testWidgets('accepts a comma decimal setpoint under fr', (tester) async {
      Intl.defaultLocale = 'fr';

      double? capturedHigh;
      await _pumpPanel(
        tester,
        CcrSettingsPanel(
          setpointHigh: 1.30,
          onChanged:
              ({
                setpointLow,
                setpointHigh,
                setpointDeco,
                diluentGas,
                scrubberType,
                scrubberDurationMinutes,
                scrubberRemainingMinutes,
                loopVolume,
              }) => capturedHigh = setpointHigh,
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, '1,3'), '1,25');
      await tester.pump();

      expect(capturedHigh, closeTo(1.25, 0.0001));
    });

    testWidgets('untouched setpoints and loop volume survive a save under de', (
      tester,
    ) async {
      Intl.defaultLocale = 'de';

      double? capturedLow;
      double? capturedHigh;
      double? capturedLoopVolume;
      int? capturedDuration;
      GasMix? capturedDiluent;
      await _pumpPanel(
        tester,
        CcrSettingsPanel(
          setpointLow: 0.7,
          setpointHigh: 1.25,
          loopVolume: 5.5,
          scrubberDurationMinutes: 180,
          diluentGas: const GasMix(o2: 18.0, he: 45.0),
          onChanged:
              ({
                setpointLow,
                setpointHigh,
                setpointDeco,
                diluentGas,
                scrubberType,
                scrubberDurationMinutes,
                scrubberRemainingMinutes,
                loopVolume,
              }) {
                capturedLow = setpointLow;
                capturedHigh = setpointHigh;
                capturedLoopVolume = loopVolume;
                capturedDuration = scrubberDurationMinutes;
                capturedDiluent = diluentGas;
              },
        ),
      );

      expect(find.widgetWithText(TextFormField, '1,25'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '5,5'), findsOneWidget);

      // The scrubber type is free text, so typing there notifies without
      // touching any of the numeric fields under test.
      await tester.enterText(_fieldWithLabel('Type'), 'Sofnolime');
      await tester.pump();

      expect(capturedLow, closeTo(0.7, 0.0001));
      expect(capturedHigh, closeTo(1.25, 0.0001));
      expect(capturedLoopVolume, closeTo(5.5, 0.0001));
      expect(capturedDuration, 180);
      expect(capturedDiluent!.o2, closeTo(18.0, 0.0001));
      expect(capturedDiluent!.he, closeTo(45.0, 0.0001));
    });
  });

  group('ScrSettingsPanel', () {
    testWidgets('accepts a comma decimal VO2 under fr', (tester) async {
      Intl.defaultLocale = 'fr';

      double? capturedVo2;
      await _pumpPanel(
        tester,
        ScrSettingsPanel(
          assumedVo2: 1.30,
          onChanged:
              ({
                scrType,
                injectionRate,
                additionRatio,
                orificeSize,
                supplyGas,
                assumedVo2,
                loopO2Min,
                loopO2Max,
                loopO2Avg,
                scrubberType,
                scrubberDurationMinutes,
                scrubberRemainingMinutes,
              }) => capturedVo2 = assumedVo2,
        ),
      );

      await tester.enterText(_fieldWithLabel('Assumed VO₂'), '0,85');
      await tester.pump();

      expect(capturedVo2, closeTo(0.85, 0.0001));
    });

    testWidgets('an untouched injection rate survives a save under de', (
      tester,
    ) async {
      Intl.defaultLocale = 'de';

      double? capturedRate;
      double? capturedVo2;
      double? capturedLoopAvg;
      GasMix? capturedSupply;
      await _pumpPanel(
        tester,
        ScrSettingsPanel(
          injectionRate: 8.5,
          assumedVo2: 1.25,
          loopO2Avg: 42.5,
          supplyGas: const GasMix(o2: 50.0, he: 0.0),
          onChanged:
              ({
                scrType,
                injectionRate,
                additionRatio,
                orificeSize,
                supplyGas,
                assumedVo2,
                loopO2Min,
                loopO2Max,
                loopO2Avg,
                scrubberType,
                scrubberDurationMinutes,
                scrubberRemainingMinutes,
              }) {
                capturedRate = injectionRate;
                capturedVo2 = assumedVo2;
                capturedLoopAvg = loopO2Avg;
                capturedSupply = supplyGas;
              },
        ),
      );

      expect(find.widgetWithText(TextFormField, '8,5'), findsOneWidget);

      await tester.enterText(_fieldWithLabel('Type'), 'Sofnolime');
      await tester.pump();

      expect(capturedRate, closeTo(8.5, 0.0001));
      expect(capturedVo2, closeTo(1.25, 0.0001));
      expect(capturedLoopAvg, closeTo(42.5, 0.0001));
      expect(capturedSupply!.o2, closeTo(50.0, 0.0001));
    });
  });
}

/// The [TextFormField] whose decoration carries [label].
Finder _fieldWithLabel(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

/// Hosts [panel] in an English MaterialApp. The pinned English locale keeps the
/// label finders working; `Intl.defaultLocale` is what governs number parsing.
Future<void> _pumpPanel(WidgetTester tester, Widget panel) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: panel)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTankEditor(
  WidgetTester tester,
  DiveTank tank,
  TankChangeCallback onChanged,
) async {
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
        tankPresetsProvider.overrideWith((ref) => Future.value(builtInPresets)),
      ].cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TankEditor(tank: tank, tankNumber: 1, onChanged: onChanged),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
