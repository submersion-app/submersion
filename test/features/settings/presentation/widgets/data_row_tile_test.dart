// Issue #3482: a Settings > Data row shows the feature's health mark, a
// one-sentence status and, when the feature is not set up, a Set up button.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
import 'package:submersion/features/settings/presentation/widgets/data_row_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester, DataRowTile tile) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: tile),
        ),
        GoRoute(
          path: '/feature',
          builder: (context, state) => const Scaffold(body: Text('feature')),
        ),
        GoRoute(
          path: '/setup',
          builder: (context, state) => const Scaffold(body: Text('setup')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no mark for a feature that is not set up', (tester) async {
    await pumpTile(
      tester,
      const DataRowTile(
        icon: Icons.photo,
        title: 'Photos & videos',
        subtitle: 'Copies are not kept in the cloud',
        route: '/feature',
        health: FeatureHealth(
          feature: DataFeature.media,
          level: HealthLevel.notSetUp,
          reason: HealthReason.notSetUp,
        ),
      ),
    );
    expect(find.byType(HealthSymbol), findsNothing);
    expect(find.text('Copies are not kept in the cloud'), findsOneWidget);
  });

  testWidgets('a 16 dp mark for any other level', (tester) async {
    await pumpTile(
      tester,
      const DataRowTile(
        icon: Icons.backup,
        title: 'Backups',
        subtitle: 'Not backed up yet',
        route: '/feature',
        health: FeatureHealth(
          feature: DataFeature.backup,
          level: HealthLevel.attention,
          reason: HealthReason.backupNever,
        ),
      ),
    );
    final mark = tester.widget<HealthSymbol>(find.byType(HealthSymbol));
    expect((mark.level, mark.size), (HealthLevel.attention, 16));
  });

  testWidgets('Set up opens the set up route, the row opens its own', (
    tester,
  ) async {
    const tile = DataRowTile(
      icon: Icons.sync,
      title: 'Sync between devices',
      subtitle: 'Only on this device',
      route: '/feature',
      offersSetUp: true,
      setUpRoute: '/setup',
    );
    await pumpTile(tester, tile);
    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();
    expect(find.text('setup'), findsOneWidget);

    await pumpTile(tester, tile);
    await tester.tap(find.text('Sync between devices'));
    await tester.pumpAndSettle();
    expect(find.text('feature'), findsOneWidget);
  });

  testWidgets('without Set up there is no action line', (tester) async {
    await pumpTile(
      tester,
      const DataRowTile(
        icon: Icons.folder,
        title: 'Database storage',
        subtitle: 'App default location',
        route: '/feature',
      ),
    );
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.text('Set up'), findsNothing);
  });
}
