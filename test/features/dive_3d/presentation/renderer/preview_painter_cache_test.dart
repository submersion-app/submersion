import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/triangle_soup.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

const _size = ui.Size(160, 120);
const _bounds = SceneBounds(durationSeconds: 1, maxDepthMeters: 10);

/// A bumpy textured grid, so triangles face many ways and overlap from
/// most camera angles: a wrong order or a stale shade shows in pixels.
MeshData _terrain({double lift = 0}) {
  const n = 12;
  final positions = Float32List(n * n * 3);
  final colors = Float32List(n * n * 3);
  final uvs = Float32List(n * n * 2);
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      final i = r * n + c;
      positions[i * 3] = c / (n - 1) * SceneBounds.xSpan;
      positions[i * 3 + 1] =
          -SceneBounds.ySpan / 2 + ((r * 7 + c * 3) % 5 - 2) * 0.4 + lift;
      positions[i * 3 + 2] = (r / (n - 1) - 0.5) * 6;
      colors[i * 3] = r / n;
      colors[i * 3 + 1] = c / n;
      colors[i * 3 + 2] = 0.6;
      uvs[i * 2] = c / (n - 1);
      uvs[i * 2 + 1] = r / (n - 1);
    }
  }
  final indices = <int>[];
  for (var r = 0; r < n - 1; r++) {
    for (var c = 0; c < n - 1; c++) {
      final a = r * n + c;
      indices
        ..addAll([a, a + 1, a + n])
        ..addAll([a + 1, a + n + 1, a + n]);
    }
  }
  return MeshData(
    positions: positions,
    indices: Uint32List.fromList(indices),
    colors: colors,
    textureCoordinates: uvs,
  );
}

MeshData _drape() => MeshData(
  positions: Float32List.fromList([3, -2, -1, 7, -2, -1, 5, -2, 2]),
  indices: Uint32List.fromList([0, 1, 2]),
  colors: Float32List.fromList([1, 1, 0, 1, 1, 0, 1, 1, 0]),
  opacity: 0.7,
);

MeshData _rest() => MeshData(
  positions: Float32List.fromList([1, -6, 0, 9, -6, 0, 5, -1, 0]),
  indices: Uint32List.fromList([0, 1, 2]),
  colors: Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1]),
  opacity: 0.5,
);

Scene3d _scene(MeshData terrain) => Scene3d(
  layers: [
    SceneLayer(terrain),
    SceneLayer(_drape(), overlay: SceneOverlay.contours, drapedOnTerrain: true),
    SceneLayer(_rest()),
  ],
  markers: const [],
  bounds: _bounds,
);

typedef _Frame = ({
  Scene3d scene,
  double yaw,
  double pitch,
  double zoom,
  Set<SceneOverlay>? overlays,
  ui.Image? imagery,
});

Future<Uint8List> _pixels(_Frame f, ScenePaintCache? cache) async {
  final recorder = ui.PictureRecorder();
  Dive3dScenePainter(
    scene: f.scene,
    yawDegrees: f.yaw,
    pitchDegrees: f.pitch,
    zoom: f.zoom,
    visibleOverlays: f.overlays,
    terrainImagery: f.imagery,
    imageryWhiteTexel: f.imagery == null ? null : (u: 0.9, v: 0.9),
    cache: cache,
  ).paint(ui.Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  return bytes.buffer.asUint8List();
}

Future<ui.Image> _imagery() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = const ui.Color(0xFF3366FF),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFFFFCC00),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(7, 7, 1, 1),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  return recorder.endRecording().toImage(8, 8);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a cached painter paints exactly what a fresh one does', () async {
    final imagery = await _imagery();
    addTearDown(imagery.dispose);
    final first = _scene(_terrain());
    final second = _scene(_terrain(lift: 1.5));
    const all = null;
    const noContours = {SceneOverlay.markers};
    // An orbit, a zoom with the camera held still, an overlay toggle, the
    // imagery arriving, and a fresh scene: every way the cache can be
    // asked to reuse or rebuild.
    final frames = <_Frame>[
      (
        scene: first,
        yaw: -32,
        pitch: 22,
        zoom: 1,
        overlays: all,
        imagery: null,
      ),
      (
        scene: first,
        yaw: -20,
        pitch: 22,
        zoom: 1,
        overlays: all,
        imagery: null,
      ),
      (
        scene: first,
        yaw: -20,
        pitch: 40,
        zoom: 1,
        overlays: all,
        imagery: null,
      ),
      (
        scene: first,
        yaw: -20,
        pitch: 40,
        zoom: 2,
        overlays: all,
        imagery: null,
      ),
      (
        scene: first,
        yaw: -20,
        pitch: 40,
        zoom: 2,
        overlays: noContours,
        imagery: null,
      ),
      (
        scene: first,
        yaw: -20,
        pitch: 40,
        zoom: 2,
        overlays: noContours,
        imagery: imagery,
      ),
      (
        scene: first,
        yaw: 75,
        pitch: 10,
        zoom: 0.7,
        overlays: all,
        imagery: imagery,
      ),
      (
        scene: first,
        yaw: 75,
        pitch: 10,
        zoom: 1.3,
        overlays: all,
        imagery: imagery,
      ),
      (
        scene: second,
        yaw: 75,
        pitch: 10,
        zoom: 1.3,
        overlays: all,
        imagery: imagery,
      ),
      (
        scene: second,
        yaw: 75,
        pitch: 10,
        zoom: 1.3,
        overlays: all,
        imagery: null,
      ),
    ];
    final cache = ScenePaintCache();
    for (var i = 0; i < frames.length; i++) {
      final cached = await _pixels(frames[i], cache);
      final fresh = await _pixels(frames[i], null);
      expect(cached, fresh, reason: 'frame $i');
    }
  });

  test('orbiting re-sorts without rebuilding the mesh data', () async {
    final scene = _scene(_terrain());
    final cache = ScenePaintCache();
    Future<void> paint(double yaw, double zoom) => _pixels((
      scene: scene,
      yaw: yaw,
      pitch: 22,
      zoom: zoom,
      overlays: null,
      imagery: null,
    ), cache);

    await paint(-32, 1);
    final soup = cache.soupAt(0);
    expect(soup.buildCount, 1);
    expect(soup.sortCount, 1);

    await paint(-10, 1);
    expect(soup.buildCount, 1, reason: 'same meshes, no rebuild');
    expect(soup.sortCount, 2, reason: 'a new yaw needs a new order');

    await paint(-10, 3);
    expect(soup.sortCount, 2, reason: 'zoom alone keeps the order');

    await paint(-10, 3);
    expect(soup.sortCount, 2);
  });

  test('a new scene rebuilds, and fewer groups drop their soups', () async {
    final cache = ScenePaintCache();
    Future<void> paint(Scene3d scene, Set<SceneOverlay>? overlays) => _pixels((
      scene: scene,
      yaw: -32,
      pitch: 22,
      zoom: 1,
      overlays: overlays,
      imagery: null,
    ), cache);

    await paint(_scene(_terrain()), null);
    expect(cache.soupCount, 2, reason: 'merged group plus the rest layer');
    final merged = cache.soupAt(0);
    expect(merged.buildCount, 1);
    final screen = merged.screen;
    final order = merged.order;

    await paint(_scene(_terrain()), null);
    expect(merged.buildCount, 2, reason: 'different mesh objects');
    expect(
      identical(merged.screen, screen) && identical(merged.order, order),
      isTrue,
      reason: 'same-sized meshes refill the buffers they had',
    );

    final single = Scene3d(
      layers: [SceneLayer(_terrain())],
      markers: const [],
      bounds: _bounds,
    );
    await paint(single, null);
    expect(cache.soupCount, 1);
  });

  test('a different cache asks the host to repaint', () {
    final scene = _scene(_terrain());
    final a = Dive3dScenePainter(scene: scene, cache: ScenePaintCache());
    final b = Dive3dScenePainter(scene: scene, cache: ScenePaintCache());
    expect(b.shouldRepaint(a), isTrue);
    final c = Dive3dScenePainter(scene: scene, cache: a.cache);
    expect(c.shouldRepaint(a), isFalse);
  });

  test('channelByte matches the clamp it replaced, edge cases included', () {
    for (final c in [
      -1.0,
      -0.0,
      0.0,
      0.001,
      0.5,
      0.998,
      1.0,
      1.0000001,
      7.0,
      double.infinity,
      double.negativeInfinity,
      double.nan,
    ]) {
      expect(
        Dive3dScenePainter.channelByte(c),
        (c.clamp(0.0, 1.0) * 255).round(),
        reason: '$c',
      );
    }
  });
}
