import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A picker sheet's header: a title, list controls (filter and sort) and
/// trailing actions (Cancel and Add) on one row whenever the title fits on it
/// whole, which saves the list a row of height (issue #2175).
///
/// When it does not (a phone, a long translation, a large text size), the
/// list controls drop to a second row under the actions, so the title keeps
/// the room the actions leave rather than being cut to a few letters.
///
/// The choice rests on measured widths, so it holds for every locale and
/// text scale where a fixed breakpoint would not.
class PickerHeaderLayout extends MultiChildRenderObjectWidget {
  PickerHeaderLayout({
    super.key,
    required Widget title,
    required Widget listControls,
    required Widget actions,
  }) : super(children: [title, listControls, actions]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPickerHeader();
}

class _HeaderParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderPickerHeader extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeaderParentData> {
  RenderBox get _title => firstChild!;
  RenderBox get _listControls => childAfter(_title)!;
  RenderBox get _actions => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeaderParentData) {
      child.parentData = _HeaderParentData();
    }
  }

  /// Whether the title's single-line width fits beside the controls and
  /// actions in [maxWidth].
  bool _fitsOneRow(
    double maxWidth,
    double controlsWidth,
    double actionsWidth,
  ) =>
      _title.getMaxIntrinsicWidth(double.infinity) +
          controlsWidth +
          actionsWidth <=
      maxWidth;

  /// Lays out (or, for a dry layout, only sizes) the three children and
  /// returns the header's size and each child's offset.
  ({Size size, List<Offset> offsets}) _arrange(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final maxWidth = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: maxWidth);
    final actions = layoutChild(_actions, loose);
    final controls = layoutChild(_listControls, loose);

    if (_fitsOneRow(maxWidth, controls.width, actions.width)) {
      final title = layoutChild(
        _title,
        BoxConstraints(maxWidth: maxWidth - controls.width - actions.width),
      );
      final height = [
        title.height,
        controls.height,
        actions.height,
      ].reduce(math.max);
      double centred(Size child) => (height - child.height) / 2;
      return (
        size: constraints.constrain(Size(maxWidth, height)),
        offsets: [
          Offset(0, centred(title)),
          Offset(maxWidth - actions.width - controls.width, centred(controls)),
          Offset(maxWidth - actions.width, centred(actions)),
        ],
      );
    }

    final title = layoutChild(
      _title,
      BoxConstraints(maxWidth: math.max(0, maxWidth - actions.width)),
    );
    final firstRow = math.max(title.height, actions.height);
    return (
      size: constraints.constrain(Size(maxWidth, firstRow + controls.height)),
      offsets: [
        Offset(0, (firstRow - title.height) / 2),
        Offset(maxWidth - controls.width, firstRow),
        Offset(maxWidth - actions.width, (firstRow - actions.height) / 2),
      ],
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    final arranged = _arrange(constraints, ChildLayoutHelper.layoutChild);
    size = arranged.size;
    for (final (child, offset) in [
      (_title, arranged.offsets[0]),
      (_listControls, arranged.offsets[1]),
      (_actions, arranged.offsets[2]),
    ]) {
      (child.parentData! as _HeaderParentData).offset = offset;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _listControls.getMinIntrinsicWidth(height) +
      _actions.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _title.getMaxIntrinsicWidth(height) +
      _listControls.getMaxIntrinsicWidth(height) +
      _actions.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
