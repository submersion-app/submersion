import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/main_scaffold.dart';

import '../../helpers/main_scaffold_stubs.dart';

/// The rail's entry for the tab already shown keeps its route, so no
/// GoRoute.onExit sees it, yet it drops the record the tab's list pane
/// shows: work held there is asked about first (issue #4527).
void main() {
  testWidgets('the current tab\'s own destination asks about held work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final guard = AppExitGuard(
      retryExit: () async {},
      preventWindowClose: (_) async {},
      revealWindow: () async {},
    );
    var answer = false;
    var asked = 0;
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => true,
        confirmLeaving: () async {
          asked++;
          return answer;
        },
      ),
    );
    final router = GoRouter(
      initialLocation: '/dives?selected=a',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainScaffold(child: child),
          routes: [
            GoRoute(
              path: '/dives',
              builder: (context, state) => const Text('Dive list'),
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
            (ref) => StubUpdateStatusNotifier(),
          ),
          downloadNotifierProvider.overrideWith(
            (ref) => StubDownloadNotifier(),
          ),
          settingsProvider.overrideWith(
            (ref) => StubSettingsNotifier(const AppSettings()),
          ),
          appExitGuardProvider.overrideWithValue(guard),
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
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));

    // Dives is the rail's second destination.
    rail.onDestinationSelected!(1);
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(router.state.uri.toString(), '/dives?selected=a');

    answer = true;
    rail.onDestinationSelected!(1);
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/dives');
  });
}
