import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/domain/geometry/dive_axes.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/camera_pose.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

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
    bool chartMode = false,
    AxisFrame? axisFrame,
    TissueChromeStyle? chromeStyle,
    SceneChromeMode chromeMode = SceneChromeMode.none,
    bool showPosePresets = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Dive3dInteractiveViewport(
            scene: scene,
            scrubPosition: scrub ?? ValueNotifier(0.0),
            visibleOverlays: SceneOverlay.values.toSet(),
            onMarkerTap: onMarkerTap,
            scrubCursor: scrubCursor,
            chartMode: chartMode,
            axisFrame: axisFrame,
            chromeStyle: chromeStyle,
            chromeMode: chromeMode,
            showPosePresets: showPosePresets,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('panning threads the offset into the chrome painter', (
    tester,
  ) async {
    const style = TissueChromeStyle(
      axisX: Color(0xFF000000),
      axisY: Color(0xFF000000),
      axisZ: Color(0xFF000000),
      grid: Color(0xFF000000),
      wireframe: Color(0x00000000),
      marker: Color(0xFF000000),
      markerOutline: Color(0xFFFFFFFF),
      label: Color(0xFF000000),
    );
    await pumpViewport(
      tester,
      scene: buildScene(),
      chartMode: true,
      chromeMode: SceneChromeMode.axesOnly,
      axisFrame: const AxisFrame([]),
      chromeStyle: style,
    );
    AxisChromePainter chrome() => tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(Dive3dInteractiveViewport),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((p) => p.foregroundPainter)
        .whereType<AxisChromePainter>()
        .single;
    expect(chrome().panOffset, Offset.zero);
    // Chart mode: a one-finger drag pans, and the chrome painter must know
    // the pan so fixed chrome (the compass) can cancel it.
    await tester.drag(
      find.byType(Dive3dInteractiveViewport),
      const Offset(60, 40),
    );
    await tester.pump();
    // Touch slop consumes the first stretch of the gesture, so assert the
    // pan moved substantially rather than by the raw drag distance.
    expect(chrome().panOffset.dx, greaterThan(20));
    expect(chrome().panOffset.dy, greaterThan(10));

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('chart mode pins the chart pose and pans instead of rotating', (
    tester,
  ) async {
    await pumpViewport(tester, scene: buildScene(), chartMode: true);
    var painter = scenePainterOf(tester);
    expect(painter.yawDegrees, chartYawDegrees);
    expect(painter.pitchDegrees, chartPitchDegrees);
    // A drag must NOT change yaw/pitch (it pans the plan view).
    await tester.drag(
      find.byType(Dive3dInteractiveViewport),
      const Offset(60, 40),
    );
    await tester.pump();
    painter = scenePainterOf(tester);
    expect(painter.yawDegrees, chartYawDegrees);
    expect(painter.pitchDegrees, chartPitchDegrees);

    // Let gesture-recognizer timers finish, then unmount so nothing is
    // pending at teardown.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

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
    expect(orbited.yawDegrees, greaterThan(-32)); // dragged right -> yaw up
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

  testWidgets('zoom buttons change zoom and reset restores it', (tester) async {
    await pumpViewport(tester, scene: buildScene());
    expect(scenePainterOf(tester).zoom, 1.0);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(scenePainterOf(tester).zoom, greaterThan(1.0));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(scenePainterOf(tester).zoom, lessThan(1.0));
    await tester.tap(find.byIcon(Icons.center_focus_strong));
    await tester.pump();
    expect(scenePainterOf(tester).zoom, 1.0);
  });

  // Issue #1188: on a touchscreen there are no pan/zoom pointers at all, so
  // the trackpad path below can never fire. Two fingers must pinch-zoom and
  // pan, while one finger keeps orbiting.
  testWidgets('two-finger pinch zooms about the focal point', (tester) async {
    await pumpViewport(tester, scene: buildScene());
    expect(scenePainterOf(tester).zoom, 1.0);
    final before = scenePainterOf(tester);
    final center = tester.getCenter(find.byType(Dive3dInteractiveViewport));

    final f1 = await tester.startGesture(center - const Offset(20, 0));
    final f2 = await tester.startGesture(center + const Offset(20, 0));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await f1.moveBy(const Offset(-15, 0));
      await f2.moveBy(const Offset(15, 0));
      await tester.pump();
    }

    final after = scenePainterOf(tester);
    expect(after.zoom, greaterThan(1.0));
    // A pinch must not double as a rotation.
    expect(after.yawDegrees, before.yawDegrees);
    expect(after.pitchDegrees, before.pitchDegrees);

    await f1.up();
    await f2.up();
    // Let the double-tap recognizer's countdown expire before teardown.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('two fingers moving together pan without rotating', (
    tester,
  ) async {
    await pumpViewport(tester, scene: buildScene());
    Offset panOffset() {
      final t = tester
          .widget<Transform>(find.byKey(const ValueKey('dive3dViewportPan')))
          .transform
          .getTranslation();
      return Offset(t.x, t.y);
    }

    final before = scenePainterOf(tester);
    final center = tester.getCenter(find.byType(Dive3dInteractiveViewport));
    final f1 = await tester.startGesture(center - const Offset(20, 0));
    final f2 = await tester.startGesture(center + const Offset(20, 0));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await f1.moveBy(const Offset(10, 6));
      await f2.moveBy(const Offset(10, 6));
      await tester.pump();
    }

    expect(panOffset().dx, greaterThan(0));
    expect(panOffset().dy, greaterThan(0));
    final after = scenePainterOf(tester);
    expect(after.yawDegrees, before.yawDegrees);
    expect(after.pitchDegrees, before.pitchDegrees);
    expect(after.zoom, closeTo(1.0, 0.05));

    await f1.up();
    await f2.up();
    // Let the double-tap recognizer's countdown expire before teardown.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('zoom controls carry a stable key for host layout checks', (
    tester,
  ) async {
    await pumpViewport(tester, scene: buildScene());
    expect(find.byKey(const ValueKey('dive3dZoomControls')), findsOneWidget);
  });

  testWidgets('trackpad pan translates the view and pinch zooms', (
    tester,
  ) async {
    await pumpViewport(tester, scene: buildScene());
    Offset panOffset() {
      final t = tester
          .widget<Transform>(find.byKey(const ValueKey('dive3dViewportPan')))
          .transform
          .getTranslation();
      return Offset(t.x, t.y);
    }

    expect(panOffset(), Offset.zero);
    final center = tester.getCenter(find.byType(Dive3dInteractiveViewport));
    final g = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await g.panZoomStart(center);
    await g.panZoomUpdate(center, pan: const Offset(40, 20), scale: 1.5);
    await tester.pump();
    expect(panOffset(), const Offset(40, 20)); // two-finger pan translated
    expect(scenePainterOf(tester).zoom, greaterThan(1.0)); // pinch zoomed
    await g.panZoomEnd();

    await tester.tap(find.byIcon(Icons.center_focus_strong));
    await tester.pump();
    expect(panOffset(), Offset.zero); // reset recenters
    expect(scenePainterOf(tester).zoom, 1.0);
  });

  testWidgets('hover over a surface vertex publishes a pick', (tester) async {
    const size = Size(400, 300);
    final result = SubsurfaceTissueBuilder.buildResult(
      BuhlmannAlgorithm().processProfile(
        depths: const [0, 30, 30, 30, 0],
        timestamps: const [0, 120, 600, 1200, 1400],
      ),
      colorFn: thermalColor,
    );
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    final hoverPick = ValueNotifier<ScenePick?>(null);
    const style = TissueChromeStyle(
      axisX: Color(0xFFFFB300),
      axisY: Color(0xFF66BB6A),
      axisZ: Color(0xFF42A5F5),
      grid: Color(0x33FFFFFF),
      wireframe: Color(0x33FFFFFF),
      marker: Color(0xFFFFFFFF),
      markerOutline: Color(0xFF000000),
      label: Color(0xFFFFFFFF),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: size,
              child: Dive3dInteractiveViewport(
                scene: result.scene,
                scrubPosition: ValueNotifier<double>(0),
                visibleOverlays: const {},
                chromeMode: SceneChromeMode.tissue,
                picker: GridHoverPicker(result.grid),
                surfaceGrid: result.grid,
                axisFrame: frame,
                chromeStyle: style,
                hoverPick: hoverPick,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Compute where vertex (col, comp) lands at the default camera, then hover.
    final projector = SceneProjector(size: size, bounds: result.scene.bounds);
    const col = 1, comp = 5;
    final (x, y, z) = result.grid.positionAt(col, comp);
    final origin = tester.getTopLeft(find.byType(Dive3dInteractiveViewport));
    final target = origin + projector.project(x, y, z);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(target);
    await tester.pump();

    expect(hoverPick.value, isNotNull);
    final tissue = hoverPick.value!.payload as TissuePick;
    expect(tissue.col, col);
    expect(tissue.comp, comp);
  });

  testWidgets('published pick screenPos tracks the vertex after panning', (
    tester,
  ) async {
    const size = Size(400, 300);
    final result = SubsurfaceTissueBuilder.buildResult(
      BuhlmannAlgorithm().processProfile(
        depths: const [0, 30, 30, 30, 0],
        timestamps: const [0, 120, 600, 1200, 1400],
      ),
      colorFn: thermalColor,
    );
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    final hoverPick = ValueNotifier<ScenePick?>(null);
    const style = TissueChromeStyle(
      axisX: Color(0xFFFFB300),
      axisY: Color(0xFF66BB6A),
      axisZ: Color(0xFF42A5F5),
      grid: Color(0x33FFFFFF),
      wireframe: Color(0x33FFFFFF),
      marker: Color(0xFFFFFFFF),
      markerOutline: Color(0xFF000000),
      label: Color(0xFFFFFFFF),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: size,
              child: Dive3dInteractiveViewport(
                scene: result.scene,
                scrubPosition: ValueNotifier<double>(0),
                visibleOverlays: const {},
                chromeMode: SceneChromeMode.tissue,
                picker: GridHoverPicker(result.grid),
                surfaceGrid: result.grid,
                axisFrame: frame,
                chromeStyle: style,
                hoverPick: hoverPick,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(Dive3dInteractiveViewport));
    // Pan the view with the trackpad.
    final center = tester.getCenter(find.byType(Dive3dInteractiveViewport));
    final pan = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await pan.panZoomStart(center);
    await pan.panZoomUpdate(center, pan: const Offset(30, 20));
    await tester.pump();
    await pan.panZoomEnd();

    // Read the viewport's actual camera so the check doesn't assume a zoom.
    final actualPan = tester
        .widget<Transform>(find.byKey(const ValueKey('dive3dViewportPan')))
        .transform
        .getTranslation();
    final panVec = Offset(actualPan.x, actualPan.y);
    final actualZoom = scenePainterOf(tester).zoom;

    // The vertex appears at project(...) + pan; hover that visual point.
    final projector = SceneProjector(
      size: size,
      bounds: result.scene.bounds,
      zoom: actualZoom,
    );
    const col = 1, comp = 5;
    final (x, y, z) = result.grid.positionAt(col, comp);
    final visualLocal = projector.project(x, y, z) + panVec;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(origin + visualLocal);
    await tester.pump();

    expect(hoverPick.value, isNotNull);
    final tissue = hoverPick.value!.payload as TissuePick;
    expect(tissue.col, col);
    expect(tissue.comp, comp);
    // screenPos is in viewport-local space, i.e. on the visual vertex, not the
    // untranslated projection (this is the pan-drift fix).
    expect((hoverPick.value!.screenPos - visualLocal).distance, lessThan(1.0));
    expect(panVec, isNot(Offset.zero)); // sanity: the pan actually applied
  });

  testWidgets('hover pick screenPos re-tracks the vertex after a zoom with no '
      'cursor move (tooltip stays on the marker ring)', (tester) async {
    const size = Size(400, 300);
    final result = SubsurfaceTissueBuilder.buildResult(
      BuhlmannAlgorithm().processProfile(
        depths: const [0, 30, 30, 30, 0],
        timestamps: const [0, 120, 600, 1200, 1400],
      ),
      colorFn: thermalColor,
    );
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    final hoverPick = ValueNotifier<ScenePick?>(null);
    const style = TissueChromeStyle(
      axisX: Color(0xFFFFB300),
      axisY: Color(0xFF66BB6A),
      axisZ: Color(0xFF42A5F5),
      grid: Color(0x33FFFFFF),
      wireframe: Color(0x33FFFFFF),
      marker: Color(0xFFFFFFFF),
      markerOutline: Color(0xFF000000),
      label: Color(0xFFFFFFFF),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: size,
              child: Dive3dInteractiveViewport(
                scene: result.scene,
                scrubPosition: ValueNotifier<double>(0),
                visibleOverlays: const {},
                chromeMode: SceneChromeMode.tissue,
                picker: GridHoverPicker(result.grid),
                surfaceGrid: result.grid,
                axisFrame: frame,
                chromeStyle: style,
                hoverPick: hoverPick,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Hover a vertex at the default camera to establish a pick.
    final origin = tester.getTopLeft(find.byType(Dive3dInteractiveViewport));
    final projDefault = SceneProjector(size: size, bounds: result.scene.bounds);
    const col = 1, comp = 5;
    final (x, y, z) = result.grid.positionAt(col, comp);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(origin + projDefault.project(x, y, z));
    await tester.pump();
    expect(hoverPick.value, isNotNull);
    final screenPosBefore = hoverPick.value!.screenPos;

    // Zoom in with the on-screen button; the mouse pointer does NOT move.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    final newZoom = scenePainterOf(tester).zoom;
    expect(newZoom, greaterThan(1.0)); // sanity: the zoom applied

    // The pick must now sit on the vertex's NEW projected position, matching
    // the re-projected marker ring - not the stale pre-zoom screenPos.
    final projZoomed = SceneProjector(
      size: size,
      bounds: result.scene.bounds,
      zoom: newZoom,
    );
    final expected = projZoomed.project(x, y, z); // pan is zero here
    final tissue = hoverPick.value!.payload as TissuePick;
    expect(tissue.col, col);
    expect(tissue.comp, comp);
    expect((hoverPick.value!.screenPos - expected).distance, lessThan(1.0));
    // And it genuinely moved (an off-center vertex re-projects under zoom).
    expect(
      (hoverPick.value!.screenPos - screenPosBefore).distance,
      greaterThan(1.0),
    );
  });

  testWidgets('framed mode paints the frame behind and axis chrome in front', (
    tester,
  ) async {
    final scene = buildScene();
    final axes = buildDiveAxes(
      bounds: scene.bounds,
      depthTicks: depthAxisTicks(
        maxDepthMeters: 18,
        stepMeters: 10,
        toDisplay: (m) => m,
      ),
      timeTicks: timeAxisTicks(120),
      depthTitle: 'Depth (m)',
      timeTitle: 'Run time (min)',
    );
    const style = TissueChromeStyle(
      axisX: Color(0xFFFFFFFF),
      axisY: Color(0xFFFFFFFF),
      axisZ: Color(0xFFFFFFFF),
      grid: Color(0x33FFFFFF),
      wireframe: Color(0x00000000),
      marker: Color(0xFFFFFFFF),
      markerOutline: Color(0xFF000000),
      label: Color(0xFFFFFFFF),
    );
    final hoverPick = ValueNotifier<ScenePick?>(null);
    addTearDown(hoverPick.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Dive3dInteractiveViewport(
            scene: scene,
            scrubPosition: ValueNotifier<double>(0),
            visibleOverlays: SceneOverlay.values.toSet(),
            chromeMode: SceneChromeMode.framed,
            axisFrame: axes.frame,
            axisLabels: axes.labels,
            chromeStyle: style,
            picker: PathHoverPicker(scene.scrubPath!),
            hoverPick: hoverPick,
          ),
        ),
      ),
    );
    await tester.pump();
    final paints = tester.widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(Dive3dInteractiveViewport),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      paints.map((p) => p.painter).whereType<TissueFramePainter>(),
      hasLength(1),
    );
    final chrome = paints
        .map((p) => p.foregroundPainter)
        .whereType<AxisChromePainter>()
        .single;
    expect(chrome.hoverGuides, isTrue);
    expect(chrome.showCompass, isFalse);
    expect(chrome.markerLabels, isNotNull);
    // Hovering the middle path sample publishes a PathPick.
    final viewportFinder = find.byType(Dive3dInteractiveViewport);
    final projector = SceneProjector(
      size: tester.getSize(viewportFinder),
      bounds: scene.bounds,
    );
    final path = scene.scrubPath!;
    final origin = tester.getTopLeft(viewportFinder);
    final target =
        origin + projector.project(path.xs[1], path.ys[1], path.zs![1]);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(target);
    await tester.pump();
    expect((hoverPick.value!.payload as PathPick).index, 1);
  });

  testWidgets('pose presets snap the camera and reset returns to default', (
    tester,
  ) async {
    await pumpViewport(tester, scene: buildScene(), showPosePresets: true);
    final menuFinder = find.byKey(const ValueKey('dive3dPoseMenu'));
    expect(menuFinder, findsOneWidget);
    // Drive the selection directly: the popup's placement on the small test
    // surface is Flutter's concern, the camera plumbing is ours.
    tester.widget<PopupMenuButton<CameraPose>>(menuFinder).onSelected!(
      CameraPose.side,
    );
    await tester.pump();
    var painter = scenePainterOf(tester);
    expect(painter.yawDegrees, CameraPose.side.yawDegrees);
    expect(painter.pitchDegrees, CameraPose.side.pitchDegrees);
    await tester.tap(find.byIcon(Icons.center_focus_strong));
    await tester.pump();
    painter = scenePainterOf(tester);
    expect(painter.yawDegrees, -32);
    expect(painter.pitchDegrees, 22);
  });
}
