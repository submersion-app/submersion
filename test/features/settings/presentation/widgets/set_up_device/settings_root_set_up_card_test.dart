import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_device_card.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../set_up_progress_fixture.dart';

const _reconnect = PendingSetupItem(
  kind: SetupItemKind.mediaStoreReconnect,
  key: 'store_marker_s1',
  label: 'Dropbox',
  route: '/settings/photos-media',
);

void main() {
  late GoRouter router;
  late SharedPreferences prefs;

  Future<void> pump(
    WidgetTester tester,
    Widget root, {
    List<PendingSetupItem> items = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final logDir = Directory.systemTemp.createTempSync('set_up_root_card_');
    addTearDown(() => logDir.deleteSync(recursive: true));
    final logs = LogFileService(logDirectory: logDir.path);
    await tester.runAsync(logs.initialize);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.display.devicePixelRatio = 1;
    tester.view.display.size = const Size(390, 1600);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);
    router = GoRouter(
      initialLocation: '/root',
      routes: [
        GoRoute(path: '/root', builder: (context, state) => root),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(body: Text('settings')),
          routes: [
            GoRoute(
              path: 'setup',
              builder: (context, state) => Scaffold(
                body: Text('setup ${state.uri.queryParameters['step']}'),
              ),
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
          logFileServiceProvider.overrideWithValue(logs),
          allDiversProvider.overrideWith((ref) async => const []),
          setUpProgressProvider.overrideWithValue(
            setUpProgressOf(accountHere: true),
          ),
          pendingSetupItemsProvider.overrideWith((ref) async => items),
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
  }

  Uri location() => router.routerDelegate.currentConfiguration.uri;

  group('the desktop settings list', () {
    testWidgets('leads with the compact card, whose Continue opens the next '
        'step in the Data pane', (tester) async {
      await pump(tester, const SettingsListContent());

      final card = tester.widget<SetUpDeviceCard>(find.byType(SetUpDeviceCard));
      expect(card.compact, isTrue);
      expect(find.text('Finish setting up this phone'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(location().path, '/settings');
      expect(location().queryParameters, {
        'selected': 'data',
        'dataPage': 'setup?step=sync',
      });
    });

    // Issue #3482 review: the card's items open where its steps do, in the
    // Data pane, not over the whole window.
    testWidgets('an item\'s page opens in the Data pane too', (tester) async {
      await pump(tester, const SettingsListContent(), items: [_reconnect]);

      await tester.tap(find.text('Reconnect'));
      await tester.pumpAndSettle();

      expect(location().queryParameters, {
        'selected': 'data',
        'dataPage': 'photos-media',
      });
    });

    // Issue #3482 review: with Settings > Data in the pane, its own card is
    // on screen; a second copy beside it would show every item twice.
    testWidgets('shows no card while Settings > Data is selected', (
      tester,
    ) async {
      await pump(tester, const SettingsListContent(selectedId: 'data'));
      expect(find.byType(SetUpDeviceCard), findsNothing);
    });
  });

  testWidgets('the phone settings list leads with the compact card, whose '
      'Continue pushes the next step', (tester) async {
    await pump(tester, const SettingsMobileContent());

    final card = tester.widget<SetUpDeviceCard>(find.byType(SetUpDeviceCard));
    expect(card.compact, isTrue);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('setup sync'), findsOneWidget);
    // Pushed over the list, so Back returns to it.
    expect(router.canPop(), isTrue);
  });

  // Issue #3482 review: the scheduled backup writes from another isolate;
  // the root card reads the settings fresh when the app returns, as
  // Settings > Data does.
  testWidgets('reloads the backup settings when the app returns', (
    tester,
  ) async {
    await pump(tester, const SettingsMobileContent());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SetUpDeviceCard)),
    );
    expect(container.read(backupSettingsProvider).enabled, isFalse);

    // Another isolate turns automatic backups on while the app is away.
    SharedPreferences.setMockInitialValues({'backup_enabled': true});
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    expect(container.read(backupSettingsProvider).enabled, isTrue);
  });
}
