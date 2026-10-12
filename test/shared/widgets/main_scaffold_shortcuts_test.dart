import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/main_scaffold.dart';

import '../../support/fake_app_settings_repository.dart';

/// Nav shortcuts (#2936) in the shell: selection and navigation.
///
/// The harness mirrors `main_scaffold_test.dart`'s, trimmed to the routes a
/// shortcut touches.

class _StubUpdateStatusNotifier extends StateNotifier<UpdateStatus>
    implements UpdateStatusNotifier {
  _StubUpdateStatusNotifier() : super(const UpToDate());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubDownloadNotifier extends StateNotifier<DownloadState>
    implements DownloadNotifier {
  _StubDownloadNotifier() : super(const DownloadState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<Widget> _buildHarness(
  FakeAppSettingsRepository repo, {
  String initialLocation = '/dashboard',
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  GoRoute page(String path, String text) =>
      GoRoute(path: path, builder: (context, state) => Text(text));

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          page('/dashboard', 'Dashboard'),
          page('/dives', 'Dives page'),
          page('/sites', 'Sites page'),
          page('/planning', 'Planning page'),
          page('/planning/gas-calculators/blender', 'Blender page'),
          page('/shortcut/gas-blender', 'Blender alias'),
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
      settingsProvider.overrideWith((ref) => _StubSettingsNotifier()),
      appSettingsRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  group('MainScaffold nav shortcuts', () {
    testWidgets('phone: a shortcut in the bar is selected on its page', (
      tester,
    ) async {
      _useSize(tester, const Size(400, 800));
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['shortcut:gas-blender', 'dives', 'sites'];
      await tester.pumpWidget(
        await _buildHarness(
          repo,
          initialLocation: '/planning/gas-calculators/blender',
        ),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 1);
      expect(
        find.widgetWithText(NavigationDestination, 'Blender'),
        findsOneWidget,
      );
    });

    testWidgets('phone: a shortcut in More selects More on its page', (
      tester,
    ) async {
      _useSize(tester, const Size(400, 800));
      // Planning in the bar, the blender shortcut last, in the More sheet.
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = [
          'planning',
          'dives',
          'sites',
          'trips',
          'media',
          'equipment',
          'buddies',
          'dive-centers',
          'certifications',
          'documents',
          'courses',
          'species',
          'insights',
          'transfer',
          'tracks',
          'settings',
          'shortcut:gas-blender',
        ];
      await tester.pumpWidget(
        await _buildHarness(
          repo,
          initialLocation: '/planning/gas-calculators/blender',
        ),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, bar.destinations.length - 1);
    });

    testWidgets('phone: tapping a shortcut opens its alias', (tester) async {
      _useSize(tester, const Size(400, 800));
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['shortcut:gas-blender', 'dives', 'sites'];
      await tester.pumpWidget(await _buildHarness(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'Blender'));
      await tester.pumpAndSettle();

      expect(find.text('Blender alias'), findsOneWidget);
    });

    testWidgets('rail: the shortcut beats Planning on the canonical page', (
      tester,
    ) async {
      _useSize(tester, const Size(1300, 1400));
      final repo = FakeAppSettingsRepository()
        ..navRailIds = ['planning', 'shortcut:gas-blender'];
      await tester.pumpWidget(
        await _buildHarness(
          repo,
          initialLocation: '/planning/gas-calculators/blender',
        ),
      );
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 2); // Home, Planning, Blender
    });

    testWidgets('rail: Planning stays selected on its other pages', (
      tester,
    ) async {
      _useSize(tester, const Size(1300, 1400));
      final repo = FakeAppSettingsRepository()
        ..navRailIds = ['planning', 'shortcut:gas-blender'];
      await tester.pumpWidget(
        await _buildHarness(repo, initialLocation: '/planning'),
      );
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 1);
    });
  });
}
