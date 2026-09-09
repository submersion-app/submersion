import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_dive_statistics.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The statistics card links each aggregate to the dive it was taken from
/// (the anchor ids on [SiteDiveStatistics]), so these tests drive real taps
/// through a router and assert on where the diver lands.
void main() {
  // No coordinates: the map, tide and reef sections all gate on them, so the
  // page under test stays to the cards this suite cares about.
  const site = DiveSite(id: 'site-1', name: 'Blue Hole');

  const stats = SiteDiveStatistics(
    diveCount: 4,
    maxDepthReached: 42,
    minDepthReached: 8,
    longestDiveSeconds: 4500,
    averageDurationSeconds: 2250,
    deepestDiveId: 'dive-deepest',
    shallowestDiveId: 'dive-shallowest',
    longestDiveId: 'dive-longest',
    firstDiveId: 'dive-first',
    lastDiveId: 'dive-last',
  );

  void setMobileSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<ProviderContainer> pumpPage(
    WidgetTester tester, {
    required SiteDiveStatistics siteStats,
    int diveCount = 4,
  }) async {
    setMobileSurface(tester);
    final overrides = await getBaseOverrides();

    final router = GoRouter(
      initialLocation: '/sites/site-1',
      routes: [
        GoRoute(
          path: '/sites/:id',
          builder: (context, state) =>
              SiteDetailPage(siteId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/dives',
          builder: (context, state) =>
              const Scaffold(body: Text('DIVE_LIST_PAGE')),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (context, state) =>
              Scaffold(body: Text('DIVE_${state.pathParameters['id']}')),
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        ...overrides,
        siteProvider(site.id).overrideWith((_) async => site),
        siteDiveCountProvider(site.id).overrideWith((_) async => diveCount),
        siteDiveStatisticsProvider(
          site.id,
        ).overrideWith((_) async => siteStats),
      ].cast<Override>(),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          // Pinned: these assertions are on English UI strings.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Scrolls [label] into view before tapping it.
  ///
  /// Without this the lower rows sit past the bottom of the test surface and
  /// tap() logs a hit-test warning and does nothing - which would quietly
  /// turn every "links nowhere" assertion into a false pass.
  Future<void> tapRow(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('site statistics link to the dive each number came from', () {
    testWidgets('the deepest dive statistic opens that dive', (tester) async {
      await pumpPage(tester, siteStats: stats);

      await tapRow(tester, 'Deepest Dive');

      expect(find.text('DIVE_dive-deepest'), findsOneWidget);
    });

    testWidgets('the longest dive statistic opens that dive', (tester) async {
      await pumpPage(tester, siteStats: stats);

      await tapRow(tester, 'Longest Dive');

      expect(find.text('DIVE_dive-longest'), findsOneWidget);
    });

    testWidgets('the shallowest dive statistic opens that dive', (
      tester,
    ) async {
      await pumpPage(tester, siteStats: stats);

      await tapRow(tester, 'Shallowest Dive');

      expect(find.text('DIVE_dive-shallowest'), findsOneWidget);
    });

    testWidgets('the average duration statistic links nowhere', (tester) async {
      // No single dive holds the mean, so this row must stay inert rather
      // than borrow a neighbouring row's anchor.
      await pumpPage(tester, siteStats: stats);

      await tapRow(tester, 'Average Duration');

      expect(find.byType(SiteDetailPage), findsOneWidget);
      expect(find.textContaining('DIVE_dive-'), findsNothing);
    });

    testWidgets('a statistic with no anchor dive links nowhere', (
      tester,
    ) async {
      // Depths are present but every dive lacked one, so the aggregate and
      // its anchor are both null and the row must not become a dead link.
      await pumpPage(
        tester,
        siteStats: const SiteDiveStatistics(
          diveCount: 2,
          longestDiveSeconds: 3000,
          longestDiveId: 'dive-longest',
        ),
      );

      await tapRow(tester, 'Deepest Dive');

      expect(find.byType(SiteDetailPage), findsOneWidget);
      expect(find.textContaining('DIVE_dive-'), findsNothing);
    });
  });

  group('the statistics card footer opens the filtered dive list', () {
    testWidgets('tapping the footer filters the dive list to this site', (
      tester,
    ) async {
      final container = await pumpPage(tester, siteStats: stats);

      await tapRow(tester, 'View all 4 dives');

      expect(find.text('DIVE_LIST_PAGE'), findsOneWidget);
      expect(container.read(diveFilterProvider).siteId, equals(site.id));
    });

    testWidgets(
      'the footer counts every dive at the site, not just the scoped ones',
      (tester) async {
        // siteDiveCountProvider counts all dives; SiteDiveStatistics applies
        // DiveStatsScope. The footer opens the unscoped list, so it must show
        // the unscoped number or it disagrees with what the diver then sees.
        await pumpPage(tester, siteStats: stats, diveCount: 7);

        expect(find.text('View all 7 dives'), findsOneWidget);
      },
    );
  });
  group('the dives card degrades honestly when the count fails', () {
    testWidgets('a failed count shows a stable message, not a spinner', (
      tester,
    ) async {
      setMobileSurface(tester);
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(site.id).overrideWith((_) async => site),
            siteDiveCountProvider(
              site.id,
            ).overrideWith((_) async => throw Exception('count unavailable')),
            siteDiveStatisticsProvider(
              site.id,
            ).overrideWith((_) async => SiteDiveStatistics.empty),
          ].cast<Override>(),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: 'site-1', embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A spinner here would never resolve: the provider has already failed.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Not available'), findsWidgets);
    });

    testWidgets('a count still in flight does show a spinner', (tester) async {
      setMobileSurface(tester);
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(site.id).overrideWith((_) async => site),
            siteDiveCountProvider(site.id).overrideWith(
              (_) => Future.delayed(const Duration(seconds: 5), () => 3),
            ),
            siteDiveStatisticsProvider(
              site.id,
            ).overrideWith((_) async => SiteDiveStatistics.empty),
          ].cast<Override>(),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: 'site-1', embedded: true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Drain the pending timer before teardown.
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
