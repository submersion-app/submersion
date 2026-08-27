import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/dive_axes.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';

void main() {
  const bounds = SceneBounds(
    durationSeconds: 3120,
    maxDepthMeters: 38,
    sceneMinZ: -SceneBounds.zPathHalfSpan,
    sceneMaxZ: SceneBounds.zPathHalfSpan,
  );
  List<AxisTick> depthTicks() =>
      depthAxisTicks(maxDepthMeters: 38, stepMeters: 10, toDisplay: (m) => m);

  test('depth ticks step in meters and label in the display unit', () {
    expect(depthTicks().map((t) => t.text), ['0', '10', '20', '30']);
    final imperial = depthAxisTicks(
      maxDepthMeters: 38,
      stepMeters: 7.62,
      toDisplay: (m) => m / 0.3048,
    );
    expect(imperial.map((t) => t.text), ['0', '25', '50', '75', '100']);
    expect(imperial[1].value, closeTo(7.62, 1e-9));
  });

  test('time ticks pick the first nice step with at most six ticks', () {
    expect(timeAxisTicks(3120).map((t) => t.text), [
      '0',
      '10',
      '20',
      '30',
      '40',
      '50',
    ]);
    expect(timeAxisTicks(180).map((t) => t.text), ['0', '1', '2', '3']);
    expect(timeAxisTicks(3120)[1].value, 600);
  });

  test('frame has three axes, ticks, and wall grids when Z is set', () {
    const spec = ZAxisSpec(lo: 10, hi: 25, step: 5, symbol: '°C');
    final axes = buildDiveAxes(
      bounds: bounds,
      depthTicks: depthTicks(),
      timeTicks: timeAxisTicks(3120),
      zAxis: spec,
      depthTitle: 'Depth (m)',
      timeTitle: 'Run time (min)',
      zTitle: 'Temperature (°C)',
    );
    final roles = axes.frame.segments.map((s) => s.role).toSet();
    expect(roles, containsAll(AxisRole.values));
    final zTicks = axes.frame.segments.where((s) => s.role == AxisRole.tickZ);
    expect(zTicks, hasLength(4)); // 10, 15, 20, 25
    expect(zTicks.first.z1, closeTo(spec.zOf(10), 1e-9));
    expect(zTicks.first.x1, SceneBounds.xSpan);
    final depthTick = axes.frame.segments.firstWhere(
      (s) => s.role == AxisRole.tickY && s.y1 != 0,
    );
    expect(depthTick.y1, closeTo(bounds.yOf(10), 1e-9));
    expect(depthTick.z1, bounds.sceneMaxZ);
    final titles = axes.labels.labels
        .where((l) => l.kind == AxisLabelKind.title)
        .map((l) => l.text);
    expect(titles, ['Depth (m)', 'Run time (min)', 'Temperature (°C)']);
    final zLabels = axes.labels.labels
        .where((l) => l.kind == AxisLabelKind.tick && l.x == SceneBounds.xSpan)
        .map((l) => l.text);
    expect(zLabels, ['10', '15', '20', '25']);
  });

  test('None mode omits the Z axis, its ticks, and its grid lines', () {
    final axes = buildDiveAxes(
      bounds: bounds,
      depthTicks: depthTicks(),
      timeTicks: timeAxisTicks(3120),
      depthTitle: 'Depth (m)',
      timeTitle: 'Run time (min)',
    );
    final roles = axes.frame.segments.map((s) => s.role).toSet();
    expect(roles, isNot(contains(AxisRole.axisZ)));
    expect(roles, isNot(contains(AxisRole.tickZ)));
    // Box edges + 4 depth ticks x 2 walls + 6 time ticks x 2 walls.
    final grid = axes.frame.segments.where((s) => s.role == AxisRole.frameGrid);
    expect(grid, hasLength(9 + 4 * 2 + 6 * 2));
    expect(
      axes.labels.labels.where((l) => l.kind == AxisLabelKind.title),
      hasLength(2),
    );
  });
}
