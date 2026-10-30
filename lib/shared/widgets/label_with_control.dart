import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A label with a width-hungry control after it, such as a dropdown or a
/// pair of text buttons, that moves the control onto its own line when the
/// two cannot share one.
///
/// A `Row` with the label in `Expanded` (or a `ListTile` with the control in
/// `trailing`) lays the control out first and gives the label what is left.
/// In a longer translation that left the label a few pixels, and it broke
/// one character per line (issue #3358). Here the label keeps the full width
/// when it needs it, and the control drops below it instead.
///
/// The control stays at the far end on either layout, so a row whose label
/// wraps still lines its control up with the rows around it (issue #3747). A
/// `Wrap` with `spaceBetween` put a control alone on its line at the start.
///
/// In a `ListTile`, pass this as the `title` and leave `trailing` empty. It
/// fills the width it is offered, so that width must be bounded.
class LabelWithControl extends StatelessWidget {
  const LabelWithControl({
    super.key,
    required this.label,
    required this.control,
  });

  /// Usually a [Text]. It wraps between words once it has a line of its own.
  ///
  /// Its single-line width is read as an intrinsic width to choose between
  /// the two layouts, so it cannot contain a widget without intrinsic sizes,
  /// such as a `LayoutBuilder`.
  final Widget label;

  /// Sits at the far end of the line when it fits beside [label], and at the
  /// far end of the next line when it does not.
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return _LabelWithControlLayout(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      children: [label, control],
    );
  }
}

/// The least gap between label and control on a shared line.
const double _spacing = 16;

/// The gap between the label and a control on the line below it.
const double _runSpacing = 4;

class _LabelWithControlLayout extends MultiChildRenderObjectWidget {
  const _LabelWithControlLayout({
    required this.textDirection,
    required super.children,
  });

  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLabelWithControl(textDirection);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLabelWithControl renderObject,
  ) {
    renderObject.textDirection = textDirection;
  }
}

class _LabelParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderLabelWithControl extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _LabelParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _LabelParentData> {
  _RenderLabelWithControl(this._textDirection);

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _label => firstChild!;
  RenderBox get _control => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LabelParentData) {
      child.parentData = _LabelParentData();
    }
  }

  /// Lays out (or, for a dry layout, only sizes) both children and returns
  /// the size, each child's offset, and the constraints each was given.
  ({
    Size size,
    Offset labelOffset,
    Offset controlOffset,
    BoxConstraints labelConstraints,
    BoxConstraints controlConstraints,
  })
  _arrange(BoxConstraints constraints, ChildLayouter layoutChild) {
    final controlConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    final control = layoutChild(_control, controlConstraints);
    final labelWidth = _label.getMaxIntrinsicWidth(double.infinity);
    final oneLine =
        labelWidth + _spacing + control.width <= constraints.maxWidth;
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : labelWidth + _spacing + control.width;

    // The label's start and the control's end, in either text direction.
    final rtl = textDirection == TextDirection.rtl;
    double labelX(Size label) => rtl ? width - label.width : 0;
    final controlX = rtl ? 0.0 : width - control.width;

    if (oneLine) {
      final labelConstraints = BoxConstraints(
        maxWidth: width - _spacing - control.width,
      );
      final label = layoutChild(_label, labelConstraints);
      final height = math.max(label.height, control.height);
      return (
        size: constraints.constrain(Size(width, height)),
        labelOffset: Offset(labelX(label), (height - label.height) / 2),
        controlOffset: Offset(controlX, (height - control.height) / 2),
        labelConstraints: labelConstraints,
        controlConstraints: controlConstraints,
      );
    }

    final labelConstraints = BoxConstraints(maxWidth: width);
    final label = layoutChild(_label, labelConstraints);
    final controlY = label.height + _runSpacing;
    return (
      size: constraints.constrain(Size(width, controlY + control.height)),
      labelOffset: Offset(labelX(label), 0),
      controlOffset: Offset(controlX, controlY),
      labelConstraints: labelConstraints,
      controlConstraints: controlConstraints,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final arranged = _arrange(constraints, ChildLayoutHelper.dryLayoutChild);
    var highest = BaselineOffset.noBaseline;
    for (final (child, childConstraints, offset) in [
      (_label, arranged.labelConstraints, arranged.labelOffset),
      (_control, arranged.controlConstraints, arranged.controlOffset),
    ]) {
      highest = highest.minOf(
        BaselineOffset(child.getDryBaseline(childConstraints, baseline)) +
            offset.dy,
      );
    }
    return highest.offset;
  }

  @override
  void performLayout() {
    final arranged = _arrange(constraints, ChildLayoutHelper.layoutChild);
    size = arranged.size;
    (_label.parentData! as _LabelParentData).offset = arranged.labelOffset;
    (_control.parentData! as _LabelParentData).offset = arranged.controlOffset;
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _label.getMinIntrinsicWidth(double.infinity),
    _control.getMinIntrinsicWidth(double.infinity),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _label.getMaxIntrinsicWidth(double.infinity) +
      _spacing +
      _control.getMaxIntrinsicWidth(double.infinity);

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

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
