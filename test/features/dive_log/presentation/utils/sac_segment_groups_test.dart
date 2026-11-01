import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_segment_groups.dart';

SacSegment _segment(
  int start,
  int end, {
  double sacRate = 1.0,
  double avgDepth = 10.0,
  DivePhase? phase,
  String? tankId,
  String? tankName,
}) => SacSegment(
  startTimestamp: start,
  endTimestamp: end,
  avgDepth: avgDepth,
  minDepth: 0.0,
  maxDepth: 30.0,
  sacRate: sacRate,
  gasConsumed: 1.0,
  phase: phase,
  tankId: tankId,
  tankName: tankName,
);

void main() {
  group('groupSegmentsByPhase', () {
    test('merges a phase split by another, in first-seen order', () {
      final groups = groupSegmentsByPhase([
        _segment(0, 60, phase: DivePhase.descent),
        _segment(60, 600, phase: DivePhase.bottom),
        _segment(600, 660, phase: DivePhase.ascent),
        _segment(660, 840, phase: DivePhase.safetyStop),
        _segment(840, 900, phase: DivePhase.ascent),
      ]);

      expect(groups.map((g) => g.phase), [
        DivePhase.descent,
        DivePhase.bottom,
        DivePhase.ascent,
        DivePhase.safetyStop,
      ]);
    });

    test('counts only the time spent in the phase', () {
      final ascent = groupSegmentsByPhase([
        _segment(600, 660, phase: DivePhase.ascent),
        _segment(660, 840, phase: DivePhase.safetyStop),
        _segment(840, 900, phase: DivePhase.ascent),
      ]).first;

      // 60s + 60s, not the 300s between the first start and the last end.
      expect(ascent.durationSeconds, 120);
    });

    test('weights depth by duration', () {
      final group = groupSegmentsByPhase([
        _segment(0, 60, avgDepth: 30, phase: DivePhase.bottom),
        _segment(60, 240, avgDepth: 10, phase: DivePhase.bottom),
      ]).single;

      expect(group.avgDepth, closeTo(15.0, 1e-9));
    });

    test('leaves out a segment with no phase', () {
      expect(groupSegmentsByPhase([_segment(0, 60)]), isEmpty);
    });

    test('zero-length segments average evenly instead of dividing by 0', () {
      final group = groupSegmentsByPhase([
        _segment(60, 60, avgDepth: 20, phase: DivePhase.deco),
        _segment(60, 60, avgDepth: 10, phase: DivePhase.deco),
      ]).single;

      expect(group.avgDepth, closeTo(15.0, 1e-9));
    });
  });

  group('gasSectionRows', () {
    test('lists every cylinder on a multi-cylinder dive', () {
      final rows = gasSectionRows([
        _segment(0, 600, tankId: 'back', tankName: 'Back'),
        _segment(600, 900, tankId: 'stage', tankName: 'Stage'),
      ]);

      expect(rows.map((g) => g.label), ['Back', 'Stage']);
    });

    test('is empty on a dive that stayed on one cylinder', () {
      expect(
        gasSectionRows([_segment(0, 600, tankId: 'back', tankName: 'Back')]),
        isEmpty,
      );
    });
  });

  group('groupSegmentsByCylinder', () {
    test('merges repeat visits to a cylinder', () {
      final groups = groupSegmentsByCylinder([
        _segment(0, 600, tankId: 'left', tankName: 'Left'),
        _segment(600, 1200, tankId: 'right', tankName: 'Right'),
        _segment(1200, 1800, tankId: 'left', tankName: 'Left'),
      ]);

      expect(groups.map((g) => g.label), ['Left', 'Right']);
      expect(groups.first.durationSeconds, 1200);
    });

    test('keeps two cylinders with the same name apart', () {
      final groups = groupSegmentsByCylinder([
        _segment(0, 600, tankId: 'a', tankName: 'AL80'),
        _segment(600, 1200, tankId: 'b', tankName: 'AL80'),
      ]);

      expect(groups, hasLength(2));
    });
  });

  group('containsTimestamp', () {
    final group = groupSegmentsByPhase([
      _segment(0, 60, phase: DivePhase.ascent),
      _segment(120, 180, phase: DivePhase.ascent),
    ]).single;

    test('is true inside either stretch', () {
      expect(group.containsTimestamp(30), isTrue);
      expect(group.containsTimestamp(150), isTrue);
    });

    test('is false in the gap between stretches', () {
      expect(group.containsTimestamp(90), isFalse);
    });

    test('includes both ends', () {
      expect(group.containsTimestamp(0), isTrue);
      expect(group.containsTimestamp(180), isTrue);
    });
  });
}
