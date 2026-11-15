import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/render_box_children.dart';

/// Lays its children out side by side in equal-width columns, each as tall
/// as the tallest.
///
/// Each child is first laid out at its column width and its natural height.
/// Every child shorter than the tallest is then laid out again with that
/// height as a tight constraint, so a [Card] at its root grows to fill the
/// row, its content staying at the top, and no blank space is left under it
/// before whatever follows the row (issue #4583).
///
/// An [IntrinsicHeight] around a stretched [Row] would reach the same shape,
/// but it asks every descendant for its intrinsic height first, which a
/// [LayoutBuilder] (a map, a chart) cannot answer. This never asks: the
/// price is a second layout of the shorter children.
///
/// The first pass offers the height this row is offered, which inside a
/// scroll view is unbounded, so a child must cope with that the way it would
/// in a [Column]: no [Expanded] at its root.
class EqualHeightRow extends MultiChildRenderObjectWidget {
  const EqualHeightRow({super.key, this.gap = 0, super.children});

  /// The horizontal space between neighbouring columns.
  final double gap;

  @override
  RenderEqualHeightRow createRenderObject(BuildContext context) =>
      RenderEqualHeightRow(gap: gap, textDirection: Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    RenderEqualHeightRow renderObject,
  ) {
    renderObject
      ..gap = gap
      ..textDirection = Directionality.of(context);
  }
}

/// Parent data for the children of a [RenderEqualHeightRow].
class EqualHeightRowParentData extends ContainerBoxParentData<RenderBox> {}

/// The render object behind [EqualHeightRow].
class RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, EqualHeightRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, EqualHeightRowParentData> {
  RenderEqualHeightRow({
    required double gap,
    required TextDirection textDirection,
  }) : _gap = gap,
       _textDirection = textDirection;

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  /// Which side the first child sits on: the left for left to right.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! EqualHeightRowParentData) {
      child.parentData = EqualHeightRowParentData();
    }
  }

  double get _totalGap => gap * math.max(0, childCount - 1);

  /// The width each column gets out of [width].
  double _columnWidth(double width) =>
      childCount == 0 ? 0 : math.max(0, (width - _totalGap) / childCount);

  // The columns are equal, so the row needs every column as wide as the
  // widest child needs, as a Row of Expanded children does.
  @override
  double computeMinIntrinsicWidth(double height) =>
      largestOfChildren((c) => c.getMinIntrinsicWidth(height)) * childCount +
      _totalGap;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      largestOfChildren((c) => c.getMaxIntrinsicWidth(height)) * childCount +
      _totalGap;

  @override
  double computeMinIntrinsicHeight(double width) =>
      largestOfChildren((c) => c.getMinIntrinsicHeight(_columnWidth(width)));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      largestOfChildren((c) => c.getMaxIntrinsicHeight(_columnWidth(width)));

  /// What each child is first offered: its column's width, and any height up
  /// to what the row is offered.
  BoxConstraints _naturalConstraints(BoxConstraints constraints) {
    final width = _columnWidth(constraints.maxWidth);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    assert(constraints.hasBoundedWidth, 'EqualHeightRow needs a bounded width');
    final natural = _naturalConstraints(constraints);
    final tallest = largestOfChildren((c) => c.getDryLayout(natural).height);
    return constraints.constrain(Size(constraints.maxWidth, tallest));
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    assert(constraints.hasBoundedWidth, 'EqualHeightRow needs a bounded width');
    final width = constraints.maxWidth;
    final natural = _naturalConstraints(constraints);
    final columnWidth = natural.maxWidth;

    var child = firstChild;
    while (child != null) {
      child.layout(natural, parentUsesSize: true);
      child = childAfter(child);
    }
    final height = constraints.constrainHeight(
      largestOfChildren((c) => c.size.height),
    );
    // A minimum, not a tight height: tight constraints would make the child
    // its own relayout boundary, and content that grows inside it later (a
    // tide record arriving) would relayout it at this stale height without
    // telling the row.
    final fill = natural.copyWith(minHeight: height);

    var index = 0;
    child = firstChild;
    while (child != null) {
      if (child.size.height < height) {
        child.layout(fill, parentUsesSize: true);
      }
      final start = index * (columnWidth + gap);
      final dx = switch (textDirection) {
        TextDirection.ltr => start,
        TextDirection.rtl => width - columnWidth - start,
      };
      (child.parentData! as EqualHeightRowParentData).offset = Offset(dx, 0);
      index++;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
