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
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_health_strip.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

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
  }) async {
    // MediaQuery follows the view, which the layout breakpoints read.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
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
        ])
          GoRoute(
            path: path,
            builder: (context, state) => Scaffold(body: Text('page $path')),
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
          ),
          logFileServiceProvider.overrideWithValue(
            LogFileService(logDirectory: logDir.path),
          ),
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
    expect(find.text('page /settings/cloud-sync'), findsOneWidget);
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
    expect(find.text('page /settings/photos-media'), findsOneWidget);
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
}
