import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_map_content.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  required List<SiteWithDiveCount> sites,
  String? selectedId,
  AppSettings? settings,
  BathymetryGrid? grid,
}) async {
  final base = await getBaseOverrides(
    settingsNotifier: settings == null ? null : MockSettingsNotifier(settings),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        sitesWithCountsProvider.overrideWith((ref) async => sites),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
        bathymetryGridProvider.overrideWith((ref, cell) async => grid),
        // Entering 3D must not fire the real seascape pipeline: park the
        // pane on a terminal state.
        siteSeascapeProvider.overrideWith(
          (ref, id) async => const SiteSeascapeNoData(),
        ),
      ],
      child: MaterialApp(
        // Pinned: the morph test finds the terrain button by its English
        // tooltip.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SiteMapContent(selectedId: selectedId, onItemSelected: (_) {}),
        ),
      ),
    ),
  );
  // Allow the FutureProviders to resolve and the map to build.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('renders the FlutterMap with a dive site marker', (tester) async {
    await _pump(
      tester,
      sites: [SiteWithDiveCount(site: _site(), diveCount: 3)],
    );

    expect(find.byType(FlutterMap), findsOneWidget);
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

  testWidgets('renders the FlutterMap and info card for a selected site', (
    tester,
  ) async {
    await _pump(
      tester,
      sites: [SiteWithDiveCount(site: _site(), diveCount: 3)],
      selectedId: 'site-1',
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets('depth overlay drapes the selected site when toggled on', (
    tester,
  ) async {
    final grid = BathymetryGrid(
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
    await _pump(
      tester,
      sites: [SiteWithDiveCount(site: _site(), diveCount: 3)],
      selectedId: 'site-1',
      settings: const AppSettings(
        seascapeAppearance: SeascapeAppearance(mapDepthOverlay: true),
      ),
      grid: grid,
    );
    // The overlay renders through real engine async (PictureRecorder +
    // PNG encode), which fake test time never runs: give it a runAsync
    // window, then pump the resulting frame.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.byType(OverlayImageLayer), findsOneWidget);
  });

  testWidgets('depth overlay stays away when the flag is off', (tester) async {
    await _pump(
      tester,
      sites: [SiteWithDiveCount(site: _site(), diveCount: 3)],
      selectedId: 'site-1',
    );
    expect(find.byType(OverlayImageLayer), findsNothing);
  });

  testWidgets('depth overlay needs a selection', (tester) async {
    await _pump(
      tester,
      sites: [SiteWithDiveCount(site: _site(), diveCount: 3)],
      settings: const AppSettings(
        seascapeAppearance: SeascapeAppearance(mapDepthOverlay: true),
      ),
    );
    expect(find.byType(OverlayImageLayer), findsNothing);
  });

  testWidgets('info card terrain button morphs the pane to 3D in place', (
    tester,
  ) async {
    final grid = BathymetryGrid(
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
    await _pump(
      tester,
      sites: [SiteWithDiveCount(site: _site(), diveCount: 3)],
      selectedId: 'site-1',
      grid: grid,
    );
    expect(find.byType(SiteTerrainPane), findsNothing);
    // The info card's terrain button (tooltip disambiguates it from the
    // docked toggle, which also uses Icons.terrain).
    await tester.tap(find.byTooltip('Site Seascape'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // No route push: the pane replaced the map inside the same widget.
    expect(find.byType(SiteTerrainPane), findsOneWidget);
    expect(find.byKey(const ValueKey('siteScape2dButton')), findsOneWidget);
    // Back via the docked toggle.
    await tester.tap(find.byKey(const ValueKey('siteScape2dButton')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SiteTerrainPane), findsNothing);
  });

  testWidgets('renders a cluster marker for co-located sites', (tester) async {
    // Two sites at the SAME location reliably cluster (distance 0 < radius),
    // exercising the MarkerClusterLayer cluster builder.
    await _pump(
      tester,
      sites: [
        SiteWithDiveCount(
          site: _site(id: 's-a', name: 'A'),
          diveCount: 1,
        ),
        SiteWithDiveCount(
          site: _site(id: 's-b', name: 'B'),
          diveCount: 2,
        ),
      ],
    );

    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
