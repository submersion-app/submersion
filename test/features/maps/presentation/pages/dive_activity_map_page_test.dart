import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/pages/dive_activity_map_page.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Serves a fixed page of dives to the list pane, which the desktop layout
/// shows beside the map.
class _FixedPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _FixedPaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Two sites a kilometre apart that cluster at any overview zoom, and one far
// to the south on the same meridian. Stacked north to south, the fitted
// markers sit mid-width, clear of the floating action button.
const _reefA = DiveSite(
  id: 'reef-a',
  name: 'Reef A',
  location: GeoPoint(12.34, 98.76),
);
const _reefB = DiveSite(
  id: 'reef-b',
  name: 'Reef B',
  location: GeoPoint(12.35, 98.77),
);
const _farReef = DiveSite(
  id: 'far',
  name: 'Far Reef',
  location: GeoPoint(-20.0, 98.0),
);

Dive _diveAt(DiveSite site) =>
    createTestDiveWithBottomTime(id: 'dive-${site.id}').copyWith(site: site);

/// Pumps the page on a [width] by 900 surface: below 1100 the map fills it,
/// from 1100 up the list pane sits beside the map.
Future<void> _pumpPage(
  WidgetTester tester, {
  required List<DiveSite> sites,
  double width = 600,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final dives = [for (final site in sites) _diveAt(site)];
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        sitesWithCountsProvider.overrideWith(
          (ref) async => [
            for (final site in sites)
              SiteWithDiveCount(site: site, diveCount: 1),
          ],
        ),
        sortedFilteredDivesProvider.overrideWithValue(AsyncValue.data(dives)),
        paginatedDiveListProvider.overrideWith(
          (ref) =>
              _FixedPaginatedNotifier(dives.map(DiveSummary.fromDive).toList()),
        ),
        diveActivityHeatMapProvider.overrideWithValue(
          const AsyncValue<List<HeatMapPoint>>.data(<HeatMapPoint>[]),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveActivityMapPage(),
      ),
    ),
  );
  // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
  // The sites load asynchronously, so the map mounts on the second pump and
  // the cluster layer's own zoom-in only runs on the third. A cluster ignores
  // taps until that finishes.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

MapCamera _camera(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

Finder _siteMarker(String name) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == 'Dive site: $name',
);

void _expectCamera(
  WidgetTester tester, {
  required double lat,
  required double lng,
  required double zoom,
  double tolerance = 1e-6,
}) {
  final camera = _camera(tester);
  expect(camera.center.latitude, closeTo(lat, tolerance));
  expect(camera.center.longitude, closeTo(lng, tolerance));
  expect(camera.zoom, closeTo(zoom, 1e-6));
}

void main() {
  testWidgets('renders the DiveActivityMapPage FlutterMap with a site', (
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
    // A second site at the SAME location reliably clusters with the first
    // (distance 0 < radius), exercising the MarkerClusterLayer cluster builder.
    const site2 = DiveSite(
      id: 'site-2',
      name: 'Blue Hole Annex',
      location: GeoPoint(12.34, 98.76),
    );
    final dive = createTestDiveWithBottomTime(
      id: 'dive-1',
    ).copyWith(site: site);
    final dive2 = createTestDiveWithBottomTime(
      id: 'dive-2',
    ).copyWith(site: site2);

    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          sitesWithCountsProvider.overrideWith(
            (ref) async => [
              const SiteWithDiveCount(site: site, diveCount: 3),
              const SiteWithDiveCount(site: site2, diveCount: 1),
            ],
          ),
          sortedFilteredDivesProvider.overrideWithValue(
            AsyncValue.data([dive, dive2]),
          ),
          diveActivityHeatMapProvider.overrideWithValue(
            const AsyncValue<List<HeatMapPoint>>.data(<HeatMapPoint>[]),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveActivityMapPage(),
        ),
      ),
    );

    // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FlutterMap), findsWidgets);
  });

  group('camera moves', () {
    testWidgets('tapping a dive in the list pane eases to its site', (
      tester,
    ) async {
      await _pumpPage(tester, sites: [_reefA, _farReef], width: 1400);
      // Opens framed on both sites, wider than the zoom a tap eases to.
      expect(_camera(tester).zoom, lessThan(10));

      await tester.tap(find.text('Far Reef').first);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));

      _expectCamera(tester, lat: -20.0, lng: 98.0, zoom: 12.0);
    });

    testWidgets('fit-all action frames every site again', (tester) async {
      await _pumpPage(tester, sites: [_reefA, _farReef]);
      final opening = _camera(tester);

      tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .move(const LatLng(45.0, -30.0), 7.0);
      await tester.pump();
      expect(_camera(tester).center.latitude, closeTo(45.0, 1e-6));

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();

      // Back to the framing the page opened with, which shows both sites.
      _expectCamera(
        tester,
        lat: opening.center.latitude,
        lng: opening.center.longitude,
        zoom: opening.zoom,
      );
      for (final site in [_reefA, _farReef]) {
        final point = LatLng(site.location!.latitude, site.location!.longitude);
        expect(
          _camera(tester).visibleBounds.contains(point),
          isTrue,
          reason: site.name,
        );
      }
    });

    testWidgets('tapping a cluster eases in on its sites', (tester) async {
      await _pumpPage(tester, sites: [_reefA, _reefB, _farReef]);
      // Reef A and Reef B share one cluster marker counting their two dives.
      expect(_siteMarker('Reef A'), findsNothing);

      await tester.tap(find.text('2').hitTestable().first);
      // Past flutter_map's double-tap window, then through the ease.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));

      // The cluster's bounds are small enough that the fit stops at the
      // animator's maxZoom, centred between the two sites.
      _expectCamera(
        tester,
        lat: 12.345,
        lng: 98.765,
        zoom: 14.0,
        tolerance: 1e-3,
      );
    });

    testWidgets('tapping a site marker eases to it', (tester) async {
      await _pumpPage(tester, sites: [_reefA, _farReef]);

      await tester.tap(_siteMarker('Far Reef'));
      // Past flutter_map's double-tap window, then through the ease.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));

      _expectCamera(tester, lat: -20.0, lng: 98.0, zoom: 12.0);
    });
  });
}
