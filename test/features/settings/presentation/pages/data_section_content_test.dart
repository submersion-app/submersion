// Issues #3390 and #3394: Settings > Data opens with a status strip and a
// facts line, drops every card, and marks the four feature rows with the
// same health symbol as the strip. Issue #3482: the rows read as outcomes
// with one-sentence statuses under "Your data", and the rarely used rows
// fold under "Advanced".
// On a master-detail window its rows open in the detail pane (#3467).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/pages/data_section_content.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_facts_line.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_device_card.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_health_strip.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_enter_dialog.dart';

import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/mock_providers.dart';
import '../../set_up_progress_fixture.dart';

void main() {
  const health = [
    FeatureHealth(
      feature: DataFeature.backup,
      level: HealthLevel.healthy,
      reason: HealthReason.ok,
    ),
    FeatureHealth(
      feature: DataFeature.sync,
      level: HealthLevel.healthy,
      reason: HealthReason.ok,
    ),
    FeatureHealth(
      feature: DataFeature.sharedLibraries,
      level: HealthLevel.attention,
      reason: HealthReason.librariesEditsHeld,
      name: 'Club Sites',
    ),
    FeatureHealth(
      feature: DataFeature.media,
      level: HealthLevel.notSetUp,
      reason: HealthReason.notSetUp,
    ),
  ];

  Future<GoRouter> pumpData(
    WidgetTester tester, {
    List<FeatureHealth> dataHealth = health,
    DateTime? lastSync,
    List<String> peers = const [],
    Size size = const Size(400, 2400),
    double textScale = 1,
    bool storeAttachedHere = false,
    SetUpProgress? setUp,
    DemoPackage? demoPackage,
    Future<void> Function()? exitDemo,
  }) async {
    // MediaQuery follows the view, which the layout breakpoints read.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    // The set up card's device word follows the display.
    tester.view.display.devicePixelRatio = 1;
    tester.view.display.size = size;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);
    final router = GoRouter(
      initialLocation: '/settings?selected=data',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: const SettingsPage(),
          ),
        ),
        for (final path in const [
          '/settings/import-options',
          '/settings/data-tools',
          '/settings/cloud-sync',
          '/settings/photos-media',
          '/settings/connected-accounts',
          '/settings/setup',
        ])
          GoRoute(
            path: path,
            builder: (context, state) =>
                Scaffold(body: Text('page ${state.uri}')),
          ),
      ],
    );
    addTearDown(router.dispose);
    // The master-detail section list reads debug mode, which needs a log
    // service.
    final logDir = Directory.systemTemp.createTempSync('data_pane_test');
    addTearDown(() => logDir.deleteSync(recursive: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(
            dataHealth: dataHealth,
            lastSync: lastSync,
            syncPeerNames: peers,
            mediaStoreAttachedHere: storeAttachedHere,
            demoPackage: demoPackage,
          ),
          logFileServiceProvider.overrideWithValue(
            LogFileService(logDirectory: logDir.path),
          ),
          // Null unless a test sets it: no set up card, no again row.
          setUpProgressProvider.overrideWithValue(setUp),
          pendingSetupItemsProvider.overrideWith((ref) async => const []),
          // The flow opened in the pane lists the accounts.
          accountGroupsProvider.overrideWith((ref) async => const []),
          if (exitDemo != null)
            demoExitActionProvider.overrideWithValue(exitDemo),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Finder markBeside(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
    matching: find.byType(HealthSymbol),
  );

  testWidgets('the Data page has no Card', (tester) async {
    await pumpData(tester);

    final page = find
        .ancestor(
          of: find.text('Your data'),
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    expect(
      find.descendant(of: page, matching: find.byType(Card)),
      findsNothing,
    );
  });

  testWidgets('the dashboard sits above the Your data header', (tester) async {
    await pumpData(tester);

    expect(
      tester.getTopLeft(find.byType(DataHealthStrip)).dy,
      lessThan(tester.getTopLeft(find.text('Your data')).dy),
    );
  });

  testWidgets('row marks match the strip', (tester) async {
    await pumpData(tester);

    final backupMark = tester.widget<HealthSymbol>(markBeside('Backups'));
    expect((backupMark.level, backupMark.size), (HealthLevel.healthy, 16));
    expect(
      tester.widget<HealthSymbol>(markBeside('Shared site libraries')).level,
      HealthLevel.attention,
    );
    expect(markBeside('Photos & videos'), findsNothing);
    expect(markBeside('Database storage'), findsNothing);
  });

  testWidgets('sync row names the only peer', (tester) async {
    await pumpData(
      tester,
      lastSync: DateTime.now().subtract(const Duration(minutes: 12)),
      peers: const ["Eric's iPhone"],
    );

    expect(find.text("In step with Eric's iPhone, 12m ago"), findsOneWidget);
  });

  testWidgets('sync row counts several peers', (tester) async {
    await pumpData(
      tester,
      lastSync: DateTime.now().subtract(const Duration(minutes: 12)),
      peers: const ["Eric's iPhone", 'Dive Laptop', 'iPad'],
    );

    expect(find.text('In step with 3 devices, 12m ago'), findsOneWidget);
  });

  testWidgets('sync row reads off with no provider and offers set up', (
    tester,
  ) async {
    // Signing out keeps the last sync timestamp, so the row must follow the
    // strip, not the timestamp.
    await pumpData(
      tester,
      dataHealth: [
        health[0],
        const FeatureHealth(
          feature: DataFeature.sync,
          level: HealthLevel.attention,
          reason: HealthReason.syncOff,
        ),
        health[2],
        health[3],
      ],
      lastSync: DateTime.now().subtract(const Duration(days: 12)),
      peers: const ["Eric's iPhone"],
    );

    expect(find.text('Only on this device'), findsOneWidget);
    expect(find.textContaining('In step'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Only on this device'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('Set up'),
      ),
    );
    await tester.pumpAndSettle();
    // No account chosen yet: Set up starts from the account step.
    expect(find.text('page /settings/setup?step=account'), findsOneWidget);
  });

  // Sync offers Set up only while it is off, so step 2 would have no
  // account to read even when a backup copy or photos name one.
  testWidgets('with another feature naming an account, Sync still starts '
      'from the account step', (tester) async {
    await pumpData(
      tester,
      dataHealth: [
        health[0],
        const FeatureHealth(
          feature: DataFeature.sync,
          level: HealthLevel.attention,
          reason: HealthReason.syncOff,
        ),
        health[2],
        health[3],
      ],
      setUp: setUpProgressOf(accountHere: true),
    );

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Only on this device'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('Set up'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('page /settings/setup?step=account'), findsOneWidget);
  });

  testWidgets('photos row offers set up when copies are not kept', (
    tester,
  ) async {
    await pumpData(tester);

    expect(find.text('Copies are not kept in the cloud'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Copies are not kept in the cloud'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('Set up'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('page /settings/setup?step=photos'), findsOneWidget);
  });

  testWidgets('advanced rows push their pages', (tester) async {
    await pumpData(tester);
    await tester.tap(find.text('Import options'));
    await tester.pumpAndSettle();
    expect(find.text('page /settings/import-options'), findsOneWidget);

    await pumpData(tester);
    await tester.tap(find.text('Data tools'));
    await tester.pumpAndSettle();
    expect(find.text('page /settings/data-tools'), findsOneWidget);
  });

  testWidgets('tool rows and import controls left the page', (tester) async {
    await pumpData(tester);

    expect(find.text('Fix dive times'), findsNothing);
    expect(find.text('Auto site matching'), findsNothing);
    expect(find.text('Tag imports automatically'), findsNothing);
  });

  testWidgets('only the dashboard sits above the Your data header', (
    tester,
  ) async {
    await pumpData(tester);

    final header = tester.getTopLeft(find.text('Your data')).dy;
    for (final title in const [
      'Backups',
      'Sync between devices',
      'Photos & videos',
      'Shared site libraries',
      'Connected accounts',
      'Database storage',
      'Offline maps',
      'Import options',
      'Data tools',
    ]) {
      expect(
        tester.getTopLeft(find.widgetWithText(ListTile, title)).dy,
        greaterThan(header),
        reason: title,
      );
    }
    expect(
      tester.getTopLeft(find.text('Advanced')).dy,
      greaterThan(
        tester
            .getTopLeft(find.widgetWithText(ListTile, 'Connected accounts'))
            .dy,
      ),
    );
  });

  testWidgets(
    'a long subtitle with a Set up button fits a 320 px phone at 2x text',
    (tester) async {
      await pumpData(
        tester,
        size: const Size(320, 3200),
        textScale: 2.0,
        dataHealth: [
          health[0],
          const FeatureHealth(
            feature: DataFeature.sync,
            level: HealthLevel.attention,
            reason: HealthReason.syncOff,
          ),
          health[2],
          health[3],
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Set up'), findsNWidgets(2));
    },
  );

  testWidgets('a resume picks up a backup outcome written in the background', (
    tester,
  ) async {
    await pumpData(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DataHealthStrip)),
    );
    expect(
      container.read(backupSettingsProvider).lastScheduledFailureAt,
      isNull,
    );

    // The WorkManager job writes through its own preferences while the
    // page stays open behind the app switcher.
    final prefs = await SharedPreferences.getInstance();
    await BackupPreferences(
      prefs,
    ).setLastScheduledFailure(DateTime(2026, 10, 17, 3), 'disk full');
    // Background and back, through the transitions Flutter allows; it ends
    // resumed, the state every test starts in.
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

    expect(
      container.read(backupSettingsProvider).lastScheduledFailureMessage,
      'disk full',
    );
  });

  testWidgets('on a master-detail window a row opens in the pane (#3467)', (
    tester,
  ) async {
    final router = await pumpData(tester, size: const Size(1400, 2400));
    final importPage = find.widgetWithText(AppBar, 'Import options');

    await tester.tap(find.widgetWithText(ListTile, 'Import options'));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/settings?selected=data&dataPage=import-options',
    );
    expect(importPage, findsOneWidget);
    // The section list is still beside it.
    expect(find.byType(SettingsListContent), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/settings?selected=data',
    );
    expect(importPage, findsNothing);
    expect(find.text('Your data'), findsOneWidget);
  });

  testWidgets('on a phone a row still pushes its page', (tester) async {
    final router = await pumpData(tester);

    await tester.tap(find.text('Import options'));
    await tester.pumpAndSettle();

    expect(find.text('page /settings/import-options'), findsOneWidget);
    expect(router.canPop(), isTrue);
    expect(find.text('Your data'), findsNothing);
  });

  Finder inDataPage(Finder f) =>
      find.descendant(of: find.byType(DataSectionContent), matching: f);

  group('the set up card', () {
    testWidgets('sits between the strip and the facts line', (tester) async {
      await pumpData(tester, setUp: setUpProgressOf(accountHere: true));

      final card = inDataPage(find.byType(SetUpDeviceCard));
      expect(card, findsOneWidget);
      expect(tester.widget<SetUpDeviceCard>(card).compact, isFalse);
      expect(
        tester.getTopLeft(find.byType(DataHealthStrip)).dy,
        lessThan(tester.getTopLeft(card).dy),
      );
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(find.byType(DataFactsLine)).dy),
      );
    });

    testWidgets('on a phone Continue pushes the next step', (tester) async {
      await pumpData(tester, setUp: setUpProgressOf(accountHere: true));

      await tester.tap(inDataPage(find.text('Continue')));
      await tester.pumpAndSettle();

      expect(find.text('page /settings/setup?step=sync'), findsOneWidget);
    });

    testWidgets('on a master-detail window Continue opens the step in the '
        'Data pane', (tester) async {
      final router = await pumpData(
        tester,
        size: const Size(1400, 2400),
        setUp: setUpProgressOf(accountHere: true),
      );

      await tester.tap(inDataPage(find.text('Continue')));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.queryParameters, {
        'selected': 'data',
        'dataPage': 'setup?step=sync',
      });
      expect(find.byType(SettingsListContent), findsOneWidget);
    });
  });

  group('Set up this device again', () {
    testWidgets('is not offered while the card shows its steps', (
      tester,
    ) async {
      await pumpData(tester, setUp: setUpProgressOf(accountHere: true));
      expect(find.text('Set up this phone again'), findsNothing);
    });

    testWidgets('is offered under Advanced once setup is complete', (
      tester,
    ) async {
      await pumpData(tester, setUp: setUpProgressOf(everything: true));

      expect(find.text('Set up this phone again'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Advanced')).dy,
        lessThan(tester.getTopLeft(find.text('Set up this phone again')).dy),
      );
    });

    // The flow opened afresh shows a hidden card again (its own test).
    testWidgets('on a hidden card, opens the flow afresh', (tester) async {
      await pumpData(tester, setUp: setUpProgressOf(hidden: true));

      await tester.tap(find.text('Set up this phone again'));
      await tester.pumpAndSettle();

      expect(find.text('page /settings/setup?again=true'), findsOneWidget);
    });
  });

  testWidgets('a Lightroom-only photos row draws no healthy mark', (
    tester,
  ) async {
    // Lightroom alone makes media health healthy, but no copies are kept;
    // a tick beside "Copies are not kept in the cloud" would contradict it.
    await pumpData(
      tester,
      dataHealth: [
        health[0],
        health[1],
        health[2],
        const FeatureHealth(
          feature: DataFeature.media,
          level: HealthLevel.healthy,
          reason: HealthReason.ok,
        ),
      ],
    );

    expect(find.text('Copies are not kept in the cloud'), findsOneWidget);
    expect(markBeside('Photos & videos'), findsNothing);
  });

  group('demo mode (#3708)', () {
    final package = DemoPackage(
      schemaVersion: 1,
      url: Uri.parse('https://example.com/demo.zip'),
      sha256: 'a' * 64,
      size: 10,
      generatedAt: DateTime.utc(2026, 10, 20),
    );

    tearDown(applyGlobalTestDefaults);

    testWidgets(
      'shows Explore with sample data when available and not in demo mode',
      (tester) async {
        await pumpData(tester, demoPackage: package);

        expect(find.text('Explore with sample data'), findsOneWidget);
        expect(find.text('Exit demo'), findsNothing);
      },
    );

    testWidgets('Explore with sample data sits under Advanced', (tester) async {
      await pumpData(tester, demoPackage: package);

      expect(
        tester.getTopLeft(find.text('Explore with sample data')).dy,
        greaterThan(tester.getTopLeft(find.text('Advanced')).dy),
      );
    });

    testWidgets('Explore with sample data is the last row, below Set up '
        'again', (tester) async {
      await pumpData(
        tester,
        demoPackage: package,
        setUp: setUpProgressOf(everything: true),
      );

      expect(
        tester.getTopLeft(find.text('Explore with sample data')).dy,
        greaterThan(tester.getTopLeft(find.text('Set up this phone again')).dy),
      );
    });

    testWidgets('Explore with sample data asks before downloading', (
      tester,
    ) async {
      await pumpData(tester, demoPackage: package);

      await tester.tap(find.text('Explore with sample data'));
      await tester.pumpAndSettle();
      expect(find.text('Explore with sample data?'), findsOneWidget);
      // The available package's own size, in the wording for a user whose
      // logbook is set aside.
      expect(find.textContaining('10 B'), findsOneWidget);
      expect(
        find.textContaining('set aside, untouched, until you exit demo mode'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Explore with sample data?'), findsNothing);
      expect(find.byType(DemoEnterDialog), findsNothing);
    });

    testWidgets('in demo mode Exit demo sits under Advanced', (tester) async {
      DemoModeGate.instance.debugActive = true;

      await pumpData(tester, demoPackage: package);

      expect(
        tester.getTopLeft(find.text('Exit demo')).dy,
        greaterThan(tester.getTopLeft(find.text('Advanced')).dy),
      );
    });

    testWidgets('hides it when no sample logbook is available', (tester) async {
      await pumpData(tester);

      expect(find.text('Explore with sample data'), findsNothing);
    });

    testWidgets(
      'in demo mode shows Exit demo, and the sealed rows are disabled with '
      'the note',
      (tester) async {
        DemoModeGate.instance.debugActive = true;

        await pumpData(tester, demoPackage: package);

        expect(find.text('Exit demo'), findsOneWidget);
        expect(find.text('Explore with sample data'), findsNothing);
        for (final title in [
          'Backups',
          'Sync between devices',
          'Photos & videos',
          'Shared site libraries',
          'Connected accounts',
          'Database storage',
        ]) {
          final tile = tester.widget<ListTile>(
            find.ancestor(
              of: find.text(title),
              matching: find.byType(ListTile),
            ),
          );
          expect(tile.enabled, isFalse, reason: title);
        }
        expect(find.text('Unavailable in demo mode'), findsNWidgets(6));
        expect(find.byType(SetUpDeviceCard), findsNothing);
        // The health strip would only recommend sealed backups and sync.
        expect(find.byType(DataHealthStrip), findsNothing);
      },
    );

    testWidgets('Exit demo asks for confirmation and exits only on confirm', (
      tester,
    ) async {
      DemoModeGate.instance.debugActive = true;
      var exits = 0;
      await pumpData(
        tester,
        demoPackage: package,
        exitDemo: () async => exits++,
      );

      await tester.tap(find.text('Exit demo'));
      await tester.pumpAndSettle();
      expect(find.text('Exit demo mode?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(exits, 0);

      await tester.tap(find.text('Exit demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit demo').last);
      await tester.pumpAndSettle();
      expect(exits, 1);
    });
  });
}
