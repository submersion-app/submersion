import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/profile_resampler.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

/// Where and how far a profile diverges from the reference.
class DivergenceMark {
  final String profileId;
  final double atTimeSeconds;
  final double gapMeters; // signed: profile depth - reference depth
  const DivergenceMark({
    required this.profileId,
    required this.atTimeSeconds,
    required this.gapMeters,
  });
}

/// Reference-based divergence: the largest depth gap of each other profile vs
/// the reference, and a translucent surface between one focused profile and
/// the reference (overlay layout).
class DivergenceBuilder {
  static const Color _gapColor = Color(0xFFFFC857);
  static const double _gapOpacity = 0.22;

  static List<DivergenceMark> maxGaps(
    List<ComparisonProfile> profiles,
    int referenceIndex,
  ) {
    if (profiles.length < 2) return const [];
    final ref = profiles[referenceIndex];
    final marks = <DivergenceMark>[];
    for (var i = 0; i < profiles.length; i++) {
      if (i == referenceIndex) continue;
      final p = profiles[i];
      var bestAbs = -1.0;
      var bestGap = 0.0;
      var bestT = 0.0;
      for (final t in ref.times) {
        if (t < p.times.first || t > p.times.last) continue;
        final gap =
            ProfileResampler.depthAt(p, t) - ProfileResampler.depthAt(ref, t);
        if (gap.abs() > bestAbs) {
          bestAbs = gap.abs();
          bestGap = gap;
          bestT = t;
        }
      }
      marks.add(
        DivergenceMark(
          profileId: p.id,
          atTimeSeconds: bestT,
          gapMeters: bestGap,
        ),
      );
    }
    return marks;
  }

  static MeshData gapSurface(
    ComparisonProfile focused,
    ComparisonProfile reference,
    SceneBounds bounds,
  ) {
    // Triangle strip between the two curves over the reference's knots that
    // fall inside the focused profile's time range.
    final knots = [
      for (final t in reference.times)
        if (t >= focused.times.first && t <= focused.times.last) t,
    ];
    if (knots.length < 2) {
      return MeshData(
        positions: Float32List(0),
        indices: Uint32List(0),
        colors: Float32List(0),
        opacity: _gapOpacity,
      );
    }
    final n = knots.length;
    final positions = Float32List(n * 6);
    final colors = Float32List(n * 6);
    for (var i = 0; i < n; i++) {
      final t = knots[i];
      final x = bounds.xOf(t);
      final yF = bounds.yOf(ProfileResampler.depthAt(focused, t));
      final yR = bounds.yOf(ProfileResampler.depthAt(reference, t));
      final p = i * 6;
      positions[p] = x;
      positions[p + 1] = yF;
      positions[p + 2] = 0;
      positions[p + 3] = x;
      positions[p + 4] = yR;
      positions[p + 5] = 0;
      for (var k = 0; k < 2; k++) {
        colors[p + k * 3] = _gapColor.r;
        colors[p + k * 3 + 1] = _gapColor.g;
        colors[p + k * 3 + 2] = _gapColor.b;
      }
    }
    final indices = Uint32List((n - 1) * 6);
    var j = 0;
    for (var i = 0; i < n - 1; i++) {
      final a = i * 2, b = i * 2 + 1, c = i * 2 + 2, d = i * 2 + 3;
      indices[j++] = a;
      indices[j++] = b;
      indices[j++] = c;
      indices[j++] = b;
      indices[j++] = d;
      indices[j++] = c;
    }
    return MeshData(
      positions: positions,
      indices: indices,
      colors: colors,
      opacity: _gapOpacity,
    );
  }
}
