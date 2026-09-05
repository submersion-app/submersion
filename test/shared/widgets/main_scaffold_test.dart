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
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';

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
      // Pin the locale: these tests find widgets by English label, and
      // flutter_test forwards the host platform locales.
      locale: const Locale('en'),
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
  /// Phone order (bottom-bar slots first, then the More menu).
  List<String>? stored;

  /// Wide-screen rail order, stored under its own key.
  List<String>? storedRail;

  /// No database, so nothing ever ticks.
  @override
  Stream<void> watchSettingsChanges() => const Stream.empty();

  @override
  Future<List<String>?> getNavPrimaryIdsRaw() async => stored;
  @override
  Future<void> setNavPrimaryIds(List<String> ids) async {
    stored = List<String>.from(ids);
  }

  /// How many times the rail order was read, so a phone-width build can
  /// assert it never subscribed to a surface it does not render.
  int railReads = 0;

  @override
  Future<List<String>?> getNavRailIdsRaw() async {
    railReads++;
    return storedRail;
  }

  @override
  Future<void> setNavRailIds(List<String> ids) async {
    storedRail = List<String>.from(ids);
  }

  @override
  Future<bool> getShareByDefault() async => false;
  @override
  Future<void> setShareByDefault(bool value) async {}
  @override
  Future<String?> getRawSetting(String key) async => null;
  @override
  Future<void> setRawSetting(String key, String value) async {}
  @override
  Future<BlenderPreferences?> getBlenderPreferences() async => null;
  @override
  Future<void> setBlenderPreferences(BlenderPreferences prefs) async {}
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

      // GPS Log is rail index 14 (after Transfer, before Settings).
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      rail.onDestinationSelected!(14);
      await tester.pumpAndSettle();

      expect(find.text('GPS Log Page'), findsOneWidget);
      // Re-reading recomputes the selected index from the /gps-log route.
      final selected = tester
          .widget<NavigationRail>(find.byType(NavigationRail))
          .selectedIndex;
      expect(selected, 14);
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
      EdgeInsets systemPadding = EdgeInsets.zero,
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // MaterialApp.builder wraps the Navigator, so padding stated here
          // is what the modal route's own SafeArea sees.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: systemPadding),
            child: child!,
          ),
        ),
      );

      return (app: app, router: router);
    }

    Future<Widget> buildHarness({
      required AppSettingsRepository repo,
      EdgeInsets systemPadding = EdgeInsets.zero,
    }) async {
      final result = await buildHarnessWithRouter(
        repo: repo,
        systemPadding: systemPadding,
      );
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

    testWidgets('wide-screen rail still shows all 16 default destinations', (
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

      // The rail reads its own storage key, which this repo leaves unset, so
      // it keeps the default 16-entry order no matter how the phone bottom
      // bar was customized. That independence is the point of the two keys.
      // NavigationRailDestination is a descriptor (not a Widget), so inspect
      // the NavigationRail.destinations list directly.
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(16));

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
        'Media',
        'Equipment',
        'Buddies',
        'Dive Centers',
        'Certifications',
        'Courses',
        'Species',
        'Statistics',
        'Planning',
        'Transfer',
        'GPS Log',
        'Settings',
      ]);
    });

    testWidgets('a phone build never reads the rail order', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepo();
      await tester.pumpWidget(await buildHarness(repo: repo));
      await tester.pumpAndSettle();

      // Building the rail provider would kick off a settings read for an
      // order this layout never renders.
      expect(repo.railReads, 0);
    });

    testWidgets('a rail-width build does read the rail order', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepo();
      await tester.pumpWidget(await buildHarness(repo: repo));
      await tester.pumpAndSettle();

      expect(repo.railReads, greaterThan(0));
    });

    testWidgets('wide-screen rail renders the stored rail order', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // A partial stored value: normalization keeps these three at the top and
      // appends the rest in canonical order.
      final repo = _FakeRepo()
        ..storedRail = ['settings', 'statistics', 'dives'];
      await tester.pumpWidget(await buildHarness(repo: repo));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(16));

      String labelOf(NavigationRailDestination d) {
        final label = d.label;
        if (label is Text) return label.data ?? '';
        return label.toString();
      }

      final labels = rail.destinations.map(labelOf).toList();
      // Home stays pinned at the top; the stored order follows it.
      expect(labels.take(4).toList(), [
        'Home',
        'Settings',
        'Statistics',
        'Dives',
      ]);
      // Nothing is lost: every destination still has a rail row.
      expect(labels.toSet(), hasLength(16));
    });

    testWidgets('rail customization leaves the phone bottom bar alone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepo()
        ..storedRail = ['settings', 'statistics', 'dives'];
      await tester.pumpWidget(await buildHarness(repo: repo));
      await tester.pumpAndSettle();

      // Phone order is unset, so the bottom bar keeps its defaults even though
      // the rail was rearranged.
      for (final label in const ['Home', 'Dives', 'Sites', 'Trips', 'More']) {
        expect(
          find.widgetWithText(NavigationDestination, label),
          findsOneWidget,
          reason: '$label should still occupy a default bottom-bar slot',
        );
      }
      expect(
        find.widgetWithText(NavigationDestination, 'Settings'),
        findsNothing,
      );
    });

    testWidgets('tapping a reordered rail item navigates to its route', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 'transfer' is canonically near the end; pulling it to the top proves
      // the tap handler indexes into the stored order, not the canonical one.
      final repo = _FakeRepo()..storedRail = ['transfer'];
      final harness = await buildHarnessWithRouter(repo: repo);
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/transfer',
      );
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

      // The overflow sheet should contain the items NOT in primary. The sheet
      // is height-capped, so the tiles past the fold have to be scrolled to;
      // reaching them all is itself the guard that none is stranded.
      final sheetList = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      );
      for (final label in const [
        'Dives',
        'Sites',
        'Trips',
        'Dive Centers',
        'Certifications',
        'Courses',
        'Planning',
        'Transfer',
        'Settings',
      ]) {
        final tile = find.widgetWithText(ListTile, label);
        await tester.scrollUntilVisible(tile, 100, scrollable: sheetList);
        expect(tile, findsOneWidget);
      }

      // Items now in primary should NOT appear in the overflow sheet.
      expect(find.widgetWithText(ListTile, 'Equipment'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Buddies'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Statistics'), findsNothing);
    });

    // Issue #1480: the overflow sheet is scroll-controlled, and a dozen
    // destinations are taller than a phone screen, so the sheet grew until it
    // touched y=0 and its header sat under the Android status bar.
    testWidgets('overflow sheet stops short of the top edge on a phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await buildHarness(repo: _FakeRepo()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byType(BottomSheet)).top, greaterThan(0));
    });

    // `useSafeArea: true` inserts `SafeArea(bottom: false)`, so it covers top,
    // left and right and deliberately lets the sheet run to the bottom edge.
    // The SafeArea in the builder supplies the bottom inset the outer one
    // skips; it is not a double application, because a SafeArea strips the
    // padding it consumes out of the MediaQuery it hands down.
    testWidgets('overflow sheet applies every system inset exactly once', (
      tester,
    ) async {
      const insets = EdgeInsets.only(top: 44, left: 30, right: 30, bottom: 34);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await buildHarness(repo: _FakeRepo(), systemPadding: insets),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
      await tester.pumpAndSettle();

      final screen = tester.getRect(find.byType(MaterialApp));
      final sheet = tester.getRect(find.byType(BottomSheet));
      final body = tester.getRect(
        find.byKey(const ValueKey('navOverflowSheetBody')),
      );

      expect(sheet.left, insets.left);
      expect(sheet.right, screen.right - insets.right);
      expect(sheet.top, greaterThanOrEqualTo(insets.top));
      expect(sheet.bottom, screen.bottom);
      expect(body.bottom, screen.bottom - insets.bottom);
      expect(body.left, sheet.left);
      expect(body.right, sheet.right);
    });

    testWidgets('overflow sheet close action survives scrolling the list', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await buildHarness(repo: _FakeRepo()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
      await tester.pumpAndSettle();

      final closeButton = find.widgetWithIcon(IconButton, Icons.close);
      final before = tester.getRect(closeButton);
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.getRect(closeButton), before);

      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
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
