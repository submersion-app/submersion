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

  // Issue #4561: the row is the feature's status, so the symbol takes the
  // leading slot and the title carries no second mark.
  testWidgets('the status symbol leads the row', (tester) async {
    await pumpTile(
      tester,
      const DataRowTile(
        icon: Icons.backup,
        title: 'Backups',
        subtitle: 'Not backed up yet',
        route: '/feature',
        healthLevel: HealthLevel.attention,
      ),
    );
    final mark = tester.widget<HealthSymbol>(find.byType(HealthSymbol));
    expect((mark.level, mark.size), (HealthLevel.attention, 24));
    expect(
      tester.widget<ListTile>(find.byType(ListTile)).leading,
      isA<HealthSymbol>(),
    );
    expect(find.byIcon(Icons.backup), findsNothing);
  });

  testWidgets('not set up leads with the hollow symbol', (tester) async {
    await pumpTile(
      tester,
      const DataRowTile(
        icon: Icons.photo,
        title: 'Photos & videos',
        subtitle: 'Copies are not kept in the cloud',
        route: '/feature',
        healthLevel: HealthLevel.notSetUp,
      ),
    );
    expect(
      tester.widget<HealthSymbol>(find.byType(HealthSymbol)).level,
      HealthLevel.notSetUp,
    );
  });

  testWidgets('a row with no health keeps its icon', (tester) async {
    await pumpTile(
      tester,
      const DataRowTile(
        icon: Icons.history,
        title: 'Change log',
        subtitle: 'Every edit',
        route: '/feature',
      ),
    );
    expect(find.byType(HealthSymbol), findsNothing);
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets('a disabled row keeps its icon and shows no status', (
    tester,
  ) async {
    await pumpTile(
      tester,
      const DataRowTile(
        icon: Icons.backup,
        title: 'Backups',
        subtitle: 'Not backed up yet',
        route: '/feature',
        healthLevel: HealthLevel.failing,
        enabled: false,
      ),
    );
    expect(find.byType(HealthSymbol), findsNothing);
    expect(find.byIcon(Icons.backup), findsOneWidget);
  });

  group('status action', () {
    const action = Key('action');
    const tile = DataRowTile(
      icon: Icons.sync,
      title: 'Sync between devices',
      subtitle: 'Sync paused: sign in again',
      route: '/feature',
      healthLevel: HealthLevel.failing,
      statusAction: TextButton(
        key: action,
        onPressed: null,
        child: Text('Sign in again'),
      ),
    );

    testWidgets('sits beside the sentence while it fits', (tester) async {
      await pumpTile(tester, tile);
      expect(
        tester.getTopLeft(find.byKey(action)).dy,
        lessThan(tester.getBottomLeft(find.text(tile.subtitle)).dy),
      );
    });

    testWidgets('goes under the sentence on a narrow phone at large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: const Scaffold(body: tile),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.byKey(action)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text(tile.subtitle)).dy),
      );
    });
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

  testWidgets('the Set up action names its feature for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpTile(
      tester,
      const DataRowTile(
        icon: Icons.sync,
        title: 'Sync between devices',
        subtitle: 'Only on this device',
        route: '/feature',
        offersSetUp: true,
      ),
    );
    expect(
      find.bySemanticsLabel('Set up Sync between devices'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a row with no target informs: no chevron, no tap', (
    tester,
  ) async {
    await pumpTile(
      tester,
      const DataRowTile(
        icon: Icons.folder,
        title: 'Database storage',
        subtitle: 'App default location',
      ),
    );
    expect(find.text('App default location'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
    await tester.tap(find.text('Database storage'));
    await tester.pumpAndSettle();
    expect(find.text('feature'), findsNothing);
  });
}
