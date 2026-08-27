import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/dive_axes.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';

Future<ui.Color> pixelAt(ui.Image image, Offset at) async {
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!;
  final i = ((at.dy.round() * image.width) + at.dx.round()) * 4;
  return ui.Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

// Guides paint at 70% alpha as 1 px anti-aliased lines over the black test
// background, so a dash pixel can carry as little as a third of the label
// color; on black, any pixel with red and blue but no green is magenta.
bool isMagenta(ui.Color c) => c.r > 0.2 && c.b > 0.2 && c.g < 0.15;

/// True when any pixel in the 3x3 neighborhood of [at] is magenta.
Future<bool> magentaNear(ui.Image image, Offset at) async {
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      final c = await pixelAt(image, at + Offset(dx.toDouble(), dy.toDouble()));
      if (isMagenta(c)) return true;
    }
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const size = Size(400, 300);
  const bounds = SceneBounds(
    durationSeconds: 100,
    maxDepthMeters: 20,
    sceneMinZ: -SceneBounds.zPathHalfSpan,
    sceneMaxZ: SceneBounds.zPathHalfSpan,
  );
  const style = TissueChromeStyle(
    axisX: Color(0xFFFFFFFF),
    axisY: Color(0xFFFFFFFF),
    axisZ: Color(0xFFFFFFFF),
    grid: Color(0xFF808080),
    wireframe: Color(0x00000000),
    marker: Color(0xFFFFFFFF),
    markerOutline: Color(0xFF000000),
    label: Color(0xFFFF00FF),
  );
  DiveAxes axes() => buildDiveAxes(
    bounds: bounds,
    depthTicks: depthAxisTicks(
      maxDepthMeters: 20,
      stepMeters: 10,
      toDisplay: (m) => m,
    ),
    timeTicks: timeAxisTicks(100),
    depthTitle: 'D',
    timeTitle: 'T',
  );

  test('hover guides and marker chips paint in framed mode', () async {
    final frame = axes();
    final pick = ValueNotifier<ScenePick?>(
      const ScenePick(
        x: 5,
        y: -3,
        z: 0,
        screenPos: Offset.zero,
        payload: PathPick(0),
      ),
    );
    const marker = SceneMarker(
      kind: SceneMarkerKind.gasSwitch,
      refId: 'g',
      label: 'EAN50',
      x: 2.5,
      y: -1,
      z: 0,
      timestampSeconds: 25,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF000000),
    );
    AxisChromePainter(
      bounds: bounds,
      frame: frame.frame,
      labels: frame.labels,
      style: style,
      yawDegrees: -32,
      pitchDegrees: 22,
      zoom: 1,
      hoverPick: pick,
      hoverGuides: true,
      showCompass: false,
      markerLabels: const [marker],
    ).paint(canvas, size);
    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    addTearDown(image.dispose);

    final p = SceneProjector(
      size: size,
      bounds: bounds,
      yawDegrees: -32,
      pitchDegrees: 22,
    );
    // Sample along the floor guide: dashes are label-colored.
    final from = p.project(5, -3, 0);
    final to = p.project(5, bounds.sceneMinY, 0);
    var guideHits = 0;
    for (var k = 1; k < 20; k++) {
      if (await magentaNear(image, from + (to - from) * (k / 20))) {
        guideHits++;
      }
    }
    // The chip sits 14 px above the marker anchor; its glyph boxes render in
    // the label color around its center.
    final chipCenter =
        p.project(marker.x, marker.y, marker.z) - const Offset(0, 14);
    var chipHits = 0;
    for (var dy = -4; dy <= 4; dy += 2) {
      for (var dx = -12; dx <= 12; dx += 2) {
        final at = chipCenter + Offset(dx.toDouble(), dy.toDouble());
        if (isMagenta(await pixelAt(image, at))) chipHits++;
      }
    }
    expect(guideHits, greaterThan(0));
    expect(chipHits, greaterThan(0));
  });

  test('frame painter draws only grid roles without throwing', () {
    final frame = axes();
    final recorder = ui.PictureRecorder();
    TissueFramePainter(
      bounds: bounds,
      frame: frame.frame,
      style: style,
      yawDegrees: -32,
      pitchDegrees: 22,
      zoom: 1,
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
  });
}
