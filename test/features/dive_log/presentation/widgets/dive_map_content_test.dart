import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_map_content.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

DiveSite _site({
  String id = 'site-1',
  String name = 'Blue Hole',
  double lat = 12.34,
  double lng = 98.76,
}) {
  return DiveSite(id: id, name: name, location: GeoPoint(lat, lng));
}

Dive _diveAtSite(DiveSite site, {String id = 'dive-1'}) {
  return createTestDiveWithBottomTime(id: id).copyWith(site: site);
}

Future<void> _pump(
  WidgetTester tester, {
  required AsyncValue<List<Dive>> dives,
  String? selectedId,
  ValueNotifier<String?>? selection,
  void Function(String?)? onItemSelected,
}) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        sortedFilteredDivesProvider.overrideWithValue(dives),
        diveActivityHeatMapProvider.overrideWithValue(
          const AsyncValue<List<HeatMapPoint>>.data(<HeatMapPoint>[]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          // A [selection] lets a test change selectedId on the mounted map,
          // the way the dive list does, without rebuilding the scope.
          body: selection == null
              ? DiveMapContent(
                  selectedId: selectedId,
                  onItemSelected: onItemSelected ?? (_) {},
                )
              : ValueListenableBuilder<String?>(
                  valueListenable: selection,
                  builder: (context, id, _) => DiveMapContent(
                    selectedId: id,
                    onItemSelected: onItemSelected ?? (_) {},
                  ),
                ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

MapCamera _camera(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

Finder _siteMarker(String name) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == 'Select dive site $name',
);

// Two sites a kilometre apart that cluster at any overview zoom, and one far
// to the south on the same meridian. Stacked north to south, they keep the
// markers clear of the heat map controls in the top right corner.
final _reefA = _site(id: 'reef-a', name: 'Reef A', lat: 12.34, lng: 98.76);
final _reefB = _site(id: 'reef-b', name: 'Reef B', lat: 12.35, lng: 98.77);
final _farReef = _site(id: 'far', name: 'Far Reef', lat: -20.0, lng: 98.0);

void main() {
  testWidgets('renders the FlutterMap with a site marker for dives', (
    tester,
  ) async {
    final site = _site();
    await _pump(tester, dives: AsyncValue.data([_diveAtSite(site)]));

    expect(find.byType(FlutterMap), findsOneWidget);
    // The fit-all-sites control is part of the rendered map overlay.
    expect(find.byIcon(Icons.my_location), findsOneWidget);

    // Tapping empty map (a corner, away from the centered marker) clears the
    // selection via the map's onTap. No animation, so this is teardown-safe.
    await tester.tapAt(
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(5, 5),
    );
    // Flush flutter_map's double-tap disambiguation timer before teardown.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('renders the FlutterMap and info card for a selected dive', (
    tester,
  ) async {
    final site = _site();
    await _pump(
      tester,
      dives: AsyncValue.data([_diveAtSite(site)]),
      selectedId: 'dive-1',
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    // The selected dive surfaces an info card containing the site name.
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets('renders a cluster marker for co-located sites', (tester) async {
    // Two sites at the SAME location reliably cluster (distance 0 < radius),
    // exercising the MarkerClusterLayer cluster builder.
    final a = _site(id: 'site-a', name: 'A');
    final b = _site(id: 'site-b', name: 'B');
    await _pump(
      tester,
      dives: AsyncValue.data([
        _diveAtSite(a, id: 'dive-a'),
        _diveAtSite(b, id: 'dive-b'),
      ]),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('opens on the Pacific for dives on both sides of 180 (#2516)', (
    tester,
  ) async {
    // Queensland, Fiji and Tahiti. A plain bounding box of these centres on
    // 15E (Africa) and splits the dives across the map's two edges.
    final sites = [
      _site(id: 'qld', name: 'Queensland', lat: -16.9, lng: 150.0),
      _site(id: 'fiji', name: 'Fiji', lat: -17.7, lng: 178.0),
      _site(id: 'tahiti', name: 'Tahiti', lat: -17.5, lng: -149.0),
    ];
    await _pump(
      tester,
      dives: AsyncValue.data([
        for (final site in sites) _diveAtSite(site, id: 'dive-${site.id}'),
      ]),
    );

    final camera = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera;
    // The span runs 150E to 149W, so its middle is 180.5E (179.5W).
    expect(camera.center.longitude, closeTo(-179.5, 2.0));

    // Queensland sits in the copy of the world west of the date line; it is
    // on screen only because the cluster layer repeats across the seam.
    for (final site in sites) {
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Select dive site ${site.name}',
        ),
        findsOneWidget,
        reason: site.name,
      );
    }
  });

  group('camera moves', () {
    testWidgets('eases to a dive selected from outside the map', (
      tester,
    ) async {
      final selection = ValueNotifier<String?>(null);
      addTearDown(selection.dispose);
      await _pump(
        tester,
        dives: AsyncValue.data([
          _diveAtSite(_reefA, id: 'dive-a'),
          _diveAtSite(_farReef, id: 'dive-far'),
        ]),
        selection: selection,
      );
      // Opens framed on both sites, wider than the zoom a selection eases to.
      expect(_camera(tester).zoom, lessThan(10));

      selection.value = 'dive-far';
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final camera = _camera(tester);
      expect(camera.center.latitude, closeTo(-20.0, 1e-6));
      expect(camera.center.longitude, closeTo(98.0, 1e-6));
      expect(camera.zoom, closeTo(12.0, 1e-6));
    });

    testWidgets('fit-all button frames every site again', (tester) async {
      await _pump(
        tester,
        dives: AsyncValue.data([
          _diveAtSite(_reefA, id: 'dive-a'),
          _diveAtSite(_farReef, id: 'dive-far'),
        ]),
      );
      final opening = _camera(tester);

      tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .move(const LatLng(45.0, -30.0), 7.0);
      await tester.pump();
      expect(_camera(tester).center.latitude, closeTo(45.0, 1e-6));

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();

      // Back to the framing the map opened with, which shows both sites.
      final fitted = _camera(tester);
      expect(fitted.center.latitude, closeTo(opening.center.latitude, 1e-6));
      expect(fitted.center.longitude, closeTo(opening.center.longitude, 1e-6));
      expect(fitted.zoom, closeTo(opening.zoom, 1e-6));
      for (final site in [_reefA, _farReef]) {
        final point = LatLng(site.location!.latitude, site.location!.longitude);
        expect(fitted.visibleBounds.contains(point), isTrue, reason: site.name);
      }
    });

    testWidgets('tapping a cluster eases in on its sites', (tester) async {
      await _pump(
        tester,
        dives: AsyncValue.data([
          _diveAtSite(_reefA, id: 'dive-a'),
          _diveAtSite(_reefB, id: 'dive-b'),
          _diveAtSite(_farReef, id: 'dive-far'),
        ]),
      );
      // Reef A and Reef B share one cluster marker counting their two dives.
      expect(_siteMarker('Reef A'), findsNothing);

      await tester.tap(find.text('2').hitTestable().first);
      // Past flutter_map's double-tap window, then through the ease.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));

      // The cluster's bounds are small enough that the fit stops at the
      // animator's maxZoom, centred between the two sites.
      final camera = _camera(tester);
      expect(camera.center.latitude, closeTo(12.345, 1e-3));
      expect(camera.center.longitude, closeTo(98.765, 1e-3));
      expect(camera.zoom, closeTo(14.0, 1e-6));
    });

    testWidgets('tapping a site marker selects its dive and eases to it', (
      tester,
    ) async {
      String? selected;
      await _pump(
        tester,
        dives: AsyncValue.data([
          _diveAtSite(_reefA, id: 'dive-a'),
          _diveAtSite(_farReef, id: 'dive-far'),
        ]),
        onItemSelected: (id) => selected = id,
      );

      await tester.tap(_siteMarker('Far Reef'));
      // Past flutter_map's double-tap window, then through the ease.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));

      expect(selected, 'dive-far');
      final camera = _camera(tester);
      expect(camera.center.latitude, closeTo(-20.0, 1e-6));
      expect(camera.center.longitude, closeTo(98.0, 1e-6));
      expect(camera.zoom, closeTo(12.0, 1e-6));
    });
  });
}
