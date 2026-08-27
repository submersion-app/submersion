import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

/// The deco margin as a translucent sheet standing between the path and its
/// ceiling depth, following the path in Z. Its height is the margin the
/// diver has to the ceiling; samples where the diver is shallower than the
/// ceiling (a violation) render red.
class CeilingBuilder {
  static const Color _safe = Color(0xFFF59E0B);
  static const Color _violation = Color(0xFFEF4444);
  static const double _opacity = 0.35;

  static MeshData? build({
    required List<double> times,
    required List<double> depths,
    required List<double> zs,
    required List<double?> ceilings,
    required SceneBounds bounds,
  }) {
    final active = <int>[];
    for (var i = 0; i < ceilings.length; i++) {
      final c = ceilings[i];
      if (c != null && c > 0) active.add(i);
    }
    if (active.length < 2) return null;

    final positions = Float32List(active.length * 6);
    final colors = Float32List(active.length * 6);
    for (var j = 0; j < active.length; j++) {
      final i = active[j];
      final x = bounds.xOf(times[i]);
      final color = depths[i] < ceilings[i]! ? _violation : _safe;
      final p = j * 6;
      positions[p] = x;
      positions[p + 1] = bounds.yOf(depths[i]);
      positions[p + 2] = zs[i];
      positions[p + 3] = x;
      positions[p + 4] = bounds.yOf(ceilings[i]!);
      positions[p + 5] = zs[i];
      for (var k = 0; k < 2; k++) {
        colors[p + k * 3] = color.r;
        colors[p + k * 3 + 1] = color.g;
        colors[p + k * 3 + 2] = color.b;
      }
    }

    // Strip indices, but break the strip across gaps in the active run so
    // separate deco periods do not get bridged by a stray quad.
    final indexList = <int>[];
    for (var j = 0; j < active.length - 1; j++) {
      if (active[j + 1] != active[j] + 1) continue;
      final a = j * 2, b = j * 2 + 1, c = j * 2 + 2, d = j * 2 + 3;
      indexList.addAll([a, b, c, b, d, c]);
    }
    if (indexList.isEmpty) return null;
    return MeshData(
      positions: positions,
      indices: Uint32List.fromList(indexList),
      colors: colors,
      opacity: _opacity,
    );
  }
}
