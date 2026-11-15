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
///
/// The columns span [width] from [left], so the wide pair can lay out each
/// figure in its own half of the box ([pairLabelColumns]).
List<FigureLabelSlot> labelColumns({
  required FigureModel model,
  required FigureView view,
  required FigureLayout layout,
  required double width,
  double left = 0,
  double labelHeight = kFigureLabelHeight,
}) {
  final figure = layout.rectFor(view);
  final items = [
    for (final p in model.placed)
      if (p.zone!.view == view) p,
  ]..sort(_byNumber);
  final leftColumn = <PlacedItem>[];
  final right = <PlacedItem>[];
  for (final p in items) {
    if (_onCentre(p)) {
      (leftColumn.length <= right.length ? leftColumn : right).add(p);
    } else if (_leftOfCentre(p)) {
      leftColumn.add(p);
    } else {
      right.add(p);
    }
  }
  final rightX = figure.right + kFigureLeaderGap;
  return [
    ..._stack(
      leftColumn,
      view,
      layout,
      x: left,
      columnWidth: math.max(0, figure.left - kFigureLeaderGap - left),
      onLeft: true,
      labelHeight: labelHeight,
    ),
    ..._stack(
      right,
      view,
      layout,
      x: rightX,
      columnWidth: math.max(0, left + width - rightX),
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

/// Wide layout (spec 8.3): the front and back side by side, each in its
/// own half of the box with label columns either side of it, as the phone
/// lays out its one figure. [layout] is a [FigureLayout.forPair] of [width].
/// A label never lies across a figure (issue #4553); a name longer than its
/// column wraps to a second line, as in a phone column.
List<FigureLabelSlot> pairLabelColumns({
  required FigureModel model,
  required FigureLayout layout,
  required double width,
  double labelHeight = kFigureLabelHeight,
}) {
  final half = width / 2;
  assert(
    (layout.front.center.dx - half / 2).abs() < 0.5 &&
        (layout.back.center.dx - half * 1.5).abs() < 0.5,
    'layout must be a FigureLayout.forPair of the same width',
  );
  return [
    for (final view in FigureView.values)
      ...labelColumns(
        model: model,
        view: view,
        layout: layout,
        width: half,
        left: view == FigureView.front ? 0 : half,
        labelHeight: labelHeight,
      ),
  ];
}
