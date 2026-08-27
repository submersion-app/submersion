import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';

void main() {
  test('fromRange snaps outward to a nice step (hand-computed vectors)', () {
    final c = ZAxisSpec.fromRange(min: 12, max: 22, symbol: '°C');
    expect((c.lo, c.hi, c.step), (10.0, 25.0, 5.0));
    final f = ZAxisSpec.fromRange(min: 53.6, max: 71.6, symbol: '°F');
    expect((f.lo, f.hi, f.step), (50.0, 75.0, 5.0));
    final bar = ZAxisSpec.fromRange(min: 60, max: 210, symbol: 'bar');
    expect((bar.lo, bar.hi, bar.step), (50.0, 250.0, 50.0));
    final psi = ZAxisSpec.fromRange(min: 870, max: 3045, symbol: 'psi');
    expect((psi.lo, psi.hi, psi.step), (0.0, 4000.0, 1000.0));
    final rate = ZAxisSpec.fromRange(min: -12, max: 18, symbol: 'm/min');
    expect((rate.lo, rate.hi, rate.step), (-20.0, 20.0, 10.0));
    final ppo2 = ZAxisSpec.fromRange(min: 0.21, max: 1.4, symbol: '');
    expect(ppo2.lo, closeTo(0, 1e-9));
    expect(ppo2.hi, closeTo(1.5, 1e-9));
    expect(ppo2.step, closeTo(0.5, 1e-9));
  });

  test('a flat series still gets a non-empty band', () {
    final flat = ZAxisSpec.fromRange(min: 20, max: 20, symbol: '°C');
    expect(flat.hi, greaterThan(flat.lo));
    expect(flat.ticks.length, greaterThanOrEqualTo(2));
  });

  test('zOf maps lo..hi onto the path span, larger toward +Z', () {
    const spec = ZAxisSpec(lo: 10, hi: 20, step: 5, symbol: '');
    expect(spec.zOf(10), -SceneBounds.zPathHalfSpan);
    expect(spec.zOf(20), SceneBounds.zPathHalfSpan);
    expect(spec.zOf(15), closeTo(0, 1e-9));
    expect(spec.zOf(99), SceneBounds.zPathHalfSpan); // clamped
  });

  test('ticks run lo..hi inclusive without float drift', () {
    const spec = ZAxisSpec(lo: 0, hi: 1.5, step: 0.5, symbol: '');
    expect(spec.ticks, [0.0, 0.5, 1.0, 1.5]);
  });
}
