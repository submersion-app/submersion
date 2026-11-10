import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_tank_specs_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
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
          (ref) => _MockTankPresetListNotifier(presets),
        ),
        tankPresetsProvider.overrideWith((ref) => Future.value(presets)),
      ].cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('BulkTankSpecsEditor', () {
    // The template writes to every tank on every selected dive, so a numbered
    // "Tank 1" header read as if only the first tank would change (#3367).
    testWidgets('labels the template as all tanks, not tank 1', (tester) async {
      await _pump(
        tester,
        BulkTankSpecsEditor(
          specs: const DiveTank(id: ''),
          fields: const {TankSpecField.volume},
          onSpecsChanged: (_) {},
          onFieldsChanged: (_) {},
        ),
      );

      final header = find.byType(TankEditor);
      expect(
        find.descendant(of: header, matching: find.text('All tanks')),
        findsOneWidget,
      );
      expect(find.text('Tank 1'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CircleAvatar),
          matching: find.byIcon(Icons.layers_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CircleAvatar),
          matching: find.text('1'),
        ),
        findsNothing,
      );
    });
  });

  group('TankEditor header', () {
    testWidgets('a dive tank keeps its number', (tester) async {
      await _pump(
        tester,
        TankEditor(
          tank: const DiveTank(id: 't2'),
          tankNumber: 2,
          onChanged: (_) {},
        ),
      );

      expect(find.text('Tank 2'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CircleAvatar),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.layers_outlined), findsNothing);
    });
  });
}

class _MockTankPresetListNotifier
    extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _MockTankPresetListNotifier(List<TankPresetEntity> presets)
    : super(AsyncValue.data(presets));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
