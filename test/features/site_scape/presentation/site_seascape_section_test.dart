import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_seascape_section.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'site_terrain_pane_test_support.dart';

void main() {
  Future<void> pumpSection(
    WidgetTester tester,
    SiteSeascapeState state, {
    VoidCallback? onOpenFullscreen,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => TestSettingsNotifier()),
          siteSeascapeProvider.overrideWith((ref, id) async => state),
          siteFeaturesProvider(
            'site-1',
          ).overrideWith((ref) async => const <SiteFeature>[]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SiteSeascapeSection(
                siteId: 'site-1',
                onOpenFullscreen: onOpenFullscreen ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shows the site terrain under the card title', (tester) async {
    await pumpSection(tester, readyState());

    expect(find.text('Site Seascape'), findsOneWidget);
    final pane = tester.widget<SiteTerrainPane>(find.byType(SiteTerrainPane));
    expect(pane.siteId, 'site-1');
    expect(pane.playbackContext, isNull);
  });

  testWidgets('gives the terrain a fixed height inside a scrolling page', (
    tester,
  ) async {
    // The pane fills its slot, so inside an unbounded scroll view the card
    // has to bound it or layout throws.
    await pumpSection(tester, readyState());

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(SiteTerrainPane)).height,
      SiteSeascapeSection.terrainHeight,
    );
  });

  testWidgets('gives the terrain more height on a phone-width card', (
    tester,
  ) async {
    // The pane's overlay chips sit below the terrain and wrap onto several
    // rows at phone width, which would otherwise squeeze the terrain itself.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    await pumpSection(tester, readyState());

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(SiteTerrainPane)).height,
      SiteSeascapeSection.narrowTerrainHeight,
    );
    expect(
      SiteSeascapeSection.narrowTerrainHeight,
      greaterThan(SiteSeascapeSection.terrainHeight),
    );
  });

  testWidgets('the fullscreen action hands control back to the host', (
    tester,
  ) async {
    var opened = 0;
    await pumpSection(tester, readyState(), onOpenFullscreen: () => opened++);

    await tester.tap(find.byTooltip('View fullscreen'));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('a site without depth data says so inside the card', (
    tester,
  ) async {
    await pumpSection(tester, const SiteSeascapeNoData());

    expect(find.text('Site Seascape'), findsOneWidget);
    expect(
      find.text('No bathymetry available for this location'),
      findsOneWidget,
    );
  });
}
