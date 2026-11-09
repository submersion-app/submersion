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

/// The cylinder editor's "Breathed at the surface" minutes (issue #2930).
void main() {
  Future<List<DiveTank>> pump(WidgetTester tester, DiveTank tank) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presets = [
      for (final p in TankPresets.all) TankPresetEntity.fromBuiltIn(p),
    ];
    final changes = <DiveTank>[];
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
                onChanged: changes.add,
                onRemove: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return changes;
  }

  Finder field() => find.widgetWithText(TextField, 'Breathed at the surface');

  testWidgets('shows and edits the minutes on a breathing cylinder', (
    tester,
  ) async {
    final changes = await pump(
      tester,
      const DiveTank(
        id: 't',
        startPressure: 200,
        endPressure: 150,
        gasMix: GasMix(o2: 100),
        role: TankRole.deco,
        surfaceBreathingDuration: Duration(minutes: 10),
      ),
    );
    expect(field(), findsOneWidget);
    expect(find.widgetWithText(TextField, '10'), findsOneWidget);

    await tester.enterText(field(), '15');
    expect(changes.last.surfaceBreathingDuration, const Duration(minutes: 15));
    await tester.enterText(field(), '');
    expect(changes.last.surfaceBreathingDuration, isNull);
  });

  testWidgets('an edit elsewhere keeps the minutes', (tester) async {
    final changes = await pump(
      tester,
      const DiveTank(
        id: 't',
        startPressure: 200,
        endPressure: 150,
        surfaceBreathingDuration: Duration(minutes: 10),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'End Pressure'),
      '140',
    );
    expect(changes.last.surfaceBreathingDuration, const Duration(minutes: 10));
  });

  testWidgets('a suit inflation bottle has no such field', (tester) async {
    await pump(tester, const DiveTank(id: 't', role: TankRole.suitInflation));
    expect(field(), findsNothing);
  });

  testWidgets('a suit inflation bottle saves no hidden minutes', (
    tester,
  ) async {
    // Minutes left from when the cylinder had a breathing role are hidden
    // with the field, so a save must not keep them where no one can clear
    // them.
    final changes = await pump(
      tester,
      const DiveTank(
        id: 't',
        startPressure: 200,
        endPressure: 150,
        role: TankRole.suitInflation,
        surfaceBreathingDuration: Duration(minutes: 10),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'End Pressure'),
      '140',
    );
    expect(changes.last.surfaceBreathingDuration, isNull);
  });
}

class _Presets extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _Presets(List<TankPresetEntity> presets) : super(AsyncValue.data(presets));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
