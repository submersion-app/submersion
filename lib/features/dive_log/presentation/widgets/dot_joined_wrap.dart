import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The space between two lines of items.
const _runSpacing = 2.0;

/// What is drawn between two items on the same line.
const _separatorText = ' · ';

/// [children] in a wrapping line, a dot between two items that share a
/// line, so a line breaks between items rather than inside one. A dot that
/// would end a line is not drawn (issue #5041): when every item has a line
/// of its own there are no dots, and an item wider than the whole line wraps
/// inside itself on a line of its own rather than leaving its dot alone at
/// the edge. The dots are drawn in the surrounding text style and not read
/// out.
class DotJoinedWrap extends StatelessWidget {
  const DotJoinedWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _DotJoined(
      separatorStyle: DefaultTextStyle.of(context).style,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      children: children,
    );
  }
}

class _DotJoined extends MultiChildRenderObjectWidget {
  const _DotJoined({
    required this.separatorStyle,
    required this.textScaler,
    required this.textDirection,
    required super.children,
  });

  final TextStyle separatorStyle;
  final TextScaler textScaler;
  final TextDirection textDirection;

  @override
  RenderDotJoinedWrap createRenderObject(BuildContext context) =>
      RenderDotJoinedWrap(
        separatorStyle: separatorStyle,
        textScaler: textScaler,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderDotJoinedWrap renderObject,
  ) {
    renderObject
      ..separatorStyle = separatorStyle
      ..textScaler = textScaler
      ..textDirection = textDirection;
  }
}

class _DotJoinedParentData extends ContainerBoxParentData<RenderBox> {}

/// One placed item: its size, where it starts on its line, and the line.
typedef _Placed = ({Size size, double x, int line});

/// Lays out [DotJoinedWrap]'s items line by line and paints a dot between
/// each two that share a line.
class RenderDotJoinedWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DotJoinedParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DotJoinedParentData> {
  RenderDotJoinedWrap({
    required TextStyle separatorStyle,
    required TextScaler textScaler,
    required TextDirection textDirection,
  }) : _textDirection = textDirection,
       _separator = TextPainter(
         text: TextSpan(text: _separatorText, style: separatorStyle),
         textScaler: textScaler,
         textDirection: textDirection,
       );

  final TextPainter _separator;

  set separatorStyle(TextStyle value) {
    if (_separator.text?.style == value) return;
    _separator.text = TextSpan(text: _separatorText, style: value);
    markNeedsLayout();
  }

  set textScaler(TextScaler value) {
    if (_separator.textScaler == value) return;
    _separator.textScaler = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _separator.textDirection = value;
    markNeedsLayout();
  }

  /// Where the dots were drawn at the last layout, in this box's
  /// coordinates.
  List<Rect> _separatorRects = const [];

  @visibleForTesting
  List<Rect> get separatorRects => _separatorRects;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DotJoinedParentData) {
      child.parentData = _DotJoinedParentData();
    }
  }

  @override
  void dispose() {
    _separator.dispose();
    super.dispose();
  }

  Size get _separatorSize {
    _separator.layout();
    return _separator.size;
  }

  /// Places each child, sized by [sizeOf] at most [maxWidth] wide: an item
  /// shares the line when it fits after a dot, else starts the next one.
  List<_Placed> _place(
    double maxWidth,
    Size Function(RenderBox child, BoxConstraints constraints) sizeOf,
  ) {
    final dot = _separatorSize.width;
    final constraints = BoxConstraints(maxWidth: maxWidth);
    final placed = <_Placed>[];
    var line = 0;
    var lineEnd = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final size = sizeOf(child, constraints);
      if (placed.isEmpty) {
        placed.add((size: size, x: 0, line: 0));
        lineEnd = size.width;
      } else if (lineEnd + dot + size.width <= maxWidth) {
        placed.add((size: size, x: lineEnd + dot, line: line));
        lineEnd += dot + size.width;
      } else {
        line++;
        placed.add((size: size, x: 0, line: line));
        lineEnd = size.width;
      }
    }
    return placed;
  }

  /// The height of each line, and the box's size, for [placed].
  ({List<double> lineHeights, Size size}) _measure(
    List<_Placed> placed,
    BoxConstraints constraints,
  ) {
    final dotHeight = _separatorSize.height;
    final lineHeights = <double>[];
    var width = 0.0;
    for (final item in placed) {
      if (item.line == lineHeights.length) lineHeights.add(0);
      // A line with a dot is at least the dot's height.
      final shared = item.x > 0 ? dotHeight : 0.0;
      lineHeights[item.line] = math.max(
        lineHeights[item.line],
        math.max(item.size.height, shared),
      );
      width = math.max(width, item.x + item.size.width);
    }
    final height =
        lineHeights.fold(0.0, (a, b) => a + b) +
        _runSpacing * math.max(0, lineHeights.length - 1);
    return (
      lineHeights: lineHeights,
      size: constraints.constrain(Size(width, height)),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final placed = _place(
      constraints.maxWidth,
      (child, c) => child.getDryLayout(c),
    );
    return _measure(placed, constraints).size;
  }

  @override
  void performLayout() {
    final placed = _place(constraints.maxWidth, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    final measured = _measure(placed, constraints);
    size = measured.size;

    final dotSize = _separatorSize;
    final rtl = _textDirection == TextDirection.rtl;
    // Each child's left edge, mirrored right to left.
    double left(double x, double width) => rtl ? size.width - x - width : x;
    final dots = <Rect>[];
    var top = 0.0;
    var line = 0;
    var child = firstChild;
    for (final item in placed) {
      if (item.line != line) {
        top += measured.lineHeights[line] + _runSpacing;
        line = item.line;
      }
      final lineHeight = measured.lineHeights[line];
      if (item.x > 0) {
        final dotX = item.x - dotSize.width;
        dots.add(
          Offset(
                left(dotX, dotSize.width),
                top + (lineHeight - dotSize.height) / 2,
              ) &
              dotSize,
        );
      }
      (child!.parentData! as _DotJoinedParentData).offset = Offset(
        left(item.x, item.size.width),
        top + (lineHeight - item.size.height) / 2,
      );
      child = childAfter(child);
    }
    _separatorRects = dots;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var width = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      width = math.max(width, child.getMinIntrinsicWidth(double.infinity));
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var width = 0.0;
    var count = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      width += child.getMaxIntrinsicWidth(double.infinity);
      count++;
    }
    return width + _separatorSize.width * math.max(0, count - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    for (final rect in _separatorRects) {
      _separator.paint(context.canvas, offset + rect.topLeft);
    }
  }
}
