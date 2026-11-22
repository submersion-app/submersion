import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [children] on one line, as many as fit, then what [overflowBuilder]
/// builds for the number left out (issue #4825): a "+N" chip, say. The
/// line never wraps, so it is never taller than its tallest child, and it
/// never scrolls, so it never takes a swipe from a pager around it.
///
/// Children run from the start edge of the ambient [Directionality],
/// [spacing] apart, centred on the line. When not all of them fit, the
/// most that fit with the count after them are shown; when not even the
/// first does, only the count. Children left out are neither painted, hit
/// nor announced, and finders that skip what is offstage pass them by.
class OneLineOverflowRow extends StatelessWidget {
  const OneLineOverflowRow({
    super.key,
    required this.children,
    required this.overflowBuilder,
    this.spacing = 8,
  });

  final List<Widget> children;

  /// The count of the children left out, given how many.
  final Widget Function(BuildContext context, int hidden) overflowBuilder;

  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return _OneLineOverflow(
      itemCount: children.length,
      spacing: spacing,
      textDirection: Directionality.of(context),
      children: [
        ...children,
        // One count for each number that could be left out: each is as
        // wide as its own number. Keyed apart, as they are all alike.
        for (var hidden = 1; hidden <= children.length; hidden++)
          KeyedSubtree(
            key: _CountKey(hidden),
            child: overflowBuilder(context, hidden),
          ),
      ],
    );
  }
}

/// The key of the count for [hidden] children left out.
class _CountKey extends ValueKey<int> {
  const _CountKey(super.hidden);
}

class _OneLineOverflow extends MultiChildRenderObjectWidget {
  const _OneLineOverflow({
    required this.itemCount,
    required this.spacing,
    required this.textDirection,
    super.children,
  });

  final int itemCount;
  final double spacing;
  final TextDirection textDirection;

  @override
  MultiChildRenderObjectElement createElement() =>
      _OneLineOverflowElement(this);

  @override
  RenderOneLineOverflow createRenderObject(BuildContext context) =>
      RenderOneLineOverflow(
        itemCount: itemCount,
        spacing: spacing,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderOneLineOverflow renderObject,
  ) {
    renderObject
      ..itemCount = itemCount
      ..spacing = spacing
      ..textDirection = textDirection;
  }
}

/// Shows finders only the children on the line, as [Offstage] does for
/// what it hides.
class _OneLineOverflowElement extends MultiChildRenderObjectElement {
  _OneLineOverflowElement(super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final line = renderObject as RenderOneLineOverflow;
    for (final child in children) {
      final box = child.renderObject;
      if (box is RenderBox && line.isShown(box)) visitor(child);
    }
  }
}

class _LineParentData extends ContainerBoxParentData<RenderBox> {
  bool shown = false;
}

/// Lays out [OneLineOverflowRow]: its first [itemCount] children are the
/// items, and the rest the counts for 1 to [itemCount] left out.
class RenderOneLineOverflow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _LineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _LineParentData> {
  RenderOneLineOverflow({
    required int itemCount,
    required double spacing,
    required TextDirection textDirection,
  }) : _itemCount = itemCount,
       _spacing = spacing,
       _textDirection = textDirection;

  int _itemCount;
  set itemCount(int value) {
    if (value == _itemCount) return;
    _itemCount = value;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// Whether [child] is on the line.
  @visibleForTesting
  bool isShown(RenderBox child) => (child.parentData! as _LineParentData).shown;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LineParentData) {
      child.parentData = _LineParentData();
    }
  }

  List<RenderBox> get _children {
    final all = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      all.add(child);
      child = childAfter(child);
    }
    return all;
  }

  /// Which children go on a line [maxWidth] wide, given each one's size:
  /// the items shown, and the count's child, or null for none.
  (int shownItems, int? countChild) _fit(List<Size> sizes, double maxWidth) {
    final n = math.min(_itemCount, sizes.length);
    double itemsWidth(int m) {
      var width = 0.0;
      for (var k = 0; k < m; k++) {
        width += sizes[k].width;
      }
      return width + _spacing * math.max(0, m - 1);
    }

    if (!maxWidth.isFinite || itemsWidth(n) <= maxWidth) return (n, null);
    for (var m = n - 1; m >= 0; m--) {
      final countIndex = n + (n - m) - 1;
      if (countIndex >= sizes.length) continue;
      final width =
          itemsWidth(m) + (m > 0 ? _spacing : 0) + sizes[countIndex].width;
      if (width <= maxWidth || m == 0) return (m, countIndex);
    }
    return (0, null);
  }

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final children = _children;
    final childConstraints = BoxConstraints(
      maxWidth: constraints.maxWidth,
      maxHeight: constraints.maxHeight,
    );
    final sizes = [
      for (final child in children)
        dry
            ? child.getDryLayout(childConstraints)
            : (child..layout(childConstraints, parentUsesSize: true)).size,
    ];
    final (shownItems, countChild) = _fit(sizes, constraints.maxWidth);
    final order = [for (var k = 0; k < shownItems; k++) k, ?countChild];
    var height = 0.0;
    var used = 0.0;
    for (final k in order) {
      height = math.max(height, sizes[k].height);
      used += sizes[k].width;
    }
    used += _spacing * math.max(0, order.length - 1);
    final size = constraints.constrain(
      Size(constraints.maxWidth.isFinite ? constraints.maxWidth : used, height),
    );
    if (dry) return size;
    for (final child in children) {
      (child.parentData! as _LineParentData).shown = false;
    }
    var x = 0.0;
    for (final k in order) {
      final data = children[k].parentData! as _LineParentData;
      data.shown = true;
      final left = _textDirection == TextDirection.ltr
          ? x
          : size.width - x - sizes[k].width;
      data.offset = Offset(left, (size.height - sizes[k].height) / 2);
      x += sizes[k].width + _spacing;
    }
    return size;
  }

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) {
    var width = 0.0;
    var k = 0;
    for (final child in _children) {
      if (k++ >= _itemCount) break;
      width += child.getMaxIntrinsicWidth(height);
    }
    return width + _spacing * math.max(0, _itemCount - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _tallest(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _tallest(width);

  double _tallest(double width) => _children.fold(
    0,
    (tallest, child) => math.max(tallest, child.getMaxIntrinsicHeight(width)),
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in _children) {
      final data = child.parentData! as _LineParentData;
      if (data.shown) context.paintChild(child, offset + data.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _children.reversed) {
      final data = child.parentData! as _LineParentData;
      if (!data.shown) continue;
      final hit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final child in _children) {
      if ((child.parentData! as _LineParentData).shown) visitor(child);
    }
  }
}
