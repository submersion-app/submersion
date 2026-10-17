// Issues #3390 and #3394: Settings > Data opens with a status strip and a
// facts line, drops every card, and marks the four feature rows with the
// same health symbol as the strip.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_health_strip.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
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

  Future<void> pumpData(
    WidgetTester tester, {
    DateTime? lastSync,
    int devices = 1,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/settings?selected=data',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(
            dataHealth: health,
            lastSync: lastSync,
            syncedDevices: devices,
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
  }

  Finder markBeside(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
    matching: find.byType(HealthSymbol),
  );

  testWidgets('the Data page has no Card', (tester) async {
    await pumpData(tester);

    final page = find
        .ancestor(
          of: find.text('Backup & Sync'),
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    expect(
      find.descendant(of: page, matching: find.byType(Card)),
      findsNothing,
    );
  });

  testWidgets('the dashboard sits above the Backup & Sync header', (
    tester,
  ) async {
    await pumpData(tester);

    expect(
      tester.getTopLeft(find.byType(DataHealthStrip)).dy,
      lessThan(tester.getTopLeft(find.text('Backup & Sync')).dy),
    );
  });

  testWidgets('row marks match the strip', (tester) async {
    await pumpData(tester);

    final backupMark = tester.widget<HealthSymbol>(
      markBeside('Backup & Restore'),
    );
    expect((backupMark.level, backupMark.size), (HealthLevel.healthy, 16));
    expect(
      tester.widget<HealthSymbol>(markBeside('Shared Site Libraries')).level,
      HealthLevel.attention,
    );
    expect(markBeside('Photos & Media'), findsNothing);
    expect(markBeside('Database Storage'), findsNothing);
  });

  testWidgets('sync row shows synced time and device count', (tester) async {
    await pumpData(
      tester,
      lastSync: DateTime.now().subtract(const Duration(minutes: 12)),
      devices: 3,
    );

    expect(find.text('Synced 12m ago · 3 devices'), findsOneWidget);
  });

  testWidgets('sync row without a sync keeps its generic subtitle', (
    tester,
  ) async {
    await pumpData(tester);

    expect(find.text('Sync via cloud storage'), findsOneWidget);
  });
}
