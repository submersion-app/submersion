import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

List<DecoStatus> statusesForDive() => BuhlmannAlgorithm().processProfile(
  depths: const [0, 30, 30, 30, 15, 0],
  timestamps: const [0, 120, 600, 1200, 1320, 1400],
);

void main() {
  test('buildResult grid matches the mesh dimensions and values', () {
    final statuses = statusesForDive();
    final result = SubsurfaceTissueBuilder.buildResult(
      statuses,
      colorFn: thermalColor,
    );
    final grid = result.grid;
    final k = statuses.first.compartments.length;

    expect(grid.compartments, k);
    expect(grid.columns, greaterThan(1));
    expect(grid.positions.length, grid.columns * grid.compartments * 3);
    expect(grid.saturationPct.length, grid.columns * grid.compartments);
    expect(grid.normalizedTimes.length, grid.columns);
    expect(grid.compartmentNumbers.length, k);
    expect(grid.halfTimesN2.length, k);

    // Grid positions are the exact mesh vertex positions.
    final surface = result.scene.layers.first.mesh;
    expect(grid.positions.length, surface.positions.length);
    for (var i = 0; i < grid.positions.length; i++) {
      expect(grid.positions[i], surface.positions[i]);
    }

    // normalizedTimes is 0..1 monotonic.
    expect(grid.normalizedTimes.first, 0.0);
    expect(grid.normalizedTimes.last, 1.0);

    // percentAt returns a sane value at a mid column.
    final cols = grid.columns;
    final midCol = cols ~/ 2;
    final y = grid.positionAt(midCol, 0).$2;
    expect(y, greaterThanOrEqualTo(0));
    expect(grid.percentAt(midCol, 0), greaterThanOrEqualTo(0));
  });

  test('build still returns just the Scene3d (back-compat)', () {
    final scene = SubsurfaceTissueBuilder.build(
      statusesForDive(),
      colorFn: thermalColor,
    );
    expect(scene.layers.length, 2);
  });

  test('empty input yields an empty grid', () {
    final result = SubsurfaceTissueBuilder.buildResult(
      const [],
      colorFn: thermalColor,
    );
    expect(result.grid.isEmpty, isTrue);
    expect(result.scene.layers, isEmpty);
  });
}
