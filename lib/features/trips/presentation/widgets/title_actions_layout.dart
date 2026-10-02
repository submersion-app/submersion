import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A card header: [title] at the start and [actions] at the end of one line
/// when both fit, otherwise [actions] on a line of their own under [title],
/// still at the end. A Row of the trip Gear card's title and its two buttons
/// overflowed a 360 px phone in de, fr, hu, nl and pt (issue #2794);
/// OverflowBar stacks every child on the same edge, and Wrap starts a lone
/// child at the start.
class TitleActionsLayout extends MultiChildRenderObjectWidget {
  TitleActionsLayout({
    super.key,
    required Widget title,
    required Widget actions,
  }) : super(children: [title, actions]);

  @override
  RenderTitleActionsLayout createRenderObject(BuildContext context) =>
      RenderTitleActionsLayout(textDirection: Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTitleActionsLayout renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _TitleActionsParentData extends ContainerBoxParentData<RenderBox> {}

/// The render object of [TitleActionsLayout]: exactly two children, the
/// title first.
class RenderTitleActionsLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TitleActionsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TitleActionsParentData> {
  RenderTitleActionsLayout({required TextDirection textDirection})
    : _textDirection = textDirection;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _title => firstChild!;
  RenderBox get _actions => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TitleActionsParentData) {
      child.parentData = _TitleActionsParentData();
    }
  }

  /// Sizes both children at their natural width (at most the available
  /// width) and places them on one line or two.
  ({Size size, Offset title, Offset actions}) _arrange(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    final title = layoutChild(_title, childConstraints);
    final actions = layoutChild(_actions, childConstraints);
    final natural = title.width + actions.width;
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : natural;
    final rtl = _textDirection == TextDirection.rtl;
    double start(Size child) => rtl ? width - child.width : 0;
    double end(Size child) => rtl ? 0 : width - child.width;
    if (natural <= width) {
      final height = math.max(title.height, actions.height);
      return (
        size: constraints.constrain(Size(width, height)),
        title: Offset(start(title), (height - title.height) / 2),
        actions: Offset(end(actions), (height - actions.height) / 2),
      );
    }
    return (
      size: constraints.constrain(Size(width, title.height + actions.height)),
      title: Offset(start(title), 0),
      actions: Offset(end(actions), title.height),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    final arranged = _arrange(constraints, ChildLayoutHelper.layoutChild);
    size = arranged.size;
    (_title.parentData! as _TitleActionsParentData).offset = arranged.title;
    (_actions.parentData! as _TitleActionsParentData).offset = arranged.actions;
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _title.getMinIntrinsicWidth(double.infinity),
    _actions.getMinIntrinsicWidth(double.infinity),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _title.getMaxIntrinsicWidth(double.infinity) +
      _actions.getMaxIntrinsicWidth(double.infinity);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMaxIntrinsicHeight(w));

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) heightOf,
  ) {
    final title = heightOf(_title, width);
    final actions = heightOf(_actions, width);
    return getMaxIntrinsicWidth(double.infinity) <= width
        ? math.max(title, actions)
        : title + actions;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
