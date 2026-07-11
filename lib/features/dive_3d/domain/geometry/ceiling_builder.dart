import 'dart:typed_data';
import 'dart:ui';

import '../entities/mesh_data.dart';
import 'scene_bounds.dart';

/// Renders the per-sample deco ceiling as a translucent strip above the
/// ribbon: the physical "roof" the diver must stay below. The vertical gap
/// between ribbon and ceiling is the deco margin. Samples where the diver
/// is shallower than the ceiling (a ceiling violation) render red.
class CeilingBuilder {
  static const Color _safe = Color(0xFFF59E0B);
  static const Color _violation = Color(0xFFEF4444);
  static const double _opacity = 0.35;
  static const double _zHalf = SceneBounds.zHalfWidth * 3;

  static MeshData? build({
    required List<double> times,
    required List<double> depths,
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
      final y = bounds.yOf(ceilings[i]!);
      final color = depths[i] < ceilings[i]! ? _violation : _safe;
      final p = j * 6;
      positions[p] = x;
      positions[p + 1] = y;
      positions[p + 2] = -_zHalf;
      positions[p + 3] = x;
      positions[p + 4] = y;
      positions[p + 5] = _zHalf;
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
