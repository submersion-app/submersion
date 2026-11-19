import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays out an [AddStrip] above a page's scrolling [body], and keeps the
/// page still as the strip comes and goes.
///
/// The strip appears when a page is unlocked and leaves when it is locked,
/// and it empties and fills again as cards are added and closed. Each time
/// the body's viewport grows or shrinks at its top edge, which on its own
/// would move everything on the page by the strip's height under the
/// diver. The body's scroll offset is moved by the same amount instead, in
/// the same layout pass, so no frame shows the page anywhere else.
///
/// A page at its very top is pushed down instead: its first rows hold the
/// record's header card and that card's pencil, which the strip would
/// otherwise cover the moment the page unlocks (issue #4756). A page that
/// fits on screen has nothing to scroll, so it is always at its top. A page
/// already less than the strip's height from its top when the strip leaves
/// settles at the top.
class AddStripLayout extends StatefulWidget {
  const AddStripLayout({super.key, required this.strip, required this.body});

  final Widget strip;

  /// The page, scrolling vertically.
  final Widget body;

  @override
  State<AddStripLayout> createState() => _AddStripLayoutState();
}

class _AddStripLayoutState extends State<AddStripLayout> {
  /// The body's own vertical scroll position, as last reported by it.
  ScrollPosition? _position;

  /// The strip's height at its last layout.
  double? _stripHeight;

  bool _onMetrics(ScrollMetricsNotification notification) {
    // The page's own scroll view, not one nested in it.
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      _position = Scrollable.maybeOf(notification.context)?.position;
    }
    return false;
  }

  /// Called as the strip is laid out, before the body is: a correction
  /// made here is in place when the body lays out in the same pass.
  void _stripLaidOut(double height) {
    final previous = _stripHeight;
    _stripHeight = height;
    if (previous == null || previous == height) return;
    final position = _position;
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return;
    }
    // The viewport's top edge moves down by [delta]; the content moves up
    // by as much within it, so it stays where it is on screen.
    final delta = height - previous;
    // At the very top the page is pushed down rather than scrolled under
    // the strip, which would hide the header card's first row.
    if (delta > 0 && position.pixels <= position.minScrollExtent) return;
    final target = math.max(position.minScrollExtent, position.pixels + delta);
    position.correctBy(target - position.pixels);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReportHeight(onLayout: _stripLaidOut, child: widget.strip),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _onMetrics,
            child: widget.body,
          ),
        ),
      ],
    );
  }
}

/// Reports its child's height each time it is laid out.
class _ReportHeight extends SingleChildRenderObjectWidget {
  const _ReportHeight({required this.onLayout, required super.child});

  final ValueChanged<double> onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportHeight(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReportHeight renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderReportHeight extends RenderProxyBox {
  _RenderReportHeight(this.onLayout);

  ValueChanged<double> onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout(size.height);
  }
}
