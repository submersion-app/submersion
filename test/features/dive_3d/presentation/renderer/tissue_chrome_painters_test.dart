import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

void main() {
  final result = SubsurfaceTissueBuilder.buildResult(
    BuhlmannAlgorithm().processProfile(
      depths: const [0, 30, 30, 30, 0],
      timestamps: const [0, 120, 600, 1200, 1400],
    ),
    colorFn: thermalColor,
  );
  const style = TissueChromeStyle(
    axisX: Colors.amber,
    axisY: Colors.green,
    axisZ: Colors.blue,
    grid: Colors.white24,
    wireframe: Colors.white24,
    marker: Colors.white,
    markerOutline: Colors.black,
    label: Colors.white,
  );

  final axisLabels = buildTissueAxisLabels(
    bounds: result.scene.bounds,
    grid: result.grid,
    referenceY: SubsurfaceTissueBuilder.referenceHeight,
    timeTitle: 'Time',
    saturationTitle: 'Saturation %',
    compartmentTitle: 'Compartment',
    runtimeSeconds: 1400,
  );

  void paint(CustomPainter painter) {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(400, 300));
    recorder.endRecording();
  }

  test('frame painter paints without throwing', () {
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    expect(
      () => paint(
        TissueFramePainter(
          bounds: result.scene.bounds,
          frame: frame,
          style: style,
          yawDegrees: -32,
          pitchDegrees: 22,
          zoom: 1,
        ),
      ),
      returnsNormally,
    );
  });

  test('static chrome painter paints without throwing', () {
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    final painter = TissueChromePainter(
      scene: result.scene,
      grid: result.grid,
      frame: frame,
      style: style,
      yawDegrees: -32,
      pitchDegrees: 22,
      zoom: 1,
      labels: axisLabels,
    );
    expect(() => paint(painter), returnsNormally);
  });

  test(
    'overlay painter paints (with a hover pick + scrub) without throwing',
    () {
      final pick = ValueNotifier<TissuePick?>(
        const TissuePick(col: 1, comp: 3, screenPos: Offset(200, 150)),
      );
      final painter = TissueOverlayPainter(
        scene: result.scene,
        grid: result.grid,
        style: style,
        yawDegrees: -32,
        pitchDegrees: 22,
        zoom: 1,
        scrubPosition: ValueNotifier<double>(0.5),
        hoverPick: pick,
      );
      expect(() => paint(painter), returnsNormally);
    },
  );

  // One shared frame so shouldRepaint's identical(frame) check isn't tripped by
  // rebuilding a fresh AxisFrame on every call.
  final sharedFrame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
  TissueChromePainter chrome({
    double yaw = -32,
    TissueChromeStyle chromeStyle = style,
  }) => TissueChromePainter(
    scene: result.scene,
    grid: result.grid,
    frame: sharedFrame,
    style: chromeStyle,
    yawDegrees: yaw,
    pitchDegrees: 22,
    zoom: 1,
    labels: axisLabels,
  );

  const otherStyle = TissueChromeStyle(
    axisX: Colors.red, // differs from `style`
    axisY: Colors.green,
    axisZ: Colors.blue,
    grid: Colors.white24,
    wireframe: Colors.white24,
    marker: Colors.white,
    markerOutline: Colors.black,
    label: Colors.white,
  );

  test('static chrome painter repaints when the camera changes', () {
    expect(chrome(yaw: -32).shouldRepaint(chrome(yaw: 10)), isTrue);
  });

  test('static chrome painter repaints when the style (theme) changes', () {
    expect(chrome().shouldRepaint(chrome()), isFalse);
    expect(chrome().shouldRepaint(chrome(chromeStyle: otherStyle)), isTrue);
  });

  test('static chrome painter is independent of scrub/hover (identical camera '
      'and style never repaints -- proves it stays put during playback)', () {
    // The static painter has no scrub/hover fields at all, so two instances at
    // the same camera/style are interchangeable regardless of cursor motion.
    expect(chrome().shouldRepaint(chrome()), isFalse);
  });

  test('overlay painter repaints on camera and style changes', () {
    final scrub = ValueNotifier<double>(0);
    final pick = ValueNotifier<TissuePick?>(null);
    TissueOverlayPainter make({
      double yaw = -32,
      TissueChromeStyle s = style,
    }) => TissueOverlayPainter(
      scene: result.scene,
      grid: result.grid,
      style: s,
      yawDegrees: yaw,
      pitchDegrees: 22,
      zoom: 1,
      scrubPosition: scrub,
      hoverPick: pick,
    );
    expect(make().shouldRepaint(make()), isFalse);
    expect(make().shouldRepaint(make(yaw: 10)), isTrue);
    expect(make().shouldRepaint(make(s: otherStyle)), isTrue);
  });

  test('frame painter repaints when the style (theme) changes', () {
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    TissueFramePainter make(Color grid) => TissueFramePainter(
      bounds: result.scene.bounds,
      frame: frame,
      style: TissueChromeStyle(
        axisX: Colors.amber,
        axisY: Colors.green,
        axisZ: Colors.blue,
        grid: grid,
        wireframe: Colors.white24,
        marker: Colors.white,
        markerOutline: Colors.black,
        label: Colors.white,
      ),
      yawDegrees: -32,
      pitchDegrees: 22,
      zoom: 1,
    );
    expect(make(Colors.white24).shouldRepaint(make(Colors.white24)), isFalse);
    expect(make(Colors.white24).shouldRepaint(make(Colors.white70)), isTrue);
  });
}
