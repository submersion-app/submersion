import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/safety_lane_layout.dart';

void main() {
  // Lane maps a 0..1000 s window onto 500 px: 1 px per 2 s.
  List<SafetyLaneChipPlacement> layout(
    List<({double startSeconds, double endSeconds})> ranges, {
    double visibleMin = 0,
    double visibleMax = 1000,
    double laneWidth = 500,
  }) {
    return layoutSafetyLaneChips(
      ranges: ranges,
      visibleMinSeconds: visibleMin,
      visibleMaxSeconds: visibleMax,
      laneWidth: laneWidth,
    );
  }

  test('a wide range maps to a proportional chip', () {
    final placements = layout([(startSeconds: 200.0, endSeconds: 400.0)]);
    expect(placements, hasLength(1));
    expect(placements.single.left, 100);
    expect(placements.single.width, 100);
    expect(placements.single.memberIndexes, [0]);
  });

  test('a short range gets the minimum chip width, centered', () {
    // 10 s -> 5 px extent (100..105 px), inflated to 26 px centered on
    // the 102.5 px midpoint: left = 102.5 - 13 = 89.5.
    final placements = layout([(startSeconds: 200.0, endSeconds: 210.0)]);
    expect(placements, hasLength(1));
    expect(placements.single.left, closeTo(89.5, 0.01));
    expect(placements.single.width, 26);
  });

  test('an instant range gets the minimum chip width', () {
    final placements = layout([(startSeconds: 500.0, endSeconds: 500.0)]);
    expect(placements, hasLength(1));
    expect(placements.single.width, 26);
    expect(placements.single.left, closeTo(250 - 13, 0.01));
  });

  test('a chip near the lane start is clamped inside the lane', () {
    final placements = layout([(startSeconds: 0.0, endSeconds: 0.0)]);
    expect(placements.single.left, 0);
    expect(placements.single.width, 26);
  });

  test('a chip near the lane end is clamped inside the lane', () {
    final placements = layout([(startSeconds: 1000.0, endSeconds: 1000.0)]);
    expect(placements.single.left, closeTo(500 - 26, 0.01));
    expect(placements.single.width, 26);
  });

  test('a range outside the visible window produces no chip', () {
    final placements = layout(
      [(startSeconds: 800.0, endSeconds: 900.0)],
      visibleMin: 0,
      visibleMax: 500,
    );
    expect(placements, isEmpty);
  });

  test('a range straddling the window edge is clamped to the edge', () {
    final placements = layout(
      [(startSeconds: 400.0, endSeconds: 600.0)],
      visibleMin: 0,
      visibleMax: 500,
      laneWidth: 500,
    );
    expect(placements, hasLength(1));
    expect(placements.single.left, 400);
    expect(placements.single.width, 100);
  });

  test('overlapping chips merge into one cluster in start order', () {
    // Two instants 10 s (5 px) apart: both inflate to 26 px and overlap.
    final placements = layout([
      (startSeconds: 510.0, endSeconds: 510.0),
      (startSeconds: 500.0, endSeconds: 500.0),
    ]);
    expect(placements, hasLength(1));
    expect(placements.single.memberIndexes, [1, 0]);
  });

  test('non-overlapping chips stay separate', () {
    final placements = layout([
      (startSeconds: 100.0, endSeconds: 100.0),
      (startSeconds: 900.0, endSeconds: 900.0),
    ]);
    expect(placements, hasLength(2));
  });

  test('empty window or lane yields nothing', () {
    expect(
      layout(
        [(startSeconds: 1.0, endSeconds: 2.0)],
        visibleMin: 5,
        visibleMax: 5,
      ),
      isEmpty,
    );
    expect(
      layout([(startSeconds: 1.0, endSeconds: 2.0)], laneWidth: 0),
      isEmpty,
    );
  });
}
