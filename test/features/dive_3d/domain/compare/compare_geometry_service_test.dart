import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/compare_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

ComparisonProfile prof(String id, List<double> t, List<double> d) =>
    ComparisonProfile(
      id: id,
      label: id,
      color: const Color(0xFF00D4FF),
      times: t,
      depths: d,
      maxDepthMeters: d.reduce((a, b) => a > b ? a : b),
    );

void main() {
  final a = prof('a', const [0, 60, 120], const [0, 30, 0]);
  final b = prof('b', const [0, 60, 180], const [0, 20, 0]);
  const svc = CompareGeometryService();

  test('empty input yields an empty scene', () {
    expect(svc.build(const []).layers, isEmpty);
  });

  test('a single profile renders one lane at z=0', () {
    // Career renders a single dive; the compare UI enforces >= 2 upstream.
    final scene = svc.build([a]);
    expect(scene.layers, hasLength(1));
    expect(
      scene.layers[0].mesh.positions[2],
      closeTo(-SceneBounds.zHalfWidth, 1e-6),
    ); // zCenter 0
  });

  test('side-by-side lays each ribbon in its own Z lane', () {
    final scene = svc.build([a, b], layout: CompareLayout.sideBySide);
    expect(scene.layers.length, 2);
    const halfZ = 0.5 * 0.6; // (2-1)*0.5*0.6
    expect(
      scene.layers[0].mesh.positions[2],
      closeTo(-halfZ - SceneBounds.zHalfWidth, 1e-6),
    );
    expect(
      scene.layers[1].mesh.positions[2],
      closeTo(halfZ - SceneBounds.zHalfWidth, 1e-6),
    );
  });

  test('shared bounds span the deepest, longest profile', () {
    final scene = svc.build([a, b]);
    expect(scene.bounds.durationSeconds, 180);
    expect(scene.bounds.maxDepthMeters, 30);
  });

  test('overlay places every ribbon at z=0 and reduces opacity', () {
    final scene = svc.build([a, b], layout: CompareLayout.overlay);
    expect(
      scene.layers[0].mesh.positions[2],
      closeTo(-SceneBounds.zHalfWidth, 1e-6),
    ); // zCenter 0
    expect(
      scene.layers[1].mesh.positions[2],
      closeTo(-SceneBounds.zHalfWidth, 1e-6),
    );
    expect(scene.layers[0].mesh.opacity, lessThan(1.0));
  });

  test('scrub path rides the reference profile', () {
    final scene = svc.build([a, b], referenceIndex: 1);
    expect(scene.scrubPath, isNotNull);
    // reference b is 180 s long -> last normalized time is 1.0
    expect(scene.scrubPath!.normalizedTimes.last, closeTo(1.0, 1e-9));
  });
}
