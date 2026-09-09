import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_summary_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The Sites landing pane summarises a whole library. These tests pin the
/// figures it reports beyond a bare site count.
void main() {
  final sites = <SiteWithDiveCount>[
    SiteWithDiveCount(
      site: const DiveSite(
        id: 'a',
        name: 'Blue Hole',
        country: 'Malta',
        rating: 5,
      ),
      diveCount: 9,
      lastDivedAt: DateTime(2026, 8, 1),
      firstDivedAt: DateTime(2020, 1, 1),
    ),
    SiteWithDiveCount(
      site: const DiveSite(
        id: 'b',
        name: 'Cathedral',
        country: 'Malta',
        rating: 4,
      ),
      diveCount: 3,
      lastDivedAt: DateTime(2026, 9, 1),
      firstDivedAt: DateTime(2024, 5, 5),
    ),
    SiteWithDiveCount(
      site: const DiveSite(id: 'c', name: 'Wreck Alley', country: 'Mexico'),
      diveCount: 1,
      lastDivedAt: DateTime(2025, 2, 2),
      firstDivedAt: DateTime(2025, 2, 2),
    ),
    // Saved but never dived: the gap the pane never surfaced.
    const SiteWithDiveCount(
      site: DiveSite(id: 'd', name: 'Someday Reef', country: 'Egypt'),
      diveCount: 0,
    ),
    const SiteWithDiveCount(
      site: DiveSite(id: 'e', name: 'Wishlist Wall', country: 'Egypt'),
      diveCount: 0,
    ),
  ];

  Future<void> pumpSummary(
    WidgetTester tester, {
    List<SiteWithDiveCount>? library,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/sites',
      routes: [
        GoRoute(
          path: '/sites',
          builder: (context, state) => const SiteSummaryWidget(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          sitesWithCountsProvider.overrideWith((_) async => library ?? sites),
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

  Finder statTile(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(Card));

  group('the overview reports more than a site count', () {
    testWidgets('counts the countries the diver has sites in', (tester) async {
      await pumpSummary(tester);

      // Malta, Mexico, Egypt.
      expect(
        find.descendant(of: statTile('Countries'), matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('counts the saved sites that have never been dived', (
      tester,
    ) async {
      await pumpSummary(tester);

      expect(
        find.descendant(of: statTile('Not dived'), matching: find.text('2')),
        findsOneWidget,
      );
    });
  });

  group('the pane surfaces recent activity, not just totals', () {
    testWidgets('lists the most recently dived sites, newest first', (
      tester,
    ) async {
      await pumpSummary(tester);

      final heading = find.text('Recently Dived');
      expect(heading, findsOneWidget);

      // Cathedral (Sep 2026) is more recent than Blue Hole (Aug 2026).
      final section = find
          .ancestor(of: heading, matching: find.byType(Column))
          .first;
      expect(
        find.descendant(of: section, matching: find.text('Cathedral')),
        findsWidgets,
      );
    });

    testWidgets('a site never dived stays out of the recent list', (
      tester,
    ) async {
      await pumpSummary(tester);

      // It has no last-dived date, so it cannot be ranked by recency.
      expect(find.text('Someday Reef'), findsNothing);
    });
  });
  group('each list shows the value it ranks by', () {
    testWidgets('the most dived list shows the dive count, not a date', (
      tester,
    ) async {
      await pumpSummary(tester);

      final list = find.byKey(const ValueKey('summaryMostDivedList'));
      expect(list, findsOneWidget);

      // Blue Hole tops this list with 9 dives; that count is what the list
      // sorts by, so it is what the row must lead with.
      expect(
        find.descendant(of: list, matching: find.text('9 dives')),
        findsOneWidget,
      );
    });

    testWidgets('the most dived list does not print the same count twice', (
      tester,
    ) async {
      await pumpSummary(tester);

      final list = find.byKey(const ValueKey('summaryMostDivedList'));

      // The count is the trailing value here, so the secondary line carries
      // the last-dived date instead of repeating it.
      expect(
        find.descendant(of: list, matching: find.textContaining('Last dived')),
        findsWidgets,
      );
    });

    testWidgets('the recently dived list still leads with its date', (
      tester,
    ) async {
      await pumpSummary(tester);

      final list = find.byKey(const ValueKey('summaryRecentlyDivedList'));
      expect(list, findsOneWidget);

      // Ranked by recency, so the count belongs on the secondary line, where
      // it is joined to the location rather than standing alone.
      expect(
        find.descendant(of: list, matching: find.textContaining('9 dives')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: list, matching: find.text('9 dives')),
        findsNothing,
      );
    });

    testWidgets('the top rated list still leads with its rating', (
      tester,
    ) async {
      await pumpSummary(tester);

      final list = find.byKey(const ValueKey('summaryTopRatedList'));
      expect(list, findsOneWidget);
      expect(
        find.descendant(of: list, matching: find.text('5.0')),
        findsOneWidget,
      );
    });
  });
  group('the country count ignores whitespace-only values', () {
    final messyLibrary = <SiteWithDiveCount>[
      const SiteWithDiveCount(
        site: DiveSite(id: 'm1', name: 'Real', country: 'Malta'),
        diveCount: 1,
      ),
      // Imported and synced data carries untrimmed values; DiveSite's own
      // locationString trims before testing for exactly this reason.
      const SiteWithDiveCount(
        site: DiveSite(id: 'm2', name: 'Padded', country: 'Malta '),
        diveCount: 1,
      ),
      const SiteWithDiveCount(
        site: DiveSite(id: 'm3', name: 'Blank', country: '   '),
        diveCount: 1,
      ),
    ];

    testWidgets('a whitespace-only country is not a country', (tester) async {
      await pumpSummary(tester, library: messyLibrary);

      // One real country: Malta. The padded duplicate folds into it and the
      // blank one is not counted at all.
      expect(
        find.descendant(of: statTile('Countries'), matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('no blank chip appears in the countries list', (tester) async {
      await pumpSummary(tester, library: messyLibrary);

      expect(find.textContaining('Malta (2)'), findsOneWidget);
      expect(find.textContaining('Malta  ('), findsNothing);
      expect(find.textContaining('   ('), findsNothing);
    });
  });
}
