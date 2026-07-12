import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/divergence_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

ComparisonProfile prof(String id, List<double> d) => ComparisonProfile(
  id: id,
  label: id,
  color: const Color(0xFF00D4FF),
  times: const [0, 60, 120],
  depths: d,
  maxDepthMeters: d.reduce((a, b) => a > b ? a : b),
);

void main() {
  final ref = prof('ref', const [0, 30, 0]);
  final other = prof('b', const [0, 34, 0]); // +4 m at t=60

  test('maxGaps finds the largest signed gap vs reference', () {
    final marks = DivergenceBuilder.maxGaps([ref, other], 0);
    expect(marks, hasLength(1)); // one per non-reference profile
    expect(marks.single.profileId, 'b');
    expect(marks.single.atTimeSeconds, 60);
    expect(marks.single.gapMeters, closeTo(4, 1e-9));
  });

  test('reference change flips the sign', () {
    final marks = DivergenceBuilder.maxGaps([ref, other], 1);
    expect(marks.single.gapMeters, closeTo(-4, 1e-9));
  });

  test('gapSurface produces a non-empty translucent mesh', () {
    final mesh = DivergenceBuilder.gapSurface(
      other,
      ref,
      const SceneBounds(durationSeconds: 120, maxDepthMeters: 34),
    );
    expect(mesh.vertexCount, greaterThan(0));
    expect(mesh.opacity, lessThan(1.0));
  });
}
