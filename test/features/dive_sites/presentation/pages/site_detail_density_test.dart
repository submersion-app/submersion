import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_dive_statistics.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Bumped to force a dependency-driven reload of the statistics provider,
/// which is what switching the active diver does in the real app.
final _reloadTrigger = StateProvider<int>((ref) => 0);

/// The detail page was a single column of full-width cards, several of which
/// restated something the page already showed. These tests pin the density
/// work: what got merged, what pairs up on a wide pane, and what no longer
/// appears twice.
void main() {
  const site = DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    minDepth: 5,
    maxDepth: 30,
    rating: 4,
    difficulty: SiteDifficulty.intermediate,
  );

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

  Future<void> pumpPage(WidgetTester tester, {required Size surface}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = surface;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/sites/site-1',
      routes: [
        GoRoute(
          path: '/sites/:id',
          builder: (context, state) => SiteDetailPage(
            siteId: state.pathParameters['id']!,
            embedded: true,
          ),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (context, state) =>
              Scaffold(body: Text('DIVE_${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          siteProvider(site.id).overrideWith((_) async => site),
          siteDiveCountProvider(site.id).overrideWith((_) async => 4),
          siteDiveStatisticsProvider(site.id).overrideWith((_) async => stats),
        ].cast<Override>(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder cardContaining(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(Card)).first;

  group('depth lives in one place', () {
    testWidgets(
      'the depth card carries both the rated range and the depth reached',
      (tester) async {
        await pumpPage(tester, surface: const Size(600, 1400));

        // The site's own rating and what dives actually found, together:
        // as two cards these were two unrelated "max depth" numbers with
        // nothing tying them.
        final depthCard = cardContaining('Depth Range');
        expect(
          find.descendant(of: depthCard, matching: find.text('Deepest Dive')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: depthCard,
            matching: find.text('Shallowest Dive'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('each depth statistic appears exactly once on the page', (
      tester,
    ) async {
      await pumpPage(tester, surface: const Size(600, 1400));

      expect(find.text('Deepest Dive'), findsOneWidget);
      expect(find.text('Shallowest Dive'), findsOneWidget);
    });

    testWidgets('the deepest reached row still opens that dive', (
      tester,
    ) async {
      await pumpPage(tester, surface: const Size(600, 1400));

      final finder = find.text('Deepest Dive');
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();

      expect(find.text('DIVE_dive-deepest'), findsOneWidget);
    });

    testWidgets('the dives card keeps the statistics that are not depths', (
      tester,
    ) async {
      await pumpPage(tester, surface: const Size(600, 1400));

      final divesCard = cardContaining('Dives at this Site');
      expect(
        find.descendant(of: divesCard, matching: find.text('Longest Dive')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: divesCard, matching: find.text('Last Dive')),
        findsOneWidget,
      );
    });
  });

  group('short cards pair up when the pane is wide enough', () {
    testWidgets('difficulty and rating share a row on a wide pane', (
      tester,
    ) async {
      await pumpPage(tester, surface: const Size(1100, 1400));

      final pair = find.ancestor(
        of: find.text('Difficulty Level'),
        matching: find.byType(ResponsiveSectionPair),
      );
      expect(pair, findsOneWidget);
      expect(
        find.descendant(of: pair, matching: find.text('Rating')),
        findsOneWidget,
      );

      // Sharing a row means neither card spans the pane.
      final difficultyWidth = tester
          .getSize(cardContaining('Difficulty Level'))
          .width;
      expect(difficultyWidth, lessThan(1100 * 0.75));
    });

    testWidgets('the same two cards stack on a narrow pane', (tester) async {
      await pumpPage(tester, surface: const Size(600, 1400));

      final difficulty = tester.getRect(cardContaining('Difficulty Level'));
      final rating = tester.getRect(cardContaining('Rating'));

      // Stacked, not side by side: one sits below the other.
      expect(rating.top, greaterThanOrEqualTo(difficulty.bottom));
    });
  });

  group('the page no longer repeats itself', () {
    testWidgets('the site name is not restated in a card below the header', (
      tester,
    ) async {
      await pumpPage(tester, surface: const Size(600, 1400));

      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Blue Hole'),
        ),
        findsNothing,
      );
    });
  });
  group('statistics survive a provider reload', () {
    testWidgets('the depth card keeps its reached depths while reloading', (
      tester,
    ) async {
      // A reload is not a refresh: `when(loading:)` fires for a dependency
      // change (skipLoadingOnReload defaults to false) even though the
      // previous value is still there. Reading through a helper that maps
      // loading to null therefore blanks the section mid-reload.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(600, 1400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();
      final container = ProviderContainer(
        overrides: [
          ...overrides,
          siteProvider(site.id).overrideWith((_) async => site),
          siteDiveCountProvider(site.id).overrideWith((_) async => 4),
          siteDiveStatisticsProvider(site.id).overrideWith((ref) async {
            final n = ref.watch(_reloadTrigger);
            if (n > 0) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }
            return stats;
          }),
        ].cast<Override>(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: 'site-1', embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Deepest Dive'), findsOneWidget);

      // Force the reload and look before it settles.
      container.read(_reloadTrigger.notifier).state++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(
        find.text('Deepest Dive'),
        findsOneWidget,
        reason: 'the previously loaded depths must survive the reload',
      );

      await tester.pumpAndSettle();
    });
  });
}
