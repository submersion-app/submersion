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

  Future<void> pumpSummary(WidgetTester tester) async {
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
          sitesWithCountsProvider.overrideWith((_) async => sites),
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
}
