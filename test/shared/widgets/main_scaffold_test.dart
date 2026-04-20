import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/main_scaffold.dart';

Future<Widget> _buildTestApp({String initialLocation = '/dashboard'}) async {
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
    ],
    child: MaterialApp.router(
      routerConfig: router,
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
    Future<Widget> buildHarness({required AppSettingsRepository repo}) async {
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

      return ProviderScope(
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
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
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

    testWidgets('wide-screen rail still shows all 13 default destinations', (
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
      // 13-entry order regardless of stored primary-ids customization.
      // NavigationRailDestination is a descriptor (not a Widget), so inspect
      // the NavigationRail.destinations list directly.
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(13));

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
        'Settings',
      ]);
    });
  });
}
