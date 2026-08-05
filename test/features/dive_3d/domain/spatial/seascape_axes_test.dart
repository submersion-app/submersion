import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';

SpatialProjection proj({
  double minEast = 0,
  double maxEast = 8000,
  double minNorth = 0,
  double maxNorth = 8000,
  double maxDepth = 40,
}) => SpatialProjection(
  minEast: minEast,
  maxEast: maxEast,
  minNorth: minNorth,
  maxNorth: maxNorth,
  maxDepth: maxDepth,
);

SeascapeAxes metric() => buildSeascapeAxes(
  projection: proj(),
  minEast: 0,
  maxEast: 8000,
  minNorth: 0,
  maxNorth: 8000,
  maxDepthMeters: 40,
  displayUnitInMeters: 1.0,
  distanceTitle: 'Distance (m)',
  depthTitle: 'Depth (m)',
);

void main() {
  test('frame has the three axes anchored at the origin corner', () {
    final axes = metric();
    final byRole = <AxisRole, List<AxisSegment>>{};
    for (final s in axes.frame.segments) {
      byRole.putIfAbsent(s.role, () => []).add(s);
    }
    expect(byRole[AxisRole.axisX], hasLength(1));
    expect(byRole[AxisRole.axisY], hasLength(1));
    expect(byRole[AxisRole.axisZ], hasLength(1));
    // No reference grids in the seascape: scenic view stays clean.
    expect(byRole[AxisRole.frameGrid], isNull);
    final p = proj();
    final x = byRole[AxisRole.axisX]!.single;
    expect(x.x1, closeTo(p.xOf(0), 1e-9));
    expect(x.x2, closeTo(p.xOf(8000), 1e-9));
    expect(x.y1, 0);
    // Depth axis descends from the waterline to max depth.
    final y = byRole[AxisRole.axisY]!.single;
    expect(y.y1, 0);
    expect(y.y2, closeTo(p.yOf(40), 1e-9));
  });

  test('metric ticks land on nice steps measured from the corner', () {
    final axes = metric();
    final ticks = axes.labels.labels
        .where((l) => l.kind == AxisLabelKind.tick)
        .map((l) => l.text)
        .toList();
    // X and Z: 8000 m / 5 -> nice step 2000; depth: 40 m / 4 -> step 10.
    // The 0 label is skipped on every axis (corner clutter).
    expect(ticks, isNot(contains('0')));
    expect(ticks.where((t) => t == '2000').length, 2); // X and Z
    expect(ticks, contains('8000'));
    expect(ticks, containsAll(['10', '20', '30', '40']));
  });

  test('imperial ticks use nice steps in feet', () {
    final axes = buildSeascapeAxes(
      projection: proj(),
      minEast: 0,
      maxEast: 8000,
      minNorth: 0,
      maxNorth: 8000,
      maxDepthMeters: 40,
      displayUnitInMeters: 0.3048,
      distanceTitle: 'Distance (ft)',
      depthTitle: 'Depth (ft)',
    );
    final ticks = axes.labels.labels
        .where((l) => l.kind == AxisLabelKind.tick)
        .map((l) => l.text)
        .toSet();
    // Depth: 40 m = 131.2 ft; /4 = 32.8 -> nice 50 -> 50, 100.
    expect(ticks, containsAll(['50', '100']));
    // Distance: 8000 m = 26247 ft; /5 = 5249 -> nice 10000 -> 10000, 20000.
    expect(ticks, containsAll(['10000', '20000']));
  });

  test('tick scene positions match the projection', () {
    final axes = metric();
    final p = proj();
    final tick2000 = axes.labels.labels.firstWhere(
      (l) =>
          l.kind == AxisLabelKind.tick && l.text == '2000' && l.z == p.zOf(0),
    );
    expect(tick2000.x, closeTo(p.xOf(2000), 1e-9));
    expect(tick2000.y, 0);
    final depth20 = axes.labels.labels.firstWhere(
      (l) => l.kind == AxisLabelKind.tick && l.text == '20',
    );
    expect(depth20.y, closeTo(p.yOf(20), 1e-9));
  });

  test('titles are placed at the axis ends', () {
    final axes = metric();
    final titles = axes.labels.labels
        .where((l) => l.kind == AxisLabelKind.title)
        .map((l) => l.text)
        .toList();
    expect(titles, ['Distance (m)', 'Depth (m)']);
  });

  test('degenerate spans are safe and tickless', () {
    final axes = buildSeascapeAxes(
      projection: proj(maxEast: 0, maxNorth: 0, maxDepth: 1),
      minEast: 0,
      maxEast: 0,
      minNorth: 0,
      maxNorth: 0,
      maxDepthMeters: 0,
      displayUnitInMeters: 1.0,
      distanceTitle: 'Distance (m)',
      depthTitle: 'Depth (m)',
    );
    expect(
      axes.labels.labels.where((l) => l.kind == AxisLabelKind.tick),
      isEmpty,
    );
  });
}
