import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_preset_dropdown.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #800: the preset field's last entry opens the presets page, so a
/// diver can manage presets from where they pick them. Choosing it is not a
/// choice of preset: the tank keeps its preset and the dive is not edited.
void main() {
  testWidgets('Manage presets opens the presets page and changes nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presets = TankPresets.all.map(TankPresetEntity.fromBuiltIn).toList();
    var presetChanges = 0;
    var cylinderChoices = 0;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TankPresetDropdown(
              presetName: 'al80',
              cylinders: const [],
              onPresetChanged: (_) => presetChanges++,
              onCylinderChosen: (_) => cylinderChoices++,
            ),
          ),
        ),
        GoRoute(
          path: '/tank-presets',
          builder: (context, state) =>
              const Scaffold(body: Text('presets-page')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tankPresetsProvider.overrideWith((ref) => Future.value(presets)),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TankPresetDropdown));
    await tester.pumpAndSettle();
    final manage = find.byKey(const Key('tank-preset-manage')).last;
    await tester.ensureVisible(manage);
    await tester.pumpAndSettle();
    await tester.tap(manage);
    await tester.pumpAndSettle();

    expect(find.text('presets-page'), findsOneWidget);
    expect(presetChanges, 0);
    expect(cylinderChoices, 0);

    router.pop();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TankPresetDropdown),
        matching: find.text('AL80'),
      ),
      findsOneWidget,
    );
  });
}
