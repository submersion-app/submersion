import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

List<DecoStatus> statusesForDive() {
  final algo = BuhlmannAlgorithm();
  // Descend to 30 m, bottom, ascend to the surface.
  return algo.processProfile(
    depths: const [0, 30, 30, 30, 15, 0],
    timestamps: const [0, 120, 600, 1200, 1320, 1400],
  );
}

void main() {
  test('extrudes the heat map: one vertex per (time, compartment)', () {
    final statuses = statusesForDive();
    final scene = SubsurfaceTissueBuilder.build(
      statuses,
      colorFn: thermalColor,
    );
    // Surface + M-value plane.
    expect(scene.layers.length, 2);
    final surface = scene.layers.first.mesh;
    final k = statuses.first.compartments.length;
    expect(surface.vertexCount % k, 0);
    expect(surface.colors.every((c) => c.isFinite), isTrue);
    // 3D scrub path (carries a Z track).
    expect(scene.scrubPath!.zs, isNotNull);
  });

  test('height uses subsurfacePercentage: rises as tissues supersaturate', () {
    final statuses = statusesForDive();
    final scene = SubsurfaceTissueBuilder.build(
      statuses,
      colorFn: thermalColor,
    );
    final surface = scene.layers.first.mesh;
    final k = statuses.first.compartments.length;
    final cols = surface.vertexCount ~/ k;

    // Peak height across the whole surface should match the peak
    // subsurfacePercentage across the (decimated) statuses, mapped to Y.
    var maxY = 0.0;
    for (var i = 0; i < surface.vertexCount; i++) {
      final y = surface.positions[i * 3 + 1];
      if (y > maxY) maxY = y;
    }
    // A 30 m dive that ascends develops supersaturation (>50%), so the
    // surface rises above the ambient-equilibrium mid-height.
    const midHeight = SubsurfaceTissueBuilder.referenceHeight * 0.5;
    expect(maxY, greaterThan(midHeight));
    expect(cols, greaterThan(1));
  });

  test('M-value plane sits at 100% (reference height)', () {
    final scene = SubsurfaceTissueBuilder.build(
      statusesForDive(),
      colorFn: thermalColor,
    );
    final plane = scene.layers.last.mesh;
    for (var i = 0; i < plane.vertexCount; i++) {
      expect(
        plane.positions[i * 3 + 1],
        SubsurfaceTissueBuilder.referenceHeight,
      );
    }
    expect(plane.opacity, lessThan(0.5));
  });

  test('empty or single-sample input yields an empty scene', () {
    expect(
      SubsurfaceTissueBuilder.build(const [], colorFn: thermalColor).layers,
      isEmpty,
    );
  });
}
