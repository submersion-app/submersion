import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/dead_reckoning_service.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/pages/spatial_site_page.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

ReckonedPath reckoned() {
  const n = 30;
  return const DeadReckoningService().reckon(
    times: [for (var i = 0; i < n; i++) (i * 20).toDouble()],
    depths: [for (var i = 0; i < n; i++) (i < 15 ? i * 2.0 : (30 - i) * 2.0)],
    headings: [for (var i = 0; i < n; i++) (i * 6).toDouble()],
    swimSpeedMps: 0.4,
  );
}

void main() {
  testWidgets('renders the seascape and the honesty captions', (tester) async {
    final overrides = await getBaseOverrides();
    final path = reckoned();
    final scene = const SpatialGeometryService().build(path, siteMaxDepth: 30);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          spatialReckonedPathProvider('d1').overrideWith((ref) async => path),
          spatialGeometryProvider(
            'd1',
          ).overrideWith((ref) async => SpatialSceneResult(scene: scene)),
        ],
        child: const SpatialSitePage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Dive3dInteractiveViewport), findsOneWidget);
    // The reconstruction captions are always shown.
    expect(find.text('Synthesized seafloor'), findsOneWidget);
    expect(find.text('Estimated path (dead reckoning)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('real-terrain scene shows chips and legend, contours on', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final path = reckoned();
    // Sloping 5 -> 45 m grid: contours and a labeled 25 m major exist.
    final grid = BathymetryGrid(
      originLat: 0,
      originLon: 0,
      cellSizeLatDeg: 100.0 / 110540.0,
      cellSizeLonDeg: 100.0 / 111320.0,
      rows: 3,
      cols: 3,
      depthsMeters: const [5, 5, 5, 25, 25, 25, 45, 45, 45],
      sourceId: 'gmrt',
      resolutionMeters: 61,
      fetchedAt: DateTime.utc(2026, 8, 15),
    );
    final built = const SpatialGeometryService().buildWithFrame(
      path,
      grid: grid,
      gridCenter: const GeoPoint(0, 0),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          spatialReckonedPathProvider('d1').overrideWith((ref) async => path),
          spatialGeometryProvider('d1').overrideWith(
            (ref) async => SpatialSceneResult(
              scene: built.scene,
              bathymetrySourceId: 'gmrt',
              bathymetryResolutionMeters: 61,
              axisInputs: built.frame,
              grid: grid,
              contourLabels: built.contourLabels,
            ),
          ),
        ],
        child: const SpatialSitePage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    expect(viewport.visibleOverlays, contains(SceneOverlay.contours));
    expect(viewport.visibleOverlays, contains(SceneOverlay.water));
    expect(viewport.chartMode, isFalse);
    expect(viewport.contourLabels, isNotEmpty);
    expect(find.text('Contours'), findsOneWidget);
    expect(find.text('Steep walls'), findsOneWidget);
    expect(find.byKey(const ValueKey('seascapeDepthLegend')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('seascapeAppearanceButton')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('synthesized scene hides chips and legend', (tester) async {
    final overrides = await getBaseOverrides();
    final path = reckoned();
    final scene = const SpatialGeometryService().build(path, siteMaxDepth: 30);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          spatialReckonedPathProvider('d1').overrideWith((ref) async => path),
          spatialGeometryProvider(
            'd1',
          ).overrideWith((ref) async => SpatialSceneResult(scene: scene)),
        ],
        child: const SpatialSitePage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Contours'), findsNothing);
    expect(find.byKey(const ValueKey('seascapeDepthLegend')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows a message when the path cannot be reconstructed', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          spatialReckonedPathProvider('d1').overrideWith((ref) async => null),
          spatialGeometryProvider('d1').overrideWith((ref) async => null),
        ],
        child: const SpatialSitePage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('Not enough data to reconstruct the dive path'),
      findsOneWidget,
    );
  });
}
