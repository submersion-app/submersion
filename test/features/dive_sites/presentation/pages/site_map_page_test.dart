import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_map_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('renders the SiteMapPage FlutterMap with a site marker', (
    tester,
  ) async {
    // Phone-sized surface keeps MapListScaffold in mobile mode, which renders
    // only the map pane (no list pane providers to mock).
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const site = DiveSite(
      id: 'site-1',
      name: 'Blue Hole',
      location: GeoPoint(12.34, 98.76),
    );
    // A second site at the SAME location reliably clusters with the first,
    // exercising the MarkerClusterLayer cluster builder.
    const site2 = DiveSite(
      id: 'site-2',
      name: 'Blue Hole Annex',
      location: GeoPoint(12.34, 98.76),
    );

    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          sitesWithCountsProvider.overrideWith(
            (ref) async => [
              SiteWithDiveCount(site: site, diveCount: 3),
              SiteWithDiveCount(site: site2, diveCount: 1),
            ],
          ),
          siteCoverageHeatMapProvider.overrideWith(
            (ref) async => <HeatMapPoint>[],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteMapPage(),
        ),
      ),
    );

    // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FlutterMap), findsWidgets);
  });
}
