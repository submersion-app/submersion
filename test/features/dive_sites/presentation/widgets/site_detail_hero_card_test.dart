import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/header_map_backdrop.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_dive_statistics.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_hero_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  // The rating and depth values format through Intl.getCurrentLocale(), and
  // the dates through a DateFormat built without a locale, so both resolve
  // the Intl.defaultLocale process global rather than the MaterialApp locale.
  // The app assigns it from the diver's locale; a widget test that pumps the
  // card alone never runs that.
  //
  // Pinned rather than merely saved: left unset it falls back to
  // Intl.systemLocale, so these assertions would rest on the host, and a test
  // earlier in the run that left another locale behind would break them.
  // en_US needs no initializeDateFormatting call; intl bundles its symbols.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  const siteId = 'site-1';

  final threeDives = SiteDiveStatistics(
    diveCount: 3,
    maxDepthReached: 24,
    minDepthReached: 8,
    longestDiveSeconds: 5400,
    averageDurationSeconds: 1800,
    firstDiveAt: DateTime(2025, 1, 5),
    lastDiveAt: DateTime(2026, 2, 20),
  );

  Future<void> pumpHero(
    WidgetTester tester, {
    required DiveSite site,
    int? diveCount = 3,
    SiteDiveStatistics? stats,
    List<SiteTypeEntity> siteTypes = const [],
    AppSettings settings = const AppSettings(),
    VoidCallback? onOpenMap,
    double surfaceWidth = 600,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(surfaceWidth, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    final effectiveStats = stats ?? threeDives;

    // A null count or stats means "still loading": the provider never
    // resolves, so the card has to render its placeholder state.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          siteDiveCountProvider(siteId).overrideWith(
            (ref) => diveCount == null
                ? Completer<int>().future
                : Future.value(diveCount),
          ),
          siteDiveStatisticsProvider(siteId).overrideWith(
            (ref) => stats == null && diveCount == null
                ? Completer<SiteDiveStatistics>().future
                : Future.value(effectiveStats),
          ),
          siteTypesForSiteProvider(
            siteId,
          ).overrideWith((ref) async => siteTypes),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SiteDetailHeroCard(site: site, onOpenMap: onOpenMap),
            ),
          ),
        ),
      ),
    );
    // Plain pumps rather than pumpAndSettle: the map backdrop's tile fade
    // never settles in a test.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('SiteDetailHeroCard title block', () {
    testWidgets('shows the site name, location and rating', (tester) async {
      const site = DiveSite(
        id: siteId,
        name: 'Blue Hole',
        country: 'Belize',
        region: 'Lighthouse Reef',
        rating: 4.5,
      );
      await pumpHero(tester, site: site);

      expect(find.text('Blue Hole'), findsOneWidget);
      expect(find.text(site.locationString), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('omits the rating star when the site has no rating', (
      tester,
    ) async {
      const site = DiveSite(id: siteId, name: 'Blue Hole');
      await pumpHero(tester, site: site);

      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('shows difficulty, water type and site type badges', (
      tester,
    ) async {
      const site = DiveSite(
        id: siteId,
        name: 'Blue Hole',
        difficulty: SiteDifficulty.advanced,
        waterType: WaterType.salt,
      );
      final types = [
        SiteTypeEntity(
          id: 'wreck',
          name: 'Wreck',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
        ),
      ];
      await pumpHero(tester, site: site, siteTypes: types);

      // Asserted on the row's input rather than on rendered text: how many
      // labels the row spells out before folding the rest into "+N" depends
      // on glyph widths, which the test font exaggerates.
      final row = tester.widget<DiveTypeBadgeRow>(
        find.byType(DiveTypeBadgeRow),
      );
      expect(row.labels, ['Advanced', 'Salt Water', 'Wreck']);
    });

    testWidgets('collapses badges that do not fit into a "+N" badge', (
      tester,
    ) async {
      const site = DiveSite(
        id: siteId,
        name: 'Blue Hole',
        difficulty: SiteDifficulty.advanced,
        waterType: WaterType.salt,
      );
      final types = [
        SiteTypeEntity(
          id: 'wreck',
          name: 'Wreck',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
        ),
      ];
      await pumpHero(tester, site: site, siteTypes: types, surfaceWidth: 400);

      // Which labels still fit depends on glyph widths, which the test font
      // exaggerates; what holds is that the tail folds into one "+N" badge
      // whose tooltip names what it hides, the site type last of all.
      final overflow = find.textContaining('+');
      expect(overflow, findsOneWidget);
      expect(find.text('Wreck'), findsNothing);
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: overflow, matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, contains('Wreck'));
    });
  });

  group('SiteDetailHeroCard stat row', () {
    testWidgets('shows dives, site max depth, longest and last dive', (
      tester,
    ) async {
      const site = DiveSite(id: siteId, name: 'Blue Hole', maxDepth: 30);
      await pumpHero(tester, site: site);

      expect(find.text('Dives'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Max Depth'), findsOneWidget);
      expect(find.text('30.0m'), findsOneWidget);
      expect(find.text('Longest Dive'), findsOneWidget);
      expect(find.text('1h 30m'), findsOneWidget);
      expect(find.text('Last Dive'), findsOneWidget);
      expect(find.text('Feb 20, 2026'), findsOneWidget);
    });

    testWidgets('formats the max depth in the active depth unit', (
      tester,
    ) async {
      const site = DiveSite(id: siteId, name: 'Blue Hole', maxDepth: 30);
      await pumpHero(
        tester,
        site: site,
        settings: const AppSettings(depthUnit: DepthUnit.feet),
      );

      expect(find.text('98.4ft'), findsOneWidget);
      expect(find.text('30.0m'), findsNothing);
    });

    testWidgets('falls back to the deepest depth reached without a site max', (
      tester,
    ) async {
      const site = DiveSite(id: siteId, name: 'Blue Hole');
      await pumpHero(tester, site: site);

      expect(find.text('24.0m'), findsOneWidget);
    });

    testWidgets('shows a dash for every stat while the lookups are in flight', (
      tester,
    ) async {
      const site = DiveSite(id: siteId, name: 'Blue Hole');
      await pumpHero(tester, site: site, diveCount: null);

      // Dives, max depth, longest dive and last dive.
      expect(find.text('--'), findsNWidgets(4));
    });

    testWidgets('shows a dash for aggregates a site with no dives lacks', (
      tester,
    ) async {
      const site = DiveSite(id: siteId, name: 'Blue Hole', maxDepth: 12);
      await pumpHero(
        tester,
        site: site,
        diveCount: 0,
        stats: SiteDiveStatistics.empty,
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.text('12.0m'), findsOneWidget);
      // Longest dive and last dive.
      expect(find.text('--'), findsNWidgets(2));
    });
  });

  group('SiteDetailHeroCard map backdrop', () {
    testWidgets('renders no map and ignores taps without coordinates', (
      tester,
    ) async {
      const site = DiveSite(id: siteId, name: 'Blue Hole');
      var opened = 0;
      await pumpHero(tester, site: site, onOpenMap: () => opened++);

      expect(find.byType(HeaderMapBackdrop), findsNothing);
      expect(find.byType(DiveLocationsMap), findsNothing);
      expect(find.text('View Map'), findsNothing);

      await tester.tap(find.text('Blue Hole'));
      await tester.pump();
      expect(opened, 0);
    });

    testWidgets('renders the faded map and opens the map on tap', (
      tester,
    ) async {
      const site = DiveSite(
        id: siteId,
        name: 'Blue Hole',
        location: GeoPoint(17.3, -87.5),
      );
      var opened = 0;
      await pumpHero(tester, site: site, onOpenMap: () => opened++);

      expect(find.byType(HeaderMapBackdrop), findsOneWidget);
      final map = tester.widget<DiveLocationsMap>(
        find.byType(DiveLocationsMap),
      );
      expect(map.interactive, isFalse);
      expect(map.site, const GeoPoint(17.3, -87.5));

      // The badge is a decorated box over the card's InkWell; a real pointer
      // on it must reach the card rather than land in a dead zone.
      await tester.tap(find.text('View Map'));
      await tester.pump();
      expect(opened, 1);

      await tester.tap(find.text('Blue Hole'));
      await tester.pump();
      expect(opened, 2);
    });

    testWidgets('keeps the rating and badges clear of the View Map badge', (
      tester,
    ) async {
      const site = DiveSite(
        id: siteId,
        name: 'Blue Hole',
        location: GeoPoint(17.3, -87.5),
        rating: 4.5,
        difficulty: SiteDifficulty.advanced,
      );
      await pumpHero(tester, site: site, onOpenMap: () {});

      // Both live in the card's top-right corner. The badge must not sit on
      // top of the rating or the difficulty badge under it.
      final badge = tester.getRect(find.text('View Map'));
      expect(badge.overlaps(tester.getRect(find.text('4.5'))), isFalse);
      expect(badge.overlaps(tester.getRect(find.text('Advanced'))), isFalse);
      expect(
        tester.getRect(find.text('4.5')).top,
        greaterThanOrEqualTo(badge.bottom),
      );
    });
  });
}
