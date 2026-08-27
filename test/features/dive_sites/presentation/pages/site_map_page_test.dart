import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_map_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _site = DiveSite(
  id: 'site-1',
  name: 'Blue Hole',
  location: GeoPoint(12.34, 98.76),
);
// A second site at the SAME location reliably clusters with the first,
// exercising the MarkerClusterLayer cluster builder.
const _site2 = DiveSite(
  id: 'site-2',
  name: 'Annex Reef',
  location: GeoPoint(12.34, 98.76),
);

BathymetryGrid _grid() => BathymetryGrid(
  originLat: 12.34,
  originLon: 98.76,
  cellSizeLatDeg: 0.001,
  cellSizeLonDeg: 0.001,
  rows: 3,
  cols: 3,
  depthsMeters: const [5, 5, 5, 25, 25, 25, 45, 45, 45],
  sourceId: 'test',
  resolutionMeters: 100,
  fetchedAt: DateTime.utc(2026, 8, 15),
);

Future<void> _pumpPage(WidgetTester tester, SiteMapPage page) async {
  // Phone-sized surface keeps MapListScaffold in mobile mode, which renders
  // only the map pane (no list pane providers to mock).
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(600, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final base = await getBaseOverrides();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        sitesWithCountsProvider.overrideWith(
          (ref) async => [
            const SiteWithDiveCount(site: _site, diveCount: 3),
            const SiteWithDiveCount(site: _site2, diveCount: 1),
          ],
        ),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
        bathymetryGridProvider.overrideWith((ref, cell) async => _grid()),
        // Entering 3D must not fire the real seascape pipeline: park the
        // pane on a terminal state.
        siteSeascapeProvider.overrideWith(
          (ref, id) async => const SiteSeascapeNoData(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ),
  );

  // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('renders the SiteMapPage FlutterMap with a site marker', (
    tester,
  ) async {
    await _pumpPage(tester, const SiteMapPage());
    expect(find.byType(FlutterMap), findsWidgets);
  });

  testWidgets('deep link seeds the selection and lands in 3D', (tester) async {
    await _pumpPage(
      tester,
      const SiteMapPage(initialSiteId: 'site-1', initialScape3d: true),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SiteTerrainPane), findsOneWidget);
  });

  testWidgets('plain site deep link stays in 2D with the site selected', (
    tester,
  ) async {
    await _pumpPage(tester, const SiteMapPage(initialSiteId: 'site-1'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SiteTerrainPane), findsNothing);
    // The info card for the seeded selection is visible.
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets('the 2D/3D toggle is docked on the right of the map pane', (
    tester,
  ) async {
    await _pumpPage(tester, const SiteMapPage(initialSiteId: 'site-1'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final toggle = find.byKey(const ValueKey('siteScape2dButton'));
    expect(toggle, findsOneWidget);
    // Right of centre: the pane's controls all cluster on one side, so the
    // mode buttons no longer sit alone in the opposite corner.
    final pane = tester.getRect(find.byType(FlutterMap).first);
    expect(tester.getCenter(toggle).dx, greaterThan(pane.center.dx));
    expect(tester.getCenter(toggle).dy, lessThan(pane.center.dy));
  });

  testWidgets('unknown deep-link site resolves the seed without zoom or 3D', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const SiteMapPage(initialSiteId: 'no-such-site', initialScape3d: true),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // The seed cannot resolve to a site: the page stays a plain 2D map
    // (no pane, no info card) and throws nothing.
    expect(find.byType(SiteTerrainPane), findsNothing);
    expect(find.byType(FlutterMap), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
