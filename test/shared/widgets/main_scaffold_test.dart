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
}
