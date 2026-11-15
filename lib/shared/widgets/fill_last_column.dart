import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Stacks its children full width, like a [Column] with
/// `CrossAxisAlignment.stretch`, and gives any height it is made to fill
/// beyond theirs to the last child.
///
/// Offered a loose height, as in a scroll view, it is exactly as tall as its
/// children. Made taller, by a `PairedCardsRow` matching a taller card
/// beside it, its last child is laid out again that much taller, so a stack
/// of cards ends level with its neighbour instead of leaving blank space
/// under it (issue #4583).
///
/// A [Column] cannot do this: an [Expanded] last child would need a bounded
/// height in every layout, and a scroll view offers none.
class FillLastColumn extends MultiChildRenderObjectWidget {
  const FillLastColumn({super.key, super.children});

  @override
  RenderFillLastColumn createRenderObject(BuildContext context) =>
      RenderFillLastColumn();
}

/// Parent data for the children of a [RenderFillLastColumn].
class FillLastColumnParentData extends ContainerBoxParentData<RenderBox> {}

/// The render object behind [FillLastColumn].
class RenderFillLastColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, FillLastColumnParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, FillLastColumnParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! FillLastColumnParentData) {
      child.parentData = FillLastColumnParentData();
    }
  }

  double _sum(double Function(RenderBox child) measure) {
    var sum = 0.0;
    var child = firstChild;
    while (child != null) {
      sum += measure(child);
      child = childAfter(child);
    }
    return sum;
  }

  double _largest(double Function(RenderBox child) measure) {
    var largest = 0.0;
    var child = firstChild;
    while (child != null) {
      largest = math.max(largest, measure(child));
      child = childAfter(child);
    }
    return largest;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _largest((c) => c.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _largest((c) => c.getMaxIntrinsicWidth(double.infinity));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _sum((c) => c.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _sum((c) => c.getMaxIntrinsicHeight(width));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    assert(constraints.hasBoundedWidth, 'FillLastColumn needs a bounded width');
    final child = BoxConstraints.tightFor(width: constraints.maxWidth);
    final height = _sum((c) => c.getDryLayout(child).height);
    return constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    assert(constraints.hasBoundedWidth, 'FillLastColumn needs a bounded width');
    final width = constraints.maxWidth;
    final natural = BoxConstraints.tightFor(width: width);

    var child = firstChild;
    while (child != null) {
      child.layout(natural, parentUsesSize: true);
      child = childAfter(child);
    }
    final stacked = _sum((c) => c.size.height);
    final height = constraints.constrainHeight(stacked);
    final last = lastChild;
    if (last != null && height > stacked) {
      // A minimum, not a tight height: tight constraints would make the
      // child its own relayout boundary, and content that grows inside it
      // later (a signature loading) would relayout it at this stale height
      // without telling the column.
      last.layout(
        natural.copyWith(minHeight: last.size.height + height - stacked),
        parentUsesSize: true,
      );
    }

    var y = 0.0;
    child = firstChild;
    while (child != null) {
      (child.parentData! as FillLastColumnParentData).offset = Offset(0, y);
      y += child.size.height;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
