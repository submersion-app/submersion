import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

Scene3d buildScene() {
  final data = Dive3dSceneData(
    diveId: 'd1',
    times: const [0, 60, 120],
    depths: const [0, 18, 0],
    temperatures: const [20, 15, 20],
    ascentRates: const [null, null, null],
    ppO2s: const [null, null, null],
    cnss: const [null, null, null],
    heartRates: const [null, null, null],
    ceilings: const [null, null, null],
    ttss: const [null, null, null],
    tankPressures: const {},
    gasSwitches: [
      GasSwitchWithTank(
        gasSwitch: GasSwitch(
          id: 'gs1',
          diveId: 'd1',
          timestamp: 60,
          tankId: 't1',
          createdAt: DateTime.utc(2026),
        ),
        tankName: 'EAN50',
        gasMix: 'EAN50',
        o2Fraction: 0.5,
      ),
    ],
    bookmarkEvents: const [],
    photos: const [],
    durationSeconds: 120,
    maxDepthMeters: 18,
  );
  return const SceneGeometryService().build(data, SceneMetric.depth);
}

Dive3dScenePainter scenePainterOf(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byType(Dive3dInteractiveViewport),
      matching: find.byType(CustomPaint),
    ),
  );
  return paints.map((p) => p.painter).whereType<Dive3dScenePainter>().single;
}

void main() {
  Future<void> pumpViewport(
    WidgetTester tester, {
    required Scene3d scene,
    ValueListenable<double>? scrub,
    void Function(SceneMarker)? onMarkerTap,
    ScrubCursorStyle scrubCursor = ScrubCursorStyle.dot,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Dive3dInteractiveViewport(
            scene: scene,
            scrubPosition: scrub ?? ValueNotifier(0.0),
            visibleOverlays: SceneOverlay.values.toSet(),
            onMarkerTap: onMarkerTap,
            scrubCursor: scrubCursor,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the scene painter with the default camera', (
    tester,
  ) async {
    await pumpViewport(tester, scene: buildScene());
    final painter = scenePainterOf(tester);
    expect(painter.yawDegrees, -32);
    expect(painter.pitchDegrees, 22);
    expect(painter.zoom, 1.0);
  });

  testWidgets('drag orbits the camera and double tap resets it', (
    tester,
  ) async {
    await pumpViewport(tester, scene: buildScene());
    await tester.drag(
      find.byType(Dive3dInteractiveViewport),
      const Offset(50, -25),
    );
    await tester.pump();
    final orbited = scenePainterOf(tester);
    expect(orbited.yawDegrees, lessThan(-32)); // dragged right -> yaw down
    expect(orbited.pitchDegrees, lessThan(22));

    await tester.tap(find.byType(Dive3dInteractiveViewport));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byType(Dive3dInteractiveViewport));
    await tester.pump(const Duration(milliseconds: 400));
    final reset = scenePainterOf(tester);
    expect(reset.yawDegrees, -32);
    expect(reset.pitchDegrees, 22);
  });

  testWidgets('tapping a marker position fires onMarkerTap', (tester) async {
    final scene = buildScene();
    SceneMarker? tapped;
    await pumpViewport(tester, scene: scene, onMarkerTap: (m) => tapped = m);

    final size = tester.getSize(find.byType(Dive3dInteractiveViewport));
    final projector = SceneProjector(size: size, bounds: scene.bounds);
    final marker = scene.markers.single;
    final screen = projector.project(marker.x, marker.y, 0);
    final origin = tester.getTopLeft(find.byType(Dive3dInteractiveViewport));

    await tester.tapAt(origin + screen);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tapped, isNotNull);
    expect(tapped!.refId, 'gs1');
  });

  testWidgets('scrub cursor foreground painter repaints on scrub', (
    tester,
  ) async {
    final scrub = ValueNotifier<double>(0.0);
    await pumpViewport(tester, scene: buildScene(), scrub: scrub);
    scrub.value = 0.5;
    await tester.pump();
    final paints = tester.widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(Dive3dInteractiveViewport),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(paints.any((p) => p.foregroundPainter != null), isTrue);
  });

  testWidgets('time-plane cursor style renders without error', (tester) async {
    await pumpViewport(
      tester,
      scene: buildScene(),
      scrubCursor: ScrubCursorStyle.timePlane,
    );
    final paints = tester.widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(Dive3dInteractiveViewport),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(paints.any((p) => p.foregroundPainter != null), isTrue);
  });
}
