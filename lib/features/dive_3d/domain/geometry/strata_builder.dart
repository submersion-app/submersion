import 'dart:typed_data';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

/// One thermal band of the water column.
class StrataBand {
  final double topMeters;
  final double bottomMeters;
  final double meanTempCelsius;

  const StrataBand({
    required this.topMeters,
    required this.bottomMeters,
    required this.meanTempCelsius,
  });
}

/// Bins profile samples into fixed-depth bands and renders each band as a
/// translucent horizontal quad at its mid-depth, colored by mean
/// temperature. Stacked planes read as the thermal structure of the water
/// column; thermoclines show up as abrupt color changes between planes.
class StrataBuilder {
  static const double _opacity = 0.15;

  static List<StrataBand> bin({
    required List<double> depths,
    required List<double?> temperatures,
    double bandMeters = 2.0,
  }) {
    final sums = <int, double>{};
    final counts = <int, int>{};
    for (var i = 0; i < depths.length; i++) {
      final t = temperatures[i];
      if (t == null || !t.isFinite) continue;
      final band = (depths[i] / bandMeters).floor();
      sums[band] = (sums[band] ?? 0) + t;
      counts[band] = (counts[band] ?? 0) + 1;
    }
    final bands = sums.keys.toList()..sort();
    return [
      for (final b in bands)
        StrataBand(
          topMeters: b * bandMeters,
          bottomMeters: (b + 1) * bandMeters,
          meanTempCelsius: sums[b]! / counts[b]!,
        ),
    ];
  }

  static MeshData? build({
    required List<StrataBand> bands,
    required SceneBounds bounds,
  }) {
    if (bands.isEmpty) return null;
    final temps = bands.map<double?>((b) => b.meanTempCelsius).toList();
    final bandColors = MetricPalette.colorsFor(SceneMetric.temperature, temps);
    final positions = Float32List(bands.length * 12);
    final colors = Float32List(bands.length * 12);
    final indices = Uint32List(bands.length * 6);
    const z = SceneBounds.zSlabHalfWidth;
    for (var i = 0; i < bands.length; i++) {
      final band = bands[i];
      final y = bounds.yOf((band.topMeters + band.bottomMeters) / 2);
      final p = i * 12;
      final corners = [
        [0.0, y, -z],
        [0.0, y, z],
        [SceneBounds.xSpan, y, -z],
        [SceneBounds.xSpan, y, z],
      ];
      for (var v = 0; v < 4; v++) {
        positions[p + v * 3] = corners[v][0];
        positions[p + v * 3 + 1] = corners[v][1];
        positions[p + v * 3 + 2] = corners[v][2];
        colors[p + v * 3] = bandColors[i * 3];
        colors[p + v * 3 + 1] = bandColors[i * 3 + 1];
        colors[p + v * 3 + 2] = bandColors[i * 3 + 2];
      }
      final base = i * 4;
      final q = i * 6;
      indices[q] = base;
      indices[q + 1] = base + 1;
      indices[q + 2] = base + 2;
      indices[q + 3] = base + 1;
      indices[q + 4] = base + 3;
      indices[q + 5] = base + 2;
    }
    return MeshData(
      positions: positions,
      indices: indices,
      colors: colors,
      opacity: _opacity,
    );
  }
}
