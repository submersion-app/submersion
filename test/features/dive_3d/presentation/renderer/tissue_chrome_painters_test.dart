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

  test('chrome painter paints (with a hover pick) without throwing', () {
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    final pick = ValueNotifier<TissuePick?>(
      const TissuePick(col: 1, comp: 3, screenPos: Offset(200, 150)),
    );
    final painter = TissueChromePainter(
      scene: result.scene,
      grid: result.grid,
      frame: frame,
      style: style,
      yawDegrees: -32,
      pitchDegrees: 22,
      zoom: 1,
      scrubPosition: ValueNotifier<double>(0.5),
      hoverPick: pick,
      labels: axisLabels,
    );
    expect(() => paint(painter), returnsNormally);
  });

  test('chrome painter repaints when the camera changes', () {
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    TissueChromePainter make(double yaw) => TissueChromePainter(
      scene: result.scene,
      grid: result.grid,
      frame: frame,
      style: style,
      yawDegrees: yaw,
      pitchDegrees: 22,
      zoom: 1,
      scrubPosition: ValueNotifier<double>(0),
      hoverPick: ValueNotifier<TissuePick?>(null),
    );
    expect(make(-32).shouldRepaint(make(10)), isTrue);
  });

  test('chrome painter repaints when the style (theme) changes', () {
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    final scrub = ValueNotifier<double>(0);
    final pick = ValueNotifier<TissuePick?>(null);
    TissueChromePainter make(TissueChromeStyle s) => TissueChromePainter(
      scene: result.scene,
      grid: result.grid,
      frame: frame,
      style: s,
      yawDegrees: -32,
      pitchDegrees: 22,
      zoom: 1,
      scrubPosition: scrub,
      hoverPick: pick,
    );
    const other = TissueChromeStyle(
      axisX: Colors.red, // differs from `style`
      axisY: Colors.green,
      axisZ: Colors.blue,
      grid: Colors.white24,
      wireframe: Colors.white24,
      marker: Colors.white,
      markerOutline: Colors.black,
      label: Colors.white,
    );
    expect(make(style).shouldRepaint(make(style)), isFalse);
    expect(make(style).shouldRepaint(make(other)), isTrue);
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
