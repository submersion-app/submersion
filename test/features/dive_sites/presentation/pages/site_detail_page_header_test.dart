import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_dive_statistics.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_header.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The pinned top of Site Details: the map card, then the site's name
/// header, above the diver's configurable cards.
void main() {
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

  const dry = DiveSite(id: 'site-1', name: 'Blue Hole', maxDepth: 30);
  final located = dry.copyWith(location: const GeoPoint(28.57, 34.53));

  /// The cards that only a located site can show, switched off so a test
  /// with coordinates does not also pump tides, reef health and features.
  List<SiteDetailSectionConfig> withoutLocatedCards() => [
    for (final s in SiteDetailSectionConfig.defaultSections)
      if (const {
        SiteDetailSectionId.tide,
        SiteDetailSectionId.reefHealth,
        SiteDetailSectionId.features,
      }.contains(s.id))
        s.copyWith(visible: false)
      else
        s,
  ];

  Future<void> pumpPage(
    WidgetTester tester, {
    required DiveSite site,
    DiveDetailLayout layout = DiveDetailLayout.detailed,
    bool embedded = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1600);
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(
        AppSettings(
          siteDetailLayout: layout,
          siteDetailSections: withoutLocatedCards(),
        ),
      ),
    );
    final router = GoRouter(
      initialLocation: '/sites/site-1',
      routes: [
        GoRoute(
          path: '/sites/:id',
          builder: (context, state) {
            final page = SiteDetailPage(
              siteId: state.pathParameters['id']!,
              embedded: embedded,
            );
            return embedded ? Scaffold(body: page) : page;
          },
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
          tagsForSiteProvider(site.id).overrideWith((_) async => const []),
          siteTypesForSiteProvider(site.id).overrideWith((_) async => const []),
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

  double topOf(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  testWidgets('the map sits above the header, above the first card', (
    tester,
  ) async {
    await pumpPage(tester, site: located);

    expect(
      topOf(tester, find.byType(FlutterMap)),
      lessThan(topOf(tester, find.byType(SiteDetailHeader))),
    );
    expect(
      topOf(tester, find.byType(SiteDetailHeader)),
      lessThan(topOf(tester, find.text('Dives at this Site'))),
    );
  });

  testWidgets('a site without coordinates opens on the header', (tester) async {
    await pumpPage(tester, site: dry);

    expect(find.byType(FlutterMap), findsNothing);
    expect(
      topOf(tester, find.byType(SiteDetailHeader)),
      lessThan(topOf(tester, find.text('Dives at this Site'))),
    );
  });

  testWidgets('the map and header stay pinned in the list layout', (
    tester,
  ) async {
    await pumpPage(tester, site: located, layout: DiveDetailLayout.list);

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(
      topOf(tester, find.byType(FlutterMap)),
      lessThan(topOf(tester, find.byType(SiteDetailHeader))),
    );
  });

  testWidgets('the header is on the standalone page too', (tester) async {
    await pumpPage(tester, site: located, embedded: false);

    expect(find.byType(SiteDetailHeader), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('the header and the Rating card fill the same stars', (
    tester,
  ) async {
    await pumpPage(tester, site: dry.copyWith(rating: 4.4));

    // An imported fraction fills the star in both places, so neither can
    // contradict the other. Counted inside the header, since the Rating
    // card's own title icon is a star too.
    expect(
      find.descendant(
        of: find.byType(SiteDetailHeader),
        matching: find.byIcon(Icons.star),
      ),
      findsNWidgets(5),
    );
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  testWidgets('the map is no longer a card the diver can fold', (tester) async {
    await pumpPage(tester, site: located, layout: DiveDetailLayout.list);

    // The Map card is gone from the section list, so no fold header carries
    // its name and the map itself is never collapsed.
    expect(find.text('Map'), findsNothing);
  });
}
