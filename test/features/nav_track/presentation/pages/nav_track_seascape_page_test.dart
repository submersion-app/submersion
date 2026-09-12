import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/dead_reckoning_service.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/features/nav_track/application/nav_track_scene_providers.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_seascape_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

ReckonedPath _reckoned() {
  const n = 10;
  return const DeadReckoningService().reckon(
    times: [for (var i = 0; i < n; i++) (i * 20).toDouble()],
    depths: [for (var i = 0; i < n; i++) (i * 1.5)],
    headings: [for (var i = 0; i < n; i++) (i * 6).toDouble()],
    swimSpeedMps: 0.4,
  );
}

void main() {
  testWidgets('shows a loading indicator while the scene resolves', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final completer = Completer<void>();
    addTearDown(() {
      if (!completer.isCompleted) completer.complete();
    });
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          // Never completes during the test: pump once without settling to
          // observe the loading state.
          navTrackSceneProvider('t1').overrideWith((ref) async {
            await completer.future;
            return null;
          }),
        ],
        child: const NavTrackSeascapePage(trackId: 't1'),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows the no-scene message when the route has no scene', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          navTrackSceneProvider('t1').overrideWith((ref) async => null),
        ],
        child: const NavTrackSeascapePage(trackId: 't1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This route has no usable seascape.'), findsOneWidget);
    expect(find.byType(Dive3dInteractiveViewport), findsNothing);
  });

  testWidgets('shows the no-scene message when the scene has no layers', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final path = _reckoned();
    final scene = const SpatialGeometryService().build(path, siteMaxDepth: 15);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          navTrackSceneProvider('t1').overrideWith(
            (ref) async => SpatialSceneResult(
              scene: Scene3d(
                layers: const [],
                markers: scene.markers,
                bounds: scene.bounds,
              ),
            ),
          ),
        ],
        child: const NavTrackSeascapePage(trackId: 't1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This route has no usable seascape.'), findsOneWidget);
  });

  testWidgets('renders the 3D viewport and scrub bar for a populated scene', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final path = _reckoned();
    final scene = const SpatialGeometryService().build(path, siteMaxDepth: 15);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          navTrackSceneProvider(
            't1',
          ).overrideWith((ref) async => SpatialSceneResult(scene: scene)),
        ],
        child: const NavTrackSeascapePage(trackId: 't1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dive3dInteractiveViewport), findsOneWidget);
    expect(find.byType(TimeScrubBar), findsOneWidget);
    expect(find.text('Route seascape'), findsOneWidget);

    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    expect(viewport.scene, scene);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
