import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/services/plan_profile_samples.dart';

DiveProfilePoint _p(int t, double d) =>
    DiveProfilePoint(timestamp: t, depth: d);

void main() {
  test('adds a sample every 30 seconds along each leg', () {
    final samples = sampledPlanProfile([_p(0, 0), _p(120, 40)]);

    expect(samples.map((s) => s.timestamp), [0, 30, 60, 90, 120]);
    expect(samples.map((s) => s.depth), [0, 10, 20, 30, 40]);
  });

  test('keeps every corner, on the grid or not', () {
    final samples = sampledPlanProfile([
      _p(0, 0),
      _p(47, 30),
      _p(1000, 30),
      _p(1063, 6),
    ]);
    final times = samples.map((s) => s.timestamp).toList();

    expect(times, containsAll([0, 47, 1000, 1063]));
    expect(times, [...times]..sort());
    expect(times.toSet(), hasLength(times.length));
  });

  test('a stop holds its depth throughout', () {
    final samples = sampledPlanProfile([_p(0, 6), _p(180, 6)]);

    expect(samples.map((s) => s.depth), everyElement(6));
  });

  test('a sample on a corner is not doubled', () {
    final samples = sampledPlanProfile([_p(0, 0), _p(30, 10), _p(60, 20)]);

    expect(samples.map((s) => s.timestamp), [0, 30, 60]);
  });

  test('two corners at one moment keep the later', () {
    final samples = sampledPlanProfile([_p(0, 0), _p(30, 10), _p(30, 12)]);

    expect(samples.last.depth, 12);
    expect(samples, hasLength(2));
  });

  test('too little to sample comes back as it is', () {
    expect(sampledPlanProfile(const []), isEmpty);
    expect(sampledPlanProfile([_p(0, 0)]), hasLength(1));
  });
}
