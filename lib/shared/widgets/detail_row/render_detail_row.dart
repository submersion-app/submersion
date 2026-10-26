import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';

/// The two children of a [DetailRowLayout].
enum DetailRowSlot { label, value }

/// Lays out a label cell and a value: the label cell in a column as wide
/// as the group's widest label (or this row's own, outside a group),
/// capped at [maxLabelShare] of the row, then [gap], then the value.
class DetailRowLayout
    extends SlottedMultiChildRenderObjectWidget<DetailRowSlot, RenderBox> {
  const DetailRowLayout({
    super.key,
    required this.label,
    required this.value,
    required this.column,
    required this.ownLabelWidth,
    required this.gap,
    required this.maxLabelShare,
  });

  final Widget label;
  final Widget value;
  final DetailLabelColumn? column;

  /// This row's label cell at its natural width.
  final double ownLabelWidth;
  final double gap;
  final double maxLabelShare;

  @override
  Iterable<DetailRowSlot> get slots => DetailRowSlot.values;

  @override
  Widget? childForSlot(DetailRowSlot slot) => switch (slot) {
    DetailRowSlot.label => label,
    DetailRowSlot.value => value,
  };

  @override
  RenderDetailRow createRenderObject(BuildContext context) => RenderDetailRow(
    column: column,
    ownLabelWidth: ownLabelWidth,
    gap: gap,
    maxLabelShare: maxLabelShare,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderDetailRow renderObject) {
    renderObject
      ..column = column
      ..ownLabelWidth = ownLabelWidth
      ..gap = gap
      ..maxLabelShare = maxLabelShare
      ..textDirection = Directionality.of(context);
  }
}

class RenderDetailRow extends RenderBox
    with SlottedContainerRenderObjectMixin<DetailRowSlot, RenderBox> {
  RenderDetailRow({
    required DetailLabelColumn? column,
    required double ownLabelWidth,
    required double gap,
    required double maxLabelShare,
    required TextDirection textDirection,
  }) : _column = column,
       _ownLabelWidth = ownLabelWidth,
       _gap = gap,
       _maxLabelShare = maxLabelShare,
       _textDirection = textDirection;

  DetailLabelColumn? _column;
  set column(DetailLabelColumn? value) {
    if (value == _column) return;
    if (attached) _leave();
    _column = value;
    if (attached) _join();
    markNeedsLayout();
  }

  double _ownLabelWidth;
  set ownLabelWidth(double value) {
    if (value == _ownLabelWidth) return;
    _ownLabelWidth = value;
    if (attached) _column?.report(this, value);
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _maxLabelShare;
  set maxLabelShare(double value) {
    if (value == _maxLabelShare) return;
    _maxLabelShare = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _label => childForSlot(DetailRowSlot.label);
  RenderBox? get _value => childForSlot(DetailRowSlot.value);

  void _join() {
    _column?.addListener(markNeedsLayout);
    _column?.report(this, _ownLabelWidth);
  }

  void _leave() {
    _column?.removeListener(markNeedsLayout);
    _column?.remove(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _join();
  }

  @override
  void detach() {
    _leave();
    super.detach();
  }

  /// The gap after a label column [column] wide: none when no row of the
  /// group has a label, so label-less rows start at the edge.
  double _gapAfter(double column) => column > 0 ? _gap : 0;

  /// The label column's width in a row [width] wide.
  double _columnWidth(double width) {
    final natural = math.max(_ownLabelWidth, _column?.width ?? 0);
    return width.isFinite ? math.min(natural, width * _maxLabelShare) : natural;
  }

  ({Size size, Size label, Size value, double column}) _computeLayout(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild,
  ) {
    final label = _label!;
    final value = _value!;
    final column = _columnWidth(constraints.maxWidth);
    final gap = _gapAfter(column);
    final labelSize = layoutChild(label, BoxConstraints(maxWidth: column));
    final valueMax = constraints.maxWidth.isFinite
        ? math.max(0.0, constraints.maxWidth - column - gap)
        : double.infinity;
    final valueSize = layoutChild(value, BoxConstraints(maxWidth: valueMax));
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : column + gap + valueSize.width;
    final size = constraints.constrain(
      Size(width, math.max(labelSize.height, valueSize.height)),
    );
    return (size: size, label: labelSize, value: valueSize, column: column);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _computeLayout(constraints, (child, c) => child.getDryLayout(c)).size;

  @override
  void performLayout() {
    final layout = _computeLayout(constraints, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    size = layout.size;
    final labelData = _label!.parentData! as BoxParentData;
    final valueData = _value!.parentData! as BoxParentData;
    final valueStart = layout.column + _gapAfter(layout.column);
    switch (_textDirection) {
      case TextDirection.ltr:
        labelData.offset = Offset.zero;
        valueData.offset = Offset(valueStart, 0);
      case TextDirection.rtl:
        labelData.offset = Offset(size.width - layout.label.width, 0);
        valueData.offset = Offset(
          size.width - valueStart - layout.value.width,
          0,
        );
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _label!.getMinIntrinsicWidth(height) +
      _gapAfter(_columnWidth(double.infinity)) +
      _value!.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) {
    final column = _columnWidth(double.infinity);
    return column + _gapAfter(column) + _value!.getMaxIntrinsicWidth(height);
  }

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) childHeight,
  ) {
    final column = _columnWidth(width);
    final valueWidth = width.isFinite
        ? math.max(0.0, width - column - _gapAfter(column))
        : double.infinity;
    return math.max(
      childHeight(_label!, column),
      childHeight(_value!, valueWidth),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMaxIntrinsicHeight(w));

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    // The label sits at the top of the row, so its own baseline is the row's.
    return _label!.getDryBaseline(
      BoxConstraints(maxWidth: _columnWidth(constraints.maxWidth)),
      baseline,
    );
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final label = _label!;
    final offset = (label.parentData! as BoxParentData).offset;
    final distance = label.getDistanceToActualBaseline(baseline);
    return distance == null ? null : distance + offset.dy;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in [_label!, _value!]) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in [_value!, _label!]) {
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
