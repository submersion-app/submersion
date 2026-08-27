import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/divergence_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ribbon_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';

/// Generalized multi-ribbon builder: N depth ribbons on one shared time/depth
/// scale, side-by-side (each in its own Z lane) or overlaid (all at z=0,
/// translucent). The extraction of the career terrain's stacking logic, plus
/// an overlay layout and an optional divergence surface.
class CompareGeometryService {
  static const double _zGap = 0.6;
  static const double _overlayOpacity = 0.55;

  const CompareGeometryService();

  Scene3d build(
    List<ComparisonProfile> profiles, {
    CompareLayout layout = CompareLayout.sideBySide,
    int referenceIndex = 0,
    int? focusedIndex,
  }) {
    if (profiles.isEmpty) {
      return const Scene3d(
        layers: [],
        markers: [],
        bounds: SceneBounds(durationSeconds: 1, maxDepthMeters: 1),
      );
    }
    // count == 1 renders one lane (career's single-dive case); the compare
    // providers/UI enforce the >= 2 minimum for the comparison feature.

    var maxDuration = 1.0;
    var maxDepth = 1.0;
    for (final p in profiles) {
      if (p.times.isNotEmpty && p.times.last > maxDuration) {
        maxDuration = p.times.last;
      }
      if (p.maxDepthMeters > maxDepth) maxDepth = p.maxDepthMeters;
    }

    final count = profiles.length;
    final halfZ = count <= 1 ? 0.0 : (count - 1) * 0.5 * _zGap;
    final side = layout == CompareLayout.sideBySide;
    final bounds = SceneBounds(
      durationSeconds: maxDuration,
      maxDepthMeters: maxDepth,
      sceneMinZ: side
          ? -halfZ - SceneBounds.zHalfWidth
          : -SceneBounds.zHalfWidth,
      sceneMaxZ: side ? halfZ + SceneBounds.zHalfWidth : SceneBounds.zHalfWidth,
    );

    double zCenterOf(int i) =>
        side ? (count <= 1 ? 0.0 : -halfZ + i * _zGap) : 0.0;

    final layers = <SceneLayer>[
      for (var i = 0; i < count; i++)
        SceneLayer(
          RibbonBuilder.build(
            times: profiles[i].times,
            depths: profiles[i].depths,
            sampleColors: _uniform(profiles[i].color, profiles[i].times.length),
            bounds: bounds,
            zCenter: zCenterOf(i),
            opacity: side ? 1.0 : _overlayOpacity,
          ),
        ),
      if (!side && focusedIndex != null && focusedIndex != referenceIndex)
        SceneLayer(
          DivergenceBuilder.gapSurface(
            profiles[focusedIndex],
            profiles[referenceIndex],
            bounds,
          ),
        ),
    ];

    final ref = profiles[referenceIndex];
    final refZ = zCenterOf(referenceIndex);
    return Scene3d(
      layers: layers,
      markers: const [],
      bounds: bounds,
      scrubPath: ScrubPath(
        normalizedTimes: [for (final t in ref.times) t / maxDuration],
        xs: [for (final t in ref.times) bounds.xOf(t)],
        ys: [for (final d in ref.depths) bounds.yOf(d)],
        zs: [for (final _ in ref.times) refZ],
      ),
    );
  }

  Float32List _uniform(Color color, int n) {
    final out = Float32List(n * 3);
    for (var i = 0; i < n; i++) {
      out[i * 3] = color.r;
      out[i * 3 + 1] = color.g;
      out[i * 3 + 2] = color.b;
    }
    return out;
  }
}
