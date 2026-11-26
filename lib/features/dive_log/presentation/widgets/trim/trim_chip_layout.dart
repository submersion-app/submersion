import 'dart:math' as math;
import 'dart:ui';

/// A chip the trim figure wants to show (issue #5028): its element, the
/// point on the figure it names, its measured size, and whether it belongs
/// above the figure (gear on the back) or below it.
class TrimChipRequest {
  const TrimChipRequest({
    required this.elementId,
    required this.anchor,
    required this.size,
    required this.above,
  });

  final String elementId;
  final Offset anchor;
  final Size size;
  final bool above;
}

class TrimChipPlacement {
  const TrimChipPlacement({
    required this.elementId,
    required this.anchor,
    required this.rect,
  });

  final String elementId;
  final Offset anchor;
  final Rect rect;
}

class TrimChipLayout {
  const TrimChipLayout(this.chips);

  final List<TrimChipPlacement> chips;

  /// The highest top and lowest bottom of any chip; the figure's own box
  /// when there are none.
  double topOf(double figureTop) =>
      chips.fold(figureTop, (t, c) => math.min(t, c.rect.top));
  double bottomOf(double figureBottom) =>
      chips.fold(figureBottom, (b, c) => math.max(b, c.rect.bottom));
}

/// Packs chips into rows above and below the figure so no two overlap.
///
/// Each band is filled left to right by anchor: a chip is centred on its
/// anchor (clamped to [width]) and goes in the first row it fits beside the
/// last chip of, else a new row further from the figure.
TrimChipLayout packTrimChips(
  List<TrimChipRequest> requests, {
  required double width,
  required double figureTop,
  required double figureBottom,
  double gap = 4,
}) {
  final placed = <TrimChipPlacement>[];
  for (final above in const [true, false]) {
    final band = [
      for (final r in requests)
        if (r.above == above) r,
    ]..sort((a, b) => a.anchor.dx.compareTo(b.anchor.dx));
    final rowRight = <double>[];
    final rowExtent = <double>[];
    for (final r in band) {
      final w = math.min(r.size.width, width);
      final left = (r.anchor.dx - w / 2).clamp(0.0, width - w);
      var row = rowRight.indexWhere((right) => left >= right + gap);
      if (row < 0) {
        row = rowRight.length;
        rowRight.add(double.negativeInfinity);
        final before = row == 0
            ? (above ? figureTop - gap : figureBottom + gap)
            : rowExtent[row - 1];
        rowExtent.add(
          above ? before - r.size.height - gap : before + r.size.height + gap,
        );
      }
      rowRight[row] = left + w;
      final edge = rowExtent[row];
      final top = above ? edge + gap : edge - r.size.height - gap;
      placed.add(
        TrimChipPlacement(
          elementId: r.elementId,
          anchor: r.anchor,
          rect: Rect.fromLTWH(left, top, w, r.size.height),
        ),
      );
    }
  }
  return TrimChipLayout(placed);
}
