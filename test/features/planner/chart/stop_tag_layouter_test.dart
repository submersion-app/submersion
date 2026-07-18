import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/stop_tag_layouter.dart';

void main() {
  const bounds = Rect.fromLTWH(0, 0, 400, 300);
  const tag = Size(44, 16);

  test('single tag sits just right and below its anchor', () {
    final rects = StopTagLayouter.layout(
      anchors: const [Offset(100, 100)],
      sizes: const [tag],
      bounds: bounds,
    );
    expect(rects.single.left, 106);
    expect(rects.single.top, 104);
  });

  test('dense stops never overlap and stay in bounds (15-stop trimix)', () {
    // 15 stops on a shallow staircase - anchors 12 px apart vertically,
    // tags 16 px tall: naive placement must collide.
    final anchors = [
      for (var i = 0; i < 15; i++) Offset(200 + i * 8.0, 60 + i * 12.0),
    ];
    final rects = StopTagLayouter.layout(
      anchors: anchors,
      sizes: List.filled(15, tag),
      bounds: bounds,
    );
    expect(rects.length, 15);
    for (var i = 0; i < rects.length; i++) {
      expect(rects[i].left, greaterThanOrEqualTo(bounds.left));
      expect(rects[i].right, lessThanOrEqualTo(bounds.right));
      expect(rects[i].top, greaterThanOrEqualTo(bounds.top));
      expect(rects[i].bottom, lessThanOrEqualTo(bounds.bottom));
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].overlaps(rects[j]),
          isFalse,
          reason: 'tag $i overlaps tag $j',
        );
      }
    }
  });

  test('tag near the right edge is pulled inside the bounds', () {
    final rects = StopTagLayouter.layout(
      anchors: const [Offset(395, 50)],
      sizes: const [tag],
      bounds: bounds,
    );
    expect(rects.single.right, lessThanOrEqualTo(bounds.right));
  });

  test('tags stay within vertical bounds even when forced to flip above', () {
    // Overcrowd a single column anchored near the top: placement fills
    // downward, runs out of room, flips above the anchor, then walks upward.
    // Without vertical clamping the flipped tags would paint above the top
    // edge (anchor.dy - 4 - height is negative here).
    final anchors = [for (var i = 0; i < 40; i++) const Offset(200, 8)];
    final rects = StopTagLayouter.layout(
      anchors: anchors,
      sizes: List.filled(40, tag),
      bounds: bounds,
    );
    for (final r in rects) {
      expect(r.top, greaterThanOrEqualTo(bounds.top));
      expect(r.bottom, lessThanOrEqualTo(bounds.bottom));
    }
  });
}
