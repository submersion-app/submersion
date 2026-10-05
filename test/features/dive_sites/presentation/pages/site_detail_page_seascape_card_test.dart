import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_scape_view.dart';
import 'package:submersion/features/site_scape/presentation/site_seascape_section.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  const gpsSite = DiveSite(
    id: 'gps-site',
    name: 'Salt Pier',
    location: GeoPoint(12.151, -68.299),
  );
  const bareSite = DiveSite(id: 'bare-site', name: 'Mystery');

  Future<void> pumpPage(
    WidgetTester tester,
    DiveSite site, {
    AppSettings settings = const AppSettings(),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          siteProvider(site.id).overrideWith((ref) async => site),
          siteDiveCountProvider(site.id).overrideWith((ref) async => 0),
          bathymetryGridProvider.overrideWith((ref, cell) async => null),
          siteFeaturesProvider(
            site.id,
          ).overrideWith((ref) async => <SiteFeature>[]),
          // The card must never start the real seascape pipeline here.
          siteSeascapeProvider.overrideWith(
            (ref, id) async => const SiteSeascapeNoData(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteDetailPage(siteId: site.id),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  List<SiteDetailSectionConfig> sectionsWhere(
    SiteDetailSectionConfig Function(SiteDetailSectionConfig) edit,
  ) => [for (final s in SiteDetailSectionConfig.defaultSections) edit(s)];

  testWidgets('a site with coordinates shows its 3D seascape card', (
    tester,
  ) async {
    await pumpPage(tester, gpsSite);

    expect(find.byType(SiteSeascapeSection), findsOneWidget);
    final pane = tester.widget<SiteTerrainPane>(
      find.descendant(
        of: find.byType(SiteSeascapeSection),
        matching: find.byType(SiteTerrainPane),
      ),
    );
    expect(pane.siteId, gpsSite.id);
  });

  testWidgets('the card sits right after Location by default', (tester) async {
    await pumpPage(tester, gpsSite);

    final location = tester.getTopLeft(find.text('Location')).dy;
    final seascape = tester.getTopLeft(find.byType(SiteSeascapeSection)).dy;
    final depth = tester.getTopLeft(find.text('Depth Range')).dy;
    expect(location, lessThan(seascape));
    expect(seascape, lessThan(depth));
  });

  testWidgets('a site without coordinates has no seascape card', (
    tester,
  ) async {
    await pumpPage(tester, bareSite);

    expect(tester.takeException(), isNull);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.byType(SiteSeascapeSection), findsNothing);
  });

  testWidgets('a diver who hid the card does not see it', (tester) async {
    await pumpPage(
      tester,
      gpsSite,
      settings: AppSettings(
        siteDetailSections: sectionsWhere(
          (s) => s.id == SiteDetailSectionId.seascape
              ? s.copyWith(visible: false)
              : s,
        ),
      ),
    );

    expect(find.byType(SiteSeascapeSection), findsNothing);
    expect(find.byType(SiteTerrainPane), findsNothing);
  });

  testWidgets('the list layout keeps the folded card unbuilt', (tester) async {
    await pumpPage(
      tester,
      gpsSite,
      settings: const AppSettings(siteDetailLayout: DiveDetailLayout.list),
    );

    expect(find.text('Site Seascape'), findsOneWidget);
    expect(find.byType(SiteTerrainPane), findsNothing);
  });

  testWidgets('the card opens the fullscreen scape in 3D', (tester) async {
    await pumpPage(tester, gpsSite);

    await tester.tap(
      find.byKey(const ValueKey('siteSeascapeFullscreenButton')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final view = tester.widget<SiteScapeView>(find.byType(SiteScapeView));
    expect(view.mode, SiteScapeMode.terrain3d);
    expect(view.selectedSiteId, gpsSite.id);
  });
}
