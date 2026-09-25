import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_space.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';

/// A label's height, which is also its tap target.
const double kFigureLabelHeight = 40;

/// Vertical space between stacked labels.
const double kFigureLabelGap = 2;

/// Space between a label and the figure or anchor it points at.
const double kFigureLeaderGap = 8;

/// Where one item's label sits, and the anchor its leader line points at.
class FigureLabelSlot {
  const FigureLabelSlot({
    required this.item,
    required this.rect,
    required this.anchor,
    required this.onLeft,
  });

  final PlacedItem item;
  final Rect rect;
  final Offset anchor;

  /// Whether the label sits left of its anchor, so its leader leaves the
  /// label's right edge.
  final bool onLeft;
}

bool _onCentre(PlacedItem p) =>
    (p.zone!.anchorX - kFigureWidth / 2).abs() <= 0.5;

bool _leftOfCentre(PlacedItem p) => p.zone!.anchorX < kFigureWidth / 2 - 0.5;

int _byNumber(PlacedItem a, PlacedItem b) => a.number.compareTo(b.number);

/// Phone layout (spec 8.2): labels for one [view] in columns either side of
/// the single figure, each level with its anchor unless that would overlap
/// the label above, in which case it moves down just enough.
List<FigureLabelSlot> labelColumns({
  required FigureModel model,
  required FigureView view,
  required FigureLayout layout,
  required double width,
  double labelHeight = kFigureLabelHeight,
}) {
  final figure = layout.rectFor(view);
  final items = [
    for (final p in model.placed)
      if (p.zone!.view == view) p,
  ]..sort(_byNumber);
  final left = <PlacedItem>[];
  final right = <PlacedItem>[];
  for (final p in items) {
    if (_onCentre(p)) {
      (left.length <= right.length ? left : right).add(p);
    } else if (_leftOfCentre(p)) {
      left.add(p);
    } else {
      right.add(p);
    }
  }
  final rightX = figure.right + kFigureLeaderGap;
  return [
    ..._stack(
      left,
      view,
      layout,
      x: 0,
      columnWidth: math.max(0, figure.left - kFigureLeaderGap),
      onLeft: true,
      labelHeight: labelHeight,
    ),
    ..._stack(
      right,
      view,
      layout,
      x: rightX,
      columnWidth: math.max(0, width - rightX),
      onLeft: false,
      labelHeight: labelHeight,
    ),
  ];
}

List<FigureLabelSlot> _stack(
  List<PlacedItem> column,
  FigureView view,
  FigureLayout layout, {
  required double x,
  required double columnWidth,
  required bool onLeft,
  required double labelHeight,
}) {
  final anchored =
      [
        for (final p in column)
          (
            item: p,
            anchor: layout.toBox(view, p.zone!.anchorX, p.zone!.anchorY),
          ),
      ]..sort((a, b) {
        final byHeight = a.anchor.dy.compareTo(b.anchor.dy);
        return byHeight != 0 ? byHeight : _byNumber(a.item, b.item);
      });
  final slots = <FigureLabelSlot>[];
  var nextTop = 0.0;
  for (final entry in anchored) {
    final top = math.max(nextTop, entry.anchor.dy - labelHeight / 2);
    slots.add(
      FigureLabelSlot(
        item: entry.item,
        rect: Rect.fromLTWH(x, top, columnWidth, labelHeight),
        anchor: entry.anchor,
        onLeft: onLeft,
      ),
    );
    nextTop = top + labelHeight + kFigureLabelGap;
  }
  return slots;
}

/// Wide layout (spec 8.3): a pill beside every placed item on the outward
/// side of its anchor, placed in number order at the nearest row, above or
/// below its anchor, that clears the pills already placed. [widthOf] is the pill's natural width;
/// it is capped at [maxWidth] and at the room between the anchor and the
/// edge of the box, or the edge of the other figure when that is nearer, so
/// a pill never lies across the other view.
List<FigureLabelSlot> labelPills({
  required FigureModel model,
  required FigureLayout layout,
  required double width,
  required double maxWidth,
  required double Function(PlacedItem item) widthOf,
  double labelHeight = kFigureLabelHeight,
}) {
  final items = [...model.placed]..sort(_byNumber);
  final taken = <Rect>[];
  final slots = <FigureLabelSlot>[];
  for (final p in items) {
    final zone = p.zone!;
    final anchor = layout.toBox(zone.view, zone.anchorX, zone.anchorY);
    final onLeft = _leftOfCentre(p);
    final own = layout.rectFor(zone.view);
    final other = zone.view == FigureView.front ? layout.back : layout.front;
    var leftLimit = 0.0;
    var rightLimit = width;
    if (other != own) {
      if (other.left >= own.right) {
        rightLimit = other.left - kFigureLeaderGap;
      } else {
        leftLimit = other.right + kFigureLeaderGap;
      }
    }
    final room = onLeft
        ? anchor.dx - kFigureLeaderGap - leftLimit
        : rightLimit - anchor.dx - kFigureLeaderGap;
    final w = math.max(0.0, math.min(math.min(widthOf(p), maxWidth), room));
    final x = onLeft
        ? anchor.dx - kFigureLeaderGap - w
        : anchor.dx + kFigureLeaderGap;
    final level = Rect.fromLTWH(
      x,
      math.max(0, anchor.dy - labelHeight / 2),
      w,
      labelHeight,
    );
    final rect = _nearestFreeRow(level, taken, labelHeight + kFigureLabelGap);
    taken.add(rect);
    slots.add(
      FigureLabelSlot(item: p, rect: rect, anchor: anchor, onLeft: onLeft),
    );
  }
  return slots;
}

/// [level] itself if nothing overlaps it; otherwise the free position
/// nearest to it, trying each spot flush against the edge of a pill in the
/// way (just below it or just above it), never above the top of the box.
/// If none of those is free it falls back to stepping down a row at a time,
/// which always ends because the rows below are empty.
Rect _nearestFreeRow(Rect level, List<Rect> taken, double step) {
  bool free(Rect r) => r.top >= 0 && !taken.any((t) => t.overlaps(r));
  if (free(level)) return level;
  final gap = step - level.height;
  final candidates = <Rect>[
    for (final t in taken)
      if (t.left < level.right && level.left < t.right) ...[
        Rect.fromLTWH(level.left, t.bottom + gap, level.width, level.height),
        Rect.fromLTWH(
          level.left,
          t.top - gap - level.height,
          level.width,
          level.height,
        ),
      ],
  ].where(free).toList();
  if (candidates.isNotEmpty) {
    double distance(Rect r) => (r.center.dy - level.center.dy).abs();
    candidates.sort((a, b) => distance(a).compareTo(distance(b)));
    return candidates.first;
  }
  var rect = level;
  while (!free(rect)) {
    rect = rect.shift(Offset(0, step));
  }
  return rect;
}
