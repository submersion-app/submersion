import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/features/bathymetry/data/terrain_imagery_service.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/terrain_imagery_frame.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.initial = const AppSettings()]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<TerrainImagery> testImagery() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  final image = await recorder.endRecording().toImage(4, 4);
  return TerrainImagery(
    image: image,
    frame: const TerrainImageryFrame(
      u0MercX: 0.4,
      u1MercX: 0.6,
      v0MercY: 0.4,
      v1MercY: 0.6,
      whiteU: 0.5,
      whiteV: 0.9,
    ),
  );
}

SiteSeascapeReady readyState({TerrainImagery? imagery}) {
  final grid = BathymetryGrid(
    originLat: 12.15,
    originLon: -68.30,
    cellSizeLatDeg: 0.001,
    cellSizeLonDeg: 0.001,
    rows: 2,
    cols: 2,
    depthsMeters: const [20, 30, 25, 35],
    sourceId: 'gmrt',
    resolutionMeters: 61,
    fetchedAt: DateTime.utc(2026, 7, 28),
  );
  final scene = const SiteSeascapeGeometryService().build(
    SiteSeascapeInput(
      grid: grid,
      center: const GeoPoint(12.151, -68.299),
      siteName: 'Salt Pier',
      siteMaxDepth: 30,
      divePaths: const [],
      nearbySites: const [],
    ),
  );
  final box = BathymetryTerrainBuilder.enuBounds(
    grid,
    const GeoPoint(12.151, -68.299),
  );
  return SiteSeascapeReady(
    scene: scene,
    sourceId: 'gmrt',
    resolutionMeters: 61,
    grid: grid,
    imagery: imagery,
    axisInputs: (
      minEast: box.minEast,
      maxEast: box.maxEast,
      minNorth: box.minNorth,
      maxNorth: box.maxNorth,
      maxDepth: 35,
    ),
  );
}

Widget page(
  SiteSeascapeState state, {
  AppSettings settings = const AppSettings(),
  List<SiteFeature> features = const [],
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
    siteSeascapeProvider.overrideWith((ref, id) async => state),
    siteFeaturesProvider('site-1').overrideWith((ref) async => features),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SiteTerrainPane(siteId: 'site-1')),
  ),
);

void main() {
  testWidgets('ready state renders viewport and provenance caption', (
    tester,
  ) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump(); // resolve the future
    await tester.pump();
    expect(find.byType(Dive3dInteractiveViewport), findsOneWidget);
    expect(find.textContaining('GMRT'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Distance/depth axes are always-on chrome.
    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    expect(viewport.axisFrame, isNotNull);
    expect(viewport.axisLabels, isNotNull);
    expect(viewport.chromeStyle, isNotNull);
    // Hover inspection: pick lattice + notifier wired, tissue chrome not.
    expect(viewport.picker, isA<GridHoverPicker>());
    expect(viewport.hoverPick, isNotNull);
    expect(viewport.chromeMode, SceneChromeMode.axesOnly);
  });

  testWidgets('contours default on, chip toggles them off', (tester) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump();
    await tester.pump();
    Dive3dInteractiveViewport viewport() =>
        tester.widget<Dive3dInteractiveViewport>(
          find.byType(Dive3dInteractiveViewport),
        );
    expect(viewport().visibleOverlays, contains(SceneOverlay.contours));
    expect(viewport().visibleOverlays, contains(SceneOverlay.water));
    expect(viewport().chartMode, isFalse);
    await tester.tap(find.text('Contours'));
    await tester.pump();
    expect(viewport().visibleOverlays, isNot(contains(SceneOverlay.contours)));
    // Walls chip exists and defaults off.
    expect(find.text('Steep walls'), findsOneWidget);
    expect(
      viewport().visibleOverlays,
      isNot(contains(SceneOverlay.steepWalls)),
    );
  });

  testWidgets('chart toggle enters chart mode and hides the water plane', (
    tester,
  ) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('seascapeChartToggle')));
    await tester.pump();
    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    expect(viewport.chartMode, isTrue);
    expect(viewport.visibleOverlays, isNot(contains(SceneOverlay.water)));
  });

  testWidgets('legend renders on the ready state', (tester) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('seascapeDepthLegend')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('seascapeAppearanceButton')),
      findsOneWidget,
    );
  });

  // Issue #1188: on a phone-sized pane the legend and the viewport's zoom
  // column both hugged the right edge, and the legend covered the +/-
  // buttons outright.
  testWidgets('the legend never overlaps the zoom controls', (tester) async {
    for (final surface in const [Size(360, 640), Size(360, 380)]) {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(page(readyState()));
      await tester.pump();
      await tester.pump();
      final legend = tester.getRect(
        find.byKey(const ValueKey('seascapeDepthLegend')),
      );
      final zoom = tester.getRect(
        find.byKey(const ValueKey('dive3dZoomControls')),
      );
      expect(
        legend.overlaps(zoom),
        isFalse,
        reason: 'legend $legend overlaps zoom controls $zoom at $surface',
      );
    }
  });

  testWidgets('imagery reaches the viewport and shows attribution', (
    tester,
  ) async {
    final imagery = await testImagery();
    addTearDown(imagery.image.dispose);
    await tester.pumpWidget(
      page(
        readyState(imagery: imagery),
        settings: const AppSettings(
          mapStyle: MapStyle.esriSatellite,
          seascapeAppearance: SeascapeAppearance(
            surfaceMode: SeascapeSurfaceMode.imagery,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    expect(viewport.terrainImagery, isNotNull);
    expect(viewport.imageryWhiteTexel, (u: 0.5, v: 0.9));
    // Esri attribution rides the chrome; the legend hides in imagery mode.
    expect(find.textContaining('Esri'), findsOneWidget);
    expect(find.byKey(const ValueKey('seascapeDepthLegend')), findsNothing);
  });

  testWidgets('depth mode keeps the legend and skips attribution', (
    tester,
  ) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('seascapeDepthLegend')), findsOneWidget);
    expect(find.textContaining('Esri'), findsNothing);
  });

  testWidgets('the Features chip is on by default and toggles the overlay', (
    tester,
  ) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump();
    await tester.pump();
    Dive3dInteractiveViewport viewport() =>
        tester.widget<Dive3dInteractiveViewport>(
          find.byType(Dive3dInteractiveViewport),
        );
    expect(viewport().visibleOverlays, contains(SceneOverlay.features));
    await tester.tap(find.text('Features'));
    await tester.pump();
    expect(viewport().visibleOverlays, isNot(contains(SceneOverlay.features)));
  });

  testWidgets('tapping a feature marker shows a read-only info sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        readyState(),
        features: const [
          SiteFeature(
            id: 'f-1',
            siteId: 'site-1',
            typeName: 'wreck',
            name: 'Hilma Hooker',
            latitude: 12.151,
            longitude: -68.299,
            depthMeters: 30,
            bearingDeg: 135,
            notes: 'Bow points north',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    // Drive the viewport's marker callback the way a 24px hit test would.
    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    viewport.onMarkerTap!(
      const SceneMarker(
        kind: SceneMarkerKind.siteFeature,
        refId: 'f-1',
        label: 'Hilma Hooker',
        x: 0,
        y: 0,
        timestampSeconds: 0,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Hilma Hooker'), findsOneWidget);
    expect(find.text('Wreck'), findsWidgets);
    expect(find.textContaining('30.0'), findsOneWidget);
    expect(find.textContaining('135'), findsOneWidget);
    expect(find.text('Bow points north'), findsOneWidget);
    // Read-only: no save or delete affordance in 3D.
    expect(find.byKey(const ValueKey('siteFeatureSaveButton')), findsNothing);
  });

  testWidgets('an unnamed feature falls back to its type label in 3D', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        readyState(),
        features: const [
          SiteFeature(
            id: 'f-2',
            siteId: 'site-1',
            typeName: 'mooring',
            latitude: 12.151,
            longitude: -68.299,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    viewport.onMarkerTap!(
      const SceneMarker(
        kind: SceneMarkerKind.siteFeature,
        refId: 'f-2',
        label: '',
        x: 0,
        y: 0,
        timestampSeconds: 0,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Mooring'), findsWidgets);
  });

  testWidgets('non-feature markers and unknown ids open nothing', (
    tester,
  ) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump();
    await tester.pump();

    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    // The site pin is not a feature.
    viewport.onMarkerTap!(
      const SceneMarker(
        kind: SceneMarkerKind.site,
        refId: null,
        label: 'Salt Pier',
        x: 0,
        y: 0,
        timestampSeconds: 0,
      ),
    );
    // A feature id with no matching row (deleted mid-frame).
    viewport.onMarkerTap!(
      const SceneMarker(
        kind: SceneMarkerKind.siteFeature,
        refId: 'gone',
        label: 'gone',
        x: 0,
        y: 0,
        timestampSeconds: 0,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('no-coordinates state shows the message, not a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(page(const SiteSeascapeNoCoordinates()));
    await tester.pump();
    await tester.pump();
    expect(find.text('This site has no GPS coordinates'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no-data state shows the message, not a spinner', (tester) async {
    await tester.pumpWidget(page(const SiteSeascapeNoData()));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('No bathymetry available for this location'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
