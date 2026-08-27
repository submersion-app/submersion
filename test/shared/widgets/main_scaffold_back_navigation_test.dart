import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Regression coverage for #647: the Android system back button closed the
/// app instead of going back, because `context.go()` replaces the shell's
/// Navigator stack and leaves nothing to pop.
///
/// These tests drive the real platform back channel and watch for the
/// `SystemNavigator.pop` call that actually closes the app, so they assert the
/// reported symptom rather than a proxy for it.
void main() {
  late List<String> exitCalls;

  setUp(() {
    exitCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemNavigator.pop') {
            exitCalls.add(call.method);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    String initialLocation = '/dashboard',
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
              routes: [
                GoRoute(
                  path: ':diveId',
                  builder: (context, state) =>
                      Text('Dive ${state.pathParameters['diveId']}'),
                ),
              ],
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const Text('Settings'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          updateServiceProvider.overrideWith((ref) async => null),
          updateStatusProvider.overrideWith(
            (ref) => _StubUpdateStatusNotifier(),
          ),
          downloadNotifierProvider.overrideWith(
            (ref) => _StubDownloadNotifier(),
          ),
          // MainScaffold reads the color-accent toggles; the real
          // SettingsNotifier reaches for the database.
          settingsProvider.overrideWith((ref) => _StubSettingsNotifier()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// Simulates an Android system back press through the navigation channel.
  Future<void> pressSystemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  group('MainScaffold system back', () {
    testWidgets('go() to a top-level tab goes up to the dashboard, not exit', (
      tester,
    ) async {
      final router = await pumpShell(tester, initialLocation: '/dives');

      await pressSystemBack(tester);

      expect(exitCalls, isEmpty, reason: 'the app must not close from a tab');
      expect(locationOf(router), '/dashboard');
    });

    testWidgets('go() to a detail page goes up to its list, not exit', (
      tester,
    ) async {
      final router = await pumpShell(tester);
      router.go('/dives/42');
      await tester.pumpAndSettle();

      await pressSystemBack(tester);

      expect(exitCalls, isEmpty);
      expect(locationOf(router), '/dives');
    });

    testWidgets('go() with a selected param unwinds the selection', (
      tester,
    ) async {
      final router = await pumpShell(tester);
      router.go('/dives?selected=42');
      await tester.pumpAndSettle();

      await pressSystemBack(tester);

      expect(exitCalls, isEmpty);
      expect(locationOf(router), '/dives');
    });

    testWidgets(
      'a pushed route still pops normally rather than up-navigating',
      (tester) async {
        final router = await pumpShell(tester, initialLocation: '/dives');
        router.push('/dives/42');
        await tester.pumpAndSettle();
        expect(find.text('Dive 42'), findsOneWidget);

        await pressSystemBack(tester);

        // Popping the pushed route must win over the shell's up-navigation
        // fallback, otherwise real history would be skipped.
        expect(exitCalls, isEmpty);
        expect(locationOf(router), '/dives');
        // "Dives" itself is ambiguous -- it is also a bottom-nav label.
        expect(find.text('Dive 42'), findsNothing);
      },
    );

    testWidgets('system back on the dashboard exits the app', (tester) async {
      await pumpShell(tester);

      await pressSystemBack(tester);

      expect(exitCalls, ['SystemNavigator.pop']);
    });

    testWidgets('repeated back presses walk up to the dashboard then exit', (
      tester,
    ) async {
      final router = await pumpShell(tester);
      router.go('/dives/42');
      await tester.pumpAndSettle();

      await pressSystemBack(tester);
      expect(locationOf(router), '/dives');

      await pressSystemBack(tester);
      expect(locationOf(router), '/dashboard');
      expect(exitCalls, isEmpty, reason: 'still inside the app');

      await pressSystemBack(tester);
      expect(exitCalls, ['SystemNavigator.pop']);
    });
  });
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

/// Stub settings notifier so the shell can build without a database.
class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
