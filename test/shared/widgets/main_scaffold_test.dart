import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/main_scaffold.dart';

Future<Widget> _buildTestApp({
  String initialLocation = '/dashboard',
  // Riverpod's sealed Override type is not re-exported; see test_app.dart.
  List<dynamic> extraOverrides = const [],
  ThemeData? theme,
  // MainScaffold reads the color-accent toggles, so settings must be stubbed
  // here -- the real SettingsNotifier reaches for the database.
  AppSettings settings = const AppSettings(),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const Text('Dashboard'),
          ),
          GoRoute(
            path: '/dives',
            builder: (context, state) => const Text('Dives'),
          ),
          GoRoute(
            path: '/sites',
            builder: (context, state) => const Text('Sites'),
          ),
          GoRoute(
            path: '/trips',
            builder: (context, state) => const Text('Trips'),
          ),
          GoRoute(
            path: '/equipment',
            builder: (context, state) => const Text('Equipment'),
          ),
          GoRoute(
            path: '/transfer',
            builder: (context, state) => const Text('Transfer'),
          ),
          GoRoute(
            path: '/gps-log',
            builder: (context, state) => const Text('GPS Log Page'),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const Text('Settings'),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      updateServiceProvider.overrideWith((ref) async => null),
      updateStatusProvider.overrideWith((ref) => _StubUpdateStatusNotifier()),
      downloadNotifierProvider.overrideWith((ref) => _StubDownloadNotifier()),
      settingsProvider.overrideWith((ref) => _StubSettingsNotifier(settings)),
      ...extraOverrides.cast(),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// Stub that avoids the 5-second timer in the real [UpdateStatusNotifier].
class _StubUpdateStatusNotifier extends StateNotifier<UpdateStatus>
    implements UpdateStatusNotifier {
  _StubUpdateStatusNotifier() : super(const UpToDate());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub that avoids platform channel dependencies.
class _StubDownloadNotifier extends StateNotifier<DownloadState>
    implements DownloadNotifier {
  _StubDownloadNotifier() : super(const DownloadState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub settings notifier so the accent tests can drive the toggles without
/// touching the database.
class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake AppSettingsRepository used by the nav customization tests.
class _FakeRepo implements AppSettingsRepository {
  List<String>? stored;
  @override
  Future<List<String>?> getNavPrimaryIdsRaw() async => stored;
  @override
  Future<void> setNavPrimaryIds(List<String> ids) async {
    stored = List<String>.from(ids);
  }

  @override
  Future<bool> getShareByDefault() async => false;
  @override
  Future<void> setShareByDefault(bool value) async {}
}

void main() {
  group('MainScaffold', () {
    testWidgets('desktop layout shows NavigationRail', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('desktop layout shows collapse toggle on wide screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      // Collapse toggle should be visible on wide screens.
      expect(find.byIcon(Icons.keyboard_double_arrow_left), findsOneWidget);

      // Tap the collapse toggle.
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_left));
      await tester.pumpAndSettle();

      // After collapse, the expand icon should appear.
      expect(find.byIcon(Icons.keyboard_double_arrow_right), findsOneWidget);
    });

    testWidgets('desktop navigation rail responds to destination selection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      // Tap the second rail destination (Dives).
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      rail.onDestinationSelected!(1);
      await tester.pumpAndSettle();

      // "Dives" appears both in rail label and route content.
      expect(find.text('Dives'), findsWidgets);
    });

    testWidgets('desktop rail navigates to the GPS Log destination', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      // GPS Log is rail index 12 (after Transfer, before Settings).
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      rail.onDestinationSelected!(12);
      await tester.pumpAndSettle();

      expect(find.text('GPS Log Page'), findsOneWidget);
      // Re-reading recomputes the selected index from the /gps-log route.
      final selected = tester
          .widget<NavigationRail>(find.byType(NavigationRail))
          .selectedIndex;
      expect(selected, 12);
    });

    testWidgets('recording strip appears while a GPS session is active', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        await _buildTestApp(
          extraOverrides: [
            gpsRecorderStateProvider.overrideWith(
              (ref) => Stream.value(
                const GpsRecorderState(
                  status: GpsRecorderStatus.recording,
                  trackId: 't1',
                  pointCount: 3,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recording GPS track · 3 points'), findsOneWidget);
    });

    testWidgets('recording strip is absent while idle', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();
      expect(find.textContaining('Recording GPS track'), findsNothing);
    });

    testWidgets('mobile layout shows NavigationBar', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('MainScaffold mobile nav customization', () {
    Future<({Widget app, GoRouter router})> buildHarnessWithRouter({
      required AppSettingsRepository repo,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (context, state, child) => MainScaffold(child: child),
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/dives',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/sites',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/trips',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/equipment',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/buddies',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/dive-centers',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/certifications',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/courses',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/statistics',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/planning',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/transfer',
                builder: (context, state) => const SizedBox(),
              ),
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SizedBox(),
              ),
            ],
          ),
        ],
      );

      final app = ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          updateServiceProvider.overrideWith((ref) async => null),
          updateStatusProvider.overrideWith(
            (ref) => _StubUpdateStatusNotifier(),
          ),
          downloadNotifierProvider.overrideWith(
            (ref) => _StubDownloadNotifier(),
          ),
          settingsProvider.overrideWith(
            (ref) => _StubSettingsNotifier(const AppSettings()),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

      return (app: app, router: router);
    }

    Future<Widget> buildHarness({required AppSettingsRepository repo}) async {
      final result = await buildHarnessWithRouter(repo: repo);
      return result.app;
    }

    testWidgets('default primary ids render default nav labels', (
      tester,
    ) async {
      // Phone-sized viewport.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepo();
      await tester.pumpWidget(await buildHarness(repo: repo));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(NavigationDestination, 'Home'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavigationDestination, 'Dives'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavigationDestination, 'Sites'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavigationDestination, 'Trips'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavigationDestination, 'More'),
        findsOneWidget,
      );
    });

    testWidgets('custom primary ids render custom labels', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepo()..stored = ['equipment', 'buddies', 'statistics'];
      await tester.pumpWidget(await buildHarness(repo: repo));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(NavigationDestination, 'Home'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavigationDestination, 'Equipment'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavigationDestination, 'Buddies'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavigationDestination, 'Statistics'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavigationDestination, 'More'),
        findsOneWidget,
      );
      // Replaced items should not appear in the primary bar.
      expect(find.widgetWithText(NavigationDestination, 'Dives'), findsNothing);
      expect(find.widgetWithText(NavigationDestination, 'Sites'), findsNothing);
      expect(find.widgetWithText(NavigationDestination, 'Trips'), findsNothing);
    });

    testWidgets('wide-screen rail still shows all 14 default destinations', (
      tester,
    ) async {
      // Wide viewport (desktop-extended so rail labels are rendered as Text).
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepo()..stored = ['equipment', 'buddies', 'statistics'];
      await tester.pumpWidget(await buildHarness(repo: repo));
      await tester.pumpAndSettle();

      // The wide-screen rail is NOT customized, so it keeps the default
      // 14-entry order regardless of stored primary-ids customization.
      // NavigationRailDestination is a descriptor (not a Widget), so inspect
      // the NavigationRail.destinations list directly.
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(14));

      String labelOf(NavigationRailDestination d) {
        final label = d.label;
        if (label is Text) return label.data ?? '';
        return label.toString();
      }

      final labels = rail.destinations.map(labelOf).toList();
      expect(labels, [
        'Home',
        'Dives',
        'Sites',
        'Trips',
        'Equipment',
        'Buddies',
        'Dive Centers',
        'Certifications',
        'Courses',
        'Statistics',
        'Planning',
        'Transfer',
        'GPS Log',
        'Settings',
      ]);
    });

    testWidgets('tapping a customized primary item navigates to its route', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepo()..stored = ['equipment', 'buddies', 'statistics'];
      final harness = await buildHarnessWithRouter(repo: repo);
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // Tap the customized "Equipment" destination in the primary nav bar.
      await tester.tap(find.widgetWithText(NavigationDestination, 'Equipment'));
      await tester.pumpAndSettle();

      // The router should have navigated to /equipment.
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/equipment',
      );
    });

    testWidgets('overflow sheet reflects current customization', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepo()..stored = ['equipment', 'buddies', 'statistics'];
      await tester.pumpWidget(await buildHarness(repo: repo));
      await tester.pumpAndSettle();

      // Tap the "More" destination to open the overflow sheet.
      await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
      await tester.pumpAndSettle();

      // The overflow sheet should contain the items NOT in primary.
      expect(find.widgetWithText(ListTile, 'Dives'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Sites'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Trips'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Dive Centers'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Certifications'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Courses'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Planning'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Transfer'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Settings'), findsOneWidget);

      // Items now in primary should NOT appear in the overflow sheet.
      expect(find.widgetWithText(ListTile, 'Equipment'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Buddies'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Statistics'), findsNothing);
    });
  });

  group('MainScaffold nav accent icons', () {
    ThemeData accentTheme() => ThemeData(
      brightness: Brightness.light,
      extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.light],
    );

    AppSettings accentSettings({required bool on}) =>
        AppSettings(accentNavIcons: on);

    testWidgets('mobile nav icons are tinted when the toggle is on', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await _buildTestApp(
          settings: accentSettings(on: true),
          theme: accentTheme(),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.scuba_diving_outlined),
        ),
      );
      expect(icon.color, FeatureAccentColors.light.of('dives'));
    });

    testWidgets('mobile nav icons are untinted when the toggle is off', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await _buildTestApp(
          settings: accentSettings(on: false),
          theme: accentTheme(),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.scuba_diving_outlined),
        ),
      );
      expect(icon.color, isNull);
    });

    testWidgets('the More sentinel is never tinted', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await _buildTestApp(
          settings: accentSettings(on: true),
          theme: accentTheme(),
        ),
      );
      await tester.pumpAndSettle();

      // 'more' has no palette entry, so it stays on the theme default even
      // with accents enabled.
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.more_horiz_outlined),
        ),
      );
      expect(icon.color, isNull);
    });

    testWidgets('rail icons are tinted when the toggle is on', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await _buildTestApp(
          settings: accentSettings(on: true),
          theme: accentTheme(),
        ),
      );
      await tester.pumpAndSettle();

      // NavigationRailDestination is a descriptor, so read the icons from the
      // rail's destination list rather than the widget tree.
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      final sitesIcon = rail.destinations[2].icon as Icon;
      expect(sitesIcon.color, FeatureAccentColors.light.of('sites'));

      final selectedSitesIcon = rail.destinations[2].selectedIcon as Icon;
      expect(selectedSitesIcon.color, FeatureAccentColors.light.of('sites'));
    });

    testWidgets('rail icons are untinted when the toggle is off', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await _buildTestApp(
          settings: accentSettings(on: false),
          theme: accentTheme(),
        ),
      );
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect((rail.destinations[2].icon as Icon).color, isNull);
    });

    testWidgets('overflow sheet icons are tinted when the toggle is on', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await _buildTestApp(
          settings: accentSettings(on: true),
          theme: accentTheme(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
      await tester.pumpAndSettle();

      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Equipment'),
      );
      expect(
        (tile.leading as Icon).color,
        FeatureAccentColors.light.of('equipment'),
      );
    });
  });
}
