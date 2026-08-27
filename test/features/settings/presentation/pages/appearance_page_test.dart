import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Mock SettingsNotifier that doesn't access the database
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  Future<void> setAccentNavIcons(bool value) async =>
      state = state.copyWith(accentNavIcons: value);

  @override
  Future<void> setAccentSectionHeaders(bool value) async =>
      state = state.copyWith(accentSectionHeaders: value);

  @override
  Future<void> setAccentListIcons(bool value) async =>
      state = state.copyWith(accentListIcons: value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Backs the display zoom control, which AppearancePage now embeds.
late SharedPreferences _prefs;

Widget _buildTestWidget() {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
      sharedPreferencesProvider.overrideWithValue(_prefs),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppearancePage(),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  group('AppearancePage hub layout', () {
    testWidgets('shows General section header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('General'), findsOneWidget);
    });

    testWidgets('shows theme tile with palette_outlined icon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
    });

    testWidgets('shows theme mode selector icons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('shows language tile with language icon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('shows Sections section header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sections'), findsOneWidget);
    });

    testWidgets('shows all 9 section navigation tiles', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      for (final label in [
        'Home',
        'Dives',
        'Sites',
        'Buddies',
        'Trips',
        'Equipment',
        'Dive Centers',
        'Certifications',
        'Courses',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'Missing tile: $label',
        );
      }
    });

    testWidgets('Home tile opens the home appearance page', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? pushed;
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const AppearancePage()),
          GoRoute(
            path: '/settings/appearance/home',
            builder: (_, _) => Builder(
              builder: (context) {
                pushed = '/settings/appearance/home';
                return const Scaffold();
              },
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
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

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(pushed, '/settings/appearance/home');
    });

    testWidgets('App Language tile pushes the language page', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const AppearancePage()),
          GoRoute(
            path: '/settings/language',
            builder: (_, _) => const Scaffold(body: Text('language page')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
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

      await tester.tap(find.text('App Language'));
      await tester.pumpAndSettle();

      // PUSH (not go): the settings page stays underneath, so the Android
      // system back button returns to it instead of closing the app (#647).
      expect(find.text('language page'), findsOneWidget);
      expect(router.routerDelegate.canPop(), isTrue);
    });

    testWidgets('does NOT show old inline settings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Dive List View'), findsNothing);
      expect(find.text('Show Profile Panel in Table View'), findsNothing);
      expect(find.text('Show details pane in table mode'), findsNothing);
    });
  });

  group('AppearancePage color accents', () {
    testWidgets('shows the three accent toggles, all off by default', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Color accents'), findsOneWidget);
      expect(find.text('Colored navigation icons'), findsOneWidget);
      expect(find.text('Colored section headers'), findsOneWidget);
      expect(find.text('Colored list icons'), findsOneWidget);

      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches, hasLength(3));
      expect(switches.every((s) => s.value == false), isTrue);
    });

    testWidgets('tapping a toggle turns only that surface on', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Colored navigation icons'));
      await tester.pumpAndSettle();

      SwitchListTile tileFor(String title) => tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(SwitchListTile),
        ),
      );

      expect(tileFor('Colored navigation icons').value, isTrue);
      expect(tileFor('Colored section headers').value, isFalse);
      expect(tileFor('Colored list icons').value, isFalse);
    });
  });
}
