import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_dive_statistics.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_hero_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_section_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The hero card is the fixed top of the Site Details page: first in the
/// scrolling body in both standalone and embedded modes, in every layout,
/// and never one of the configurable sections.
void main() {
  const site = DiveSite(id: 'site-1', name: 'Blue Hole', maxDepth: 30);

  Future<void> pumpPage(
    WidgetTester tester, {
    required bool embedded,
    AppSettings settings = const AppSettings(),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          siteProvider(site.id).overrideWith((_) async => site),
          siteDiveCountProvider(site.id).overrideWith((_) async => 2),
          siteDiveStatisticsProvider(site.id).overrideWith(
            (_) async => SiteDiveStatistics(
              diveCount: 2,
              maxDepthReached: 22,
              longestDiveSeconds: 2700,
              lastDiveAt: DateTime(2026, 3, 1),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // An embedded page borrows its host's Material, as it does under
          // the master-detail scaffold in the app; the standalone page
          // brings its own Scaffold and ignores this one.
          home: Scaffold(
            body: SiteDetailPage(siteId: site.id, embedded: embedded),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectHeroFirstInBody(WidgetTester tester) {
    final hero = find.byType(SiteDetailHeroCard);
    expect(hero, findsOneWidget);
    // Scrolls with the content rather than sitting in the page chrome.
    expect(
      find.descendant(of: find.byType(SingleChildScrollView), matching: hero),
      findsOneWidget,
    );
    // Above the configurable sections.
    final sections = find.byType(SiteDetailSectionList);
    expect(sections, findsOneWidget);
    expect(
      tester.getBottomLeft(hero).dy,
      lessThanOrEqualTo(tester.getTopLeft(sections).dy),
    );
  }

  testWidgets('sits first in the body of the standalone page', (tester) async {
    await pumpPage(tester, embedded: false);
    expectHeroFirstInBody(tester);
  });

  testWidgets('sits first in the body of the embedded page', (tester) async {
    await pumpPage(tester, embedded: true);
    expectHeroFirstInBody(tester);
  });

  testWidgets('stays unfolded above the sections in the list layout', (
    tester,
  ) async {
    await pumpPage(
      tester,
      embedded: true,
      settings: const AppSettings(siteDetailLayout: DiveDetailLayout.list),
    );
    expectHeroFirstInBody(tester);
    // The hero's stat row renders in the list layout, where every section
    // below it starts folded to a header row.
    expect(find.text('30.0m'), findsOneWidget);
  });
}
