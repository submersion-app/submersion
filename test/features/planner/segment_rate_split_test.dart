import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/segment_rate_split.dart';

const _gas = GasMix(o2: 21);

PlanSegment _seg(
  String id,
  double targetDepth, {
  required int durationSeconds,
  bool splitAtConfiguredRate = false,
  int order = 0,
}) => PlanSegment(
  id: id,
  targetDepth: targetDepth,
  durationSeconds: durationSeconds,
  tankId: 'back',
  gasMix: _gas,
  splitAtConfiguredRate: splitAtConfiguredRate,
  order: order,
);

domain.DivePlan _plan({
  required List<PlanSegment> segments,
  double descentRate = 18.0,
  double ascentRate = 9.0,
}) => domain.DivePlan(
  id: 'p',
  name: 'rate split',
  gfLow: 50,
  gfHigh: 80,
  tanks: const [
    DiveTank(id: 'back', volume: 11.1, startPressure: 200, gasMix: _gas),
  ],
  segments: segments,
  descentRate: descentRate,
  ascentRate: ascentRate,
  createdAt: DateTime(2026, 10, 11),
  updatedAt: DateTime(2026, 10, 11),
);

void main() {
  test('a segment with the flag off is returned exactly as it is', () {
    final segments = [_seg('s1', 100, durationSeconds: 600)];
    final result = expandRateSplitSegments(segments, _plan(segments: segments));
    expect(result, [segments[0]]);
  });

  test('a level segment (no depth change) is never split, flag or not', () {
    final segments = [
      _seg('s1', 100, durationSeconds: 300),
      _seg('s2', 100, durationSeconds: 600, splitAtConfiguredRate: true),
    ];
    final result = expandRateSplitSegments(segments, _plan(segments: segments));
    expect(result, hasLength(2));
    expect(result[1], segments[1]);
  });

  test('a descent split at 18 m/min: 100 m takes 333 s, remainder becomes '
      'a new hold segment', () {
    final segments = [
      _seg('s1', 100, durationSeconds: 600, splitAtConfiguredRate: true),
    ];
    final result = expandRateSplitSegments(segments, _plan(segments: segments));
    expect(result, hasLength(2));

    final travel = result[0];
    expect(travel.id, 's1', reason: 'travel half keeps the original id');
    expect(travel.targetDepth, 100);
    expect(travel.durationSeconds, 333); // (100/18*60).round()

    final hold = result[1];
    expect(hold.id, isNot('s1'));
    expect(hold.targetDepth, 100);
    expect(hold.durationSeconds, 600 - 333);
    expect(hold.tankId, travel.tankId);
    expect(hold.gasMix, travel.gasMix);
    expect(hold.splitAtConfiguredRate, isFalse);
  });

  test('an ascent splits at the ascent rate, not the descent rate', () {
    final segments = [
      _seg('s1', 60, durationSeconds: 1200), // the bottom, unsplit
      _seg(
        's2',
        30,
        durationSeconds: 300,
        splitAtConfiguredRate: true,
        order: 1,
      ), // ascending 60 -> 30 at 9 m/min = 200 s
    ];
    final result = expandRateSplitSegments(
      segments,
      _plan(segments: segments, ascentRate: 9.0),
    );
    expect(result, hasLength(3));
    expect(result[1].durationSeconds, 200); // (30/9*60).round()
    expect(result[2].durationSeconds, 300 - 200);
    expect(result[2].targetDepth, 30);
  });

  test('a configured rate slower than the entered duration stretches the '
      'segment to the travel time instead of silently ignoring the rate '
      '(#3130)', () {
    // 100 m at 1 m/min takes 6000 s, far more than the 600 s entered: there
    // is no remainder to hold, but the rate still has to govern -- the
    // diver checked the box precisely because 600 s is too fast for that
    // rate, so cutting the travel short back to 600 s would undo the whole
    // point of the checkbox.
    final segments = [
      _seg('s1', 100, durationSeconds: 600, splitAtConfiguredRate: true),
    ];
    final result = expandRateSplitSegments(
      segments,
      _plan(segments: segments, descentRate: 1.0),
    );
    expect(result, hasLength(1));
    expect(result[0].id, 's1');
    expect(result[0].targetDepth, 100);
    expect(result[0].durationSeconds, 6000);
  });

  test(
    'exactly matching durations also stay travel-only (no zero-length hold)',
    () {
      // 100 m at 10 m/min takes exactly 600 s -- the same as the entered
      // duration, so there is no remainder, and the duration is already
      // the travel time.
      final segments = [
        _seg('s1', 100, durationSeconds: 600, splitAtConfiguredRate: true),
      ];
      final result = expandRateSplitSegments(
        segments,
        _plan(segments: segments, descentRate: 10.0),
      );
      expect(result, hasLength(1));
      expect(result[0].durationSeconds, 600);
    },
  );

  test('later segments still start from the right depth after an earlier '
      'split', () {
    final segments = [
      _seg('s1', 100, durationSeconds: 600, splitAtConfiguredRate: true),
      _seg('s2', 100, durationSeconds: 1200, order: 1), // bottom, unsplit
    ];
    final result = expandRateSplitSegments(segments, _plan(segments: segments));
    expect(result, hasLength(3));
    expect(result[2].targetDepth, 100);
    expect(result[2].durationSeconds, 1200);
  });
}
