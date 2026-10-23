import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_device_card.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _accountDone = setUpProgress(
  const SetUpInputs(
    accountHere: true,
    syncEstablished: false,
    customFolder: false,
    backupsAuto: false,
    backupOffDevice: false,
    photosAttached: false,
    photosSkipped: false,
    hidden: false,
  ),
);

void main() {
  late GoRouter router;

  Future<void> pump(WidgetTester tester, Widget root) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final logDir = Directory.systemTemp.createTempSync('set_up_root_card_');
    addTearDown(() => logDir.deleteSync(recursive: true));
    final logs = LogFileService(logDirectory: logDir.path);
    await tester.runAsync(logs.initialize);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1600);
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: '/root',
      routes: [
        GoRoute(path: '/root', builder: (context, state) => root),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(body: Text('settings')),
        ),
        GoRoute(
          path: '/settings/cloud-sync',
          builder: (context, state) => const Scaffold(body: Text('sync page')),
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
          setUpProgressProvider.overrideWithValue(_accountDone),
          pendingSetupItemsProvider.overrideWith((ref) async => const []),
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

  testWidgets('the desktop settings list leads with the compact card, whose '
      'Continue opens the next step in the Data pane', (tester) async {
    await pump(tester, const SettingsListContent());

    final card = tester.widget<SetUpDeviceCard>(find.byType(SetUpDeviceCard));
    expect(card.compact, isTrue);
    expect(find.text('Finish setting up this phone'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final location = router.routerDelegate.currentConfiguration.uri;
    expect(location.path, '/settings');
    expect(location.queryParameters, {
      'selected': 'data',
      'dataPage': 'cloud-sync',
    });
  });

  testWidgets('the phone settings list leads with the compact card, whose '
      'Continue pushes the next step', (tester) async {
    await pump(tester, const SettingsMobileContent());

    final card = tester.widget<SetUpDeviceCard>(find.byType(SetUpDeviceCard));
    expect(card.compact, isTrue);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('sync page'), findsOneWidget);
    // Pushed over the list, so Back returns to it.
    expect(router.canPop(), isTrue);
  });
}
