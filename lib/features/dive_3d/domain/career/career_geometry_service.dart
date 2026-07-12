import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/career/career_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/compare/compare_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';

/// How career ribbons are colored across the set.
enum CareerColorMode { recency, depth }

/// Builds the career "terrain": one depth ribbon per dive, stacked along Z
/// under a single shared time and depth scale so the profiles are directly
/// comparable. The multi-ribbon stacking is delegated to
/// [CompareGeometryService]; this class owns only the across-set color ramps.
/// Pure and isolate-friendly; renders through Scene3d.
class CareerGeometryService {
  // Recency ramp: older (faded slate) -> newer (bright cyan).
  static const Color _oldColor = Color(0xFF64748B);
  static const Color _newColor = Color(0xFF22D3EE);
  // Depth ramp: shallow (green) -> deep (indigo).
  static const Color _shallowColor = Color(0xFF34D399);
  static const Color _deepColor = Color(0xFF4F46E5);

  const CareerGeometryService();

  Scene3d build(
    CareerSceneData data, {
    CareerColorMode colorMode = CareerColorMode.recency,
  }) {
    final dives = data.dives;
    if (dives.isEmpty) {
      return const Scene3d(
        layers: [],
        markers: [],
        bounds: SceneBounds(durationSeconds: 1, maxDepthMeters: 1),
      );
    }

    var maxDepth = 1.0;
    for (final d in dives) {
      if (d.maxDepthMeters > maxDepth) maxDepth = d.maxDepthMeters;
    }
    final count = dives.length;

    final profiles = [
      for (final dive in dives)
        ComparisonProfile(
          id: '${dive.index}',
          label: '',
          color: _colorFor(dive, count, maxDepth, colorMode),
          times: dive.times,
          depths: dive.depths,
          maxDepthMeters: dive.maxDepthMeters,
        ),
    ];

    return const CompareGeometryService().build(
      profiles,
      layout: CompareLayout.sideBySide,
    );
  }

  Color _colorFor(
    CareerDiveInput dive,
    int count,
    double maxDepth,
    CareerColorMode mode,
  ) {
    switch (mode) {
      case CareerColorMode.recency:
        final t = count <= 1 ? 1.0 : dive.index / (count - 1);
        return Color.lerp(_oldColor, _newColor, t)!;
      case CareerColorMode.depth:
        final t = maxDepth <= 0 ? 0.0 : (dive.maxDepthMeters / maxDepth);
        return Color.lerp(_shallowColor, _deepColor, t.clamp(0.0, 1.0))!;
    }
  }
}
