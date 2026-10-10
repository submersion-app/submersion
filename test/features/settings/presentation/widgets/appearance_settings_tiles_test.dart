import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/appearance_settings_tiles.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

late SharedPreferences _prefs;

/// Renders [AppearanceGeneralTiles] under a router whose /settings/themes
/// stub stands in for the theme gallery.
Future<MockSettingsNotifier> _pumpGeneralTiles(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final notifier = MockSettingsNotifier(settings);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: ListView(
            children: [AppearanceGeneralTiles(onLanguageTap: () {})],
          ),
        ),
      ),
      GoRoute(
        path: '/settings/themes',
        builder: (_, _) => const Scaffold(body: Text('theme gallery')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => notifier),
        sharedPreferencesProvider.overrideWithValue(_prefs),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  group('AppearanceGeneralTiles', () {
    testWidgets('Color Theme opens the theme gallery', (tester) async {
      await _pumpGeneralTiles(tester);

      await tester.tap(find.text('Color Theme'));
      await tester.pumpAndSettle();

      expect(find.text('theme gallery'), findsOneWidget);
    });

    for (final (presetId, name) in [
      ('submersion', 'Submersion'),
      ('console', 'Console'),
      ('tropical', 'Tropical'),
      ('minimalist', 'Minimalist'),
      ('deep', 'Deep'),
    ]) {
      testWidgets('names the $presetId theme in the Color Theme subtitle', (
        tester,
      ) async {
        await _pumpGeneralTiles(
          tester,
          settings: AppSettings(themePresetId: presetId),
        );

        final tile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text('Color Theme'),
            matching: find.byType(ListTile),
          ),
        );
        expect((tile.subtitle! as Text).data, name);
      });
    }

    // Semantics(selected) already announces the selected row. A label on its
    // check mark said so a second time, in the language list's wording, whose
    // translations agree with the word for language (French "Sélectionnée").
    testWidgets('the selected light/dark row is announced once', (
      tester,
    ) async {
      await _pumpGeneralTiles(
        tester,
        settings: const AppSettings(themeMode: ThemeMode.dark),
      );

      final check = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(check.semanticLabel, isNull);
      expect(
        find.ancestor(
          of: find.text('Dark'),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.selected == true,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a light/dark row saves that mode', (tester) async {
      final notifier = await _pumpGeneralTiles(tester);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(notifier.state.themeMode, ThemeMode.dark);
    });

    testWidgets('choosing a map style saves it', (tester) async {
      final notifier = await _pumpGeneralTiles(tester);

      await tester.tap(find.byType(DropdownButton<MapStyle>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Topographic').last);
      await tester.pumpAndSettle();

      expect(notifier.state.mapStyle, MapStyle.openTopoMap);
    });
  });
}
