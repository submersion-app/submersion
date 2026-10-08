import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

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

Future<void> _pumpPage(
  WidgetTester tester,
  SiteMapPage page, {
  List<SiteWithDiveCount> sites = const [
    SiteWithDiveCount(site: _site, diveCount: 3),
    SiteWithDiveCount(site: _site2, diveCount: 1),
  ],
  Size size = const Size(600, 900),
}) async {
  // The default phone-sized surface keeps MapListScaffold in mobile mode,
  // which renders only the map pane (no list pane providers to mock).
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final base = await getBaseOverrides();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        sitesWithCountsProvider.overrideWith((ref) async => sites),
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

// Far enough apart that neither clusters with the other at the fit-all zoom.
const _apartSites = [
  SiteWithDiveCount(
    site: DiveSite(id: 's-a', name: 'Alpha', location: GeoPoint(10, 20)),
    diveCount: 1,
  ),
  SiteWithDiveCount(
    site: DiveSite(id: 's-b', name: 'Bravo', location: GeoPoint(-10, 40)),
    diveCount: 2,
  ),
];

MapCamera _camera(WidgetTester tester) => tester
    .widget<FlutterMap>(find.byType(FlutterMap).first)
    .mapController!
    .camera;

/// The on-screen marker for the site called [name] (world copies of it sit
/// off-screen, so only one is hit-testable).
Finder _marker(String name) => find
    .byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Dive site: $name',
    )
    .hitTestable();

void _expectCenteredOn(MapCamera camera, LatLng target) {
  expect(camera.center.latitude, closeTo(target.latitude, 1e-6));
  expect(camera.center.longitude, closeTo(target.longitude, 1e-6));
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

  testWidgets('the fit-all action reframes every site after a pan', (
    tester,
  ) async {
    await _pumpPage(tester, const SiteMapPage(), sites: _apartSites);
    final framed = _camera(tester);

    // Wander off somewhere else, then ask for every site again.
    tester
        .widget<FlutterMap>(find.byType(FlutterMap).first)
        .mapController!
        .move(const LatLng(50, -100), 8);
    await tester.pump();
    expect(_camera(tester).zoom, closeTo(8, 1e-6));

    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pump();

    final camera = _camera(tester);
    _expectCenteredOn(camera, framed.center);
    expect(camera.zoom, closeTo(framed.zoom, 1e-6));
  });

  testWidgets('tapping a marker selects it and eases the camera onto it', (
    tester,
  ) async {
    await _pumpPage(tester, const SiteMapPage(), sites: _apartSites);
    expect(_camera(tester).zoom, lessThan(10));

    await tester.tap(_marker('Alpha'));
    // Past flutter_map's double-tap window, then through the ease.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));

    final camera = _camera(tester);
    _expectCenteredOn(camera, const LatLng(10, 20));
    expect(camera.zoom, closeTo(12, 1e-6));
    // The selection landed too: its info card is up.
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('tapping a cluster zooms in to its bounds', (tester) async {
    // The two default sites share a spot and cluster; a far one keeps the
    // opening fit wide.
    await _pumpPage(
      tester,
      const SiteMapPage(),
      sites: const [
        SiteWithDiveCount(site: _site, diveCount: 3),
        SiteWithDiveCount(site: _site2, diveCount: 1),
        SiteWithDiveCount(
          site: DiveSite(id: 's-far', name: 'Far', location: GeoPoint(-10, 40)),
          diveCount: 1,
        ),
      ],
    );
    expect(_camera(tester).zoom, lessThan(10));

    // The cluster layer ignores taps while its opening zoom animation runs,
    // and the pump helper stops on the frame that starts it.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('2').hitTestable());
    // Past flutter_map's double-tap window, then through the ease.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));

    // A zero-size cluster bounds fits at animateToBounds' maxZoom of 14.
    final camera = _camera(tester);
    _expectCenteredOn(camera, const LatLng(12.34, 98.76));
    expect(camera.zoom, closeTo(14, 1e-6));
  });

  testWidgets('tapping a site in the list pane eases the map onto it', (
    tester,
  ) async {
    // Wide enough for MapListScaffold's master-detail split, so the list
    // pane renders beside the map.
    await _pumpPage(
      tester,
      const SiteMapPage(),
      sites: _apartSites,
      size: const Size(1400, 900),
    );
    expect(_camera(tester).zoom, lessThan(10));

    await tester.tap(find.text('Bravo').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final camera = _camera(tester);
    _expectCenteredOn(camera, const LatLng(-10, 40));
    expect(camera.zoom, closeTo(12, 1e-6));
  });
}
