import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/segment_phase.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';

const _air = GasMix(o2: 21, he: 0);
const _chain = SegmentChain();

PlanSegment _seg(double targetDepth, int minutes, {String tank = 't1'}) =>
    PlanSegment(
      id: 's$targetDepth-$minutes-$tank',
      targetDepth: targetDepth,
      durationSeconds: minutes * 60,
      tankId: tank,
      gasMix: _air,
    );

void main() {
  group('SegmentChain.resolve', () {
    test('returns nothing for an empty plan', () {
      expect(_chain.resolve(const []), isEmpty);
    });

    test('the first leg starts at the surface', () {
      final legs = _chain.resolve([_seg(30, 3)]);

      expect(legs.single.startDepth, 0.0);
      expect(legs.single.endDepth, 30.0);
      expect(legs.single.phase, SegmentPhase.descent);
    });

    test('each leg starts where the previous one finished', () {
      final legs = _chain.resolve([_seg(30, 3), _seg(30, 20), _seg(6, 3)]);

      expect(legs.map((l) => l.startDepth), [0.0, 30.0, 30.0]);
      expect(legs.map((l) => l.endDepth), [30.0, 30.0, 6.0]);
    });

    test('classifies a standard square profile', () {
      final legs = _chain.resolve([
        _seg(30, 3), // descend
        _seg(30, 20), // bottom
        _seg(6, 3), // ascend
        _seg(6, 5), // stop
      ]);

      expect(legs.map((l) => l.phase), [
        SegmentPhase.descent,
        SegmentPhase.level,
        SegmentPhase.ascent,
        SegmentPhase.stop,
      ]);
    });

    test('a flat leg at the deepest point is the bottom, not a stop', () {
      final legs = _chain.resolve([_seg(30, 3), _seg(30, 20)]);

      expect(legs.last.phase, SegmentPhase.level);
    });

    test('a flat leg that later drops deeper is another bottom', () {
      // Multi-level: 20 m for a while, then down to 25 m. The 20 m leg is
      // working depth, not a stop, because the dive is not on its way up yet.
      final legs = _chain.resolve([
        _seg(20, 2),
        _seg(20, 15),
        _seg(25, 1),
        _seg(25, 10),
        _seg(5, 2),
        _seg(5, 3),
      ]);

      expect(legs.map((l) => l.phase), [
        SegmentPhase.descent,
        SegmentPhase.level,
        SegmentPhase.descent,
        SegmentPhase.level,
        SegmentPhase.ascent,
        SegmentPhase.stop,
      ]);
    });

    test('a flat leg on the way up is a stop', () {
      final legs = _chain.resolve([
        _seg(40, 4),
        _seg(40, 10),
        _seg(21, 2),
        _seg(21, 1), // gas switch held at 21 m
        _seg(6, 2),
        _seg(6, 8),
      ]);

      expect(legs[3].phase, SegmentPhase.stop);
      expect(legs[5].phase, SegmentPhase.stop);
    });

    test('a repeated target depth with no descent is still level', () {
      // Two consecutive holds at the same depth: the second must not read as
      // a stop just because it is flat.
      final legs = _chain.resolve([_seg(18, 2), _seg(18, 10), _seg(18, 10)]);

      expect(legs[1].phase, SegmentPhase.level);
      expect(legs[2].phase, SegmentPhase.level);
    });

    test('a surfacing leg is an ascent', () {
      final legs = _chain.resolve([_seg(12, 1), _seg(12, 30), _seg(0, 2)]);

      expect(legs.last.phase, SegmentPhase.ascent);
      expect(legs.last.endDepth, 0.0);
    });
  });

  group('ResolvedLeg geometry', () {
    test('avgDepth and deeperEnd span the leg', () {
      final legs = _chain.resolve([_seg(30, 3), _seg(10, 2)]);

      expect(legs.first.avgDepth, 15.0);
      expect(legs.first.deeperEnd, 30.0);
      expect(legs.last.avgDepth, 20.0);
      expect(legs.last.deeperEnd, 30.0);
    });

    test('rate is signed: positive descending, negative ascending', () {
      final legs = _chain.resolve([_seg(36, 2), _seg(36, 10), _seg(18, 2)]);

      expect(legs[0].rate, 18.0);
      expect(legs[1].rate, 0.0);
      expect(legs[2].rate, -9.0);
    });

    test('rate is null when the leg has no duration', () {
      final legs = _chain.resolve([_seg(30, 0)]);

      expect(legs.single.rate, isNull);
    });

    test('isDepthChange follows the geometry', () {
      final legs = _chain.resolve([_seg(30, 3), _seg(30, 20)]);

      expect(legs.first.isDepthChange, isTrue);
      expect(legs.last.isDepthChange, isFalse);
    });
  });

  group('ResolvedLeg runtime', () {
    test('accumulates across legs and ends at the total', () {
      final legs = _chain.resolve([
        _seg(30, 3),
        _seg(30, 20),
        _seg(6, 3),
        _seg(6, 5),
      ]);

      expect(legs.map((l) => l.runtimeSeconds), [
        3 * 60,
        23 * 60,
        26 * 60,
        31 * 60,
      ]);
    });

    test('startRuntimeSeconds is when the leg begins', () {
      final legs = _chain.resolve([_seg(30, 3), _seg(30, 20)]);

      expect(legs[0].startRuntimeSeconds, 0);
      expect(legs[1].startRuntimeSeconds, 3 * 60);
    });

    test('a zero-duration leg does not advance the clock', () {
      final legs = _chain.resolve([_seg(30, 3), _seg(30, 0), _seg(30, 10)]);

      expect(legs.map((l) => l.runtimeSeconds), [180, 180, 780]);
    });
  });

  group('SegmentChain.bottomLegIndex', () {
    test('finds the single level leg', () {
      final legs = _chain.resolve([_seg(30, 3), _seg(30, 20), _seg(0, 3)]);

      expect(_chain.bottomLegIndex(legs), 1);
    });

    test('picks the deepest level leg in a multi-level profile', () {
      final legs = _chain.resolve([
        _seg(20, 2),
        _seg(20, 15),
        _seg(25, 1),
        _seg(25, 10),
        _seg(0, 3),
      ]);

      expect(_chain.bottomLegIndex(legs), 3);
    });

    test('the last of two equally deep level legs wins', () {
      final legs = _chain.resolve([
        _seg(30, 3),
        _seg(30, 10),
        _seg(30, 10),
        _seg(0, 3),
      ]);

      expect(_chain.bottomLegIndex(legs), 2);
    });

    test('is null when the diver authored no level leg', () {
      final legs = _chain.resolve([_seg(30, 3), _seg(0, 4)]);

      expect(_chain.bottomLegIndex(legs), isNull);
    });

    test('ignores stops', () {
      final legs = _chain.resolve([
        _seg(30, 3),
        _seg(30, 20),
        _seg(6, 3),
        _seg(6, 10),
      ]);

      expect(_chain.bottomLegIndex(legs), 1);
    });
  });

  group('SegmentPhase', () {
    test('flat phases are the level ones', () {
      expect(SegmentPhase.level.isFlat, isTrue);
      expect(SegmentPhase.stop.isFlat, isTrue);
      expect(SegmentPhase.descent.isFlat, isFalse);
      expect(SegmentPhase.ascent.isFlat, isFalse);
      expect(SegmentPhase.descent.isDepthChange, isTrue);
      expect(SegmentPhase.level.isDepthChange, isFalse);
    });
  });

  group('ResolvedLeg equality', () {
    final segment = _seg(30, 3);

    ResolvedLeg leg({double startDepth = 0.0, int runtimeSeconds = 180}) =>
        ResolvedLeg(
          segment: segment,
          startDepth: startDepth,
          phase: SegmentPhase.descent,
          runtimeSeconds: runtimeSeconds,
        );

    test('legs with the same segment and geometry are equal', () {
      expect(leg(), equals(leg()));
      expect(leg().hashCode, leg().hashCode);
    });

    test('a different startDepth breaks equality', () {
      expect(leg(), isNot(equals(leg(startDepth: 10.0))));
    });

    test('a different runtimeSeconds breaks equality', () {
      expect(leg(), isNot(equals(leg(runtimeSeconds: 240))));
    });

    test('resolving the same plan twice yields equal legs', () {
      final plan = [_seg(30, 3), _seg(30, 20), _seg(6, 3)];

      expect(_chain.resolve(plan), equals(_chain.resolve(plan)));
    });
  });
}
