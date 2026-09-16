import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_dive_statistics.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/section_fold.dart';

import '../../../../helpers/mock_providers.dart';

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

  Future<MockSettingsNotifier> pumpPage(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    bool embedded = true,
    Size surface = const Size(600, 1400),
    List<Tag> tags = const [],
    VoidCallback? onStatsLoad,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = surface;
    addTearDown(tester.view.reset);

    final notifier = MockSettingsNotifier(settings);
    final overrides = await getBaseOverrides(settingsNotifier: notifier);
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
            // The app always hosts the embedded page inside
            // MasterDetailScaffold's Scaffold, which the list layout's fold
            // headers (InkWells) need as their Material ancestor.
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
          siteDiveStatisticsProvider(site.id).overrideWith((_) async {
            onStatsLoad?.call();
            return stats;
          }),
          tagsForSiteProvider(site.id).overrideWith((_) async => tags),
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
    return notifier;
  }

  List<SiteDetailSectionConfig> hide(SiteDetailSectionId id) => [
    for (final s in SiteDetailSectionConfig.defaultSections)
      s.id == id ? s.copyWith(visible: false) : s,
  ];

  testWidgets('the tune button sits in the embedded header', (tester) async {
    await pumpPage(tester);

    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('the tune button sits in the standalone app bar', (tester) async {
    await pumpPage(tester, embedded: false);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.tune),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a hidden card is not on the page', (tester) async {
    await pumpPage(
      tester,
      settings: AppSettings(
        siteDetailSections: hide(SiteDetailSectionId.notes),
      ),
    );

    expect(find.text('Notes'), findsNothing);
    expect(find.text('Dives at this Site'), findsOneWidget);
  });

  testWidgets('the saved order is the page order', (tester) async {
    await pumpPage(
      tester,
      settings: AppSettings(
        siteDetailSections: [
          const SiteDetailSectionConfig(
            id: SiteDetailSectionId.notes,
            visible: true,
          ),
          for (final s in SiteDetailSectionConfig.defaultSections)
            if (s.id != SiteDetailSectionId.notes) s,
        ],
      ),
    );

    expect(
      tester.getTopLeft(find.text('Notes')).dy,
      lessThan(tester.getTopLeft(find.text('Dives at this Site')).dy),
    );
  });

  testWidgets('the list layout folds every card this site has', (tester) async {
    await pumpPage(
      tester,
      settings: const AppSettings(siteDetailLayout: DiveDetailLayout.list),
    );

    // No coordinates, altitude, hazards or access info on this site, so
    // Map, Features, Tides, Ecosystem, Altitude, Hazards and Access have
    // nothing to show; the other nine cards fold.
    expect(find.byType(SectionFold), findsNWidgets(9));
    // Inside the folded depth card, so not built.
    expect(find.text('Deepest Dive'), findsNothing);
  });

  testWidgets('folded cards start none of their lookups', (tester) async {
    var statsLoads = 0;
    await pumpPage(
      tester,
      settings: const AppSettings(siteDetailLayout: DiveDetailLayout.list),
      onStatsLoad: () => statsLoads++,
    );

    // Dives at this Site and Depth Range both read the dive statistics, but
    // folded they are never built, so nothing asks for them.
    expect(statsLoads, 0);

    await tester.tap(find.text('Depth Range'));
    await tester.pumpAndSettle();

    expect(statsLoads, greaterThan(0));
  });

  testWidgets('unfolding a card shows it and remembers it', (tester) async {
    final notifier = await pumpPage(
      tester,
      settings: const AppSettings(siteDetailLayout: DiveDetailLayout.list),
    );

    await tester.tap(find.text('Depth Range'));
    await tester.pumpAndSettle();

    expect(
      notifier.state.siteDetailSections
          .firstWhere((s) => s.id == SiteDetailSectionId.depth)
          .expanded,
      isTrue,
    );
    expect(find.text('Deepest Dive'), findsOneWidget);
  });

  group('the Tags card', () {
    final tag = Tag(
      id: 't1',
      name: 'To try',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      scopes: const {TagScope.dives, TagScope.sites},
    );

    testWidgets('shows after Site Media when the site has tags', (
      tester,
    ) async {
      await pumpPage(tester, tags: [tag]);

      expect(find.text('To try'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Tags')).dy,
        greaterThan(tester.getTopLeft(find.text('Site Media')).dy),
      );
    });

    testWidgets('stays hidden when switched off, tags or not', (tester) async {
      await pumpPage(
        tester,
        tags: [tag],
        settings: AppSettings(
          siteDetailSections: hide(SiteDetailSectionId.tags),
        ),
      );

      expect(find.text('To try'), findsNothing);
      expect(find.text('Tags'), findsNothing);
    });
  });
}
