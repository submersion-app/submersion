import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [CustomScrollView] that opens with the [center] sliver at the top, so a
/// trip under way opens at today with the earlier days above it.
///
/// Anchoring alone leaves a hole near the end of a trip: the viewport cannot
/// scroll past its last content, so when what follows today is shorter than
/// the window, today sits at the top over blank space. After the first frame
/// this measures where the content ends and pulls the view back by the blank
/// height, so the last days fill the window like any list scrolled to its end.
class TodayAnchoredScrollView extends StatefulWidget {
  /// Slivers in reading order; [center] names one of them.
  final List<Widget> slivers;

  /// Key of the sliver that opens at the top; null builds a plain list that
  /// opens at its start.
  final Key? center;

  const TodayAnchoredScrollView({
    super.key,
    required this.slivers,
    this.center,
  });

  @override
  State<TodayAnchoredScrollView> createState() =>
      _TodayAnchoredScrollViewState();
}

class _TodayAnchoredScrollViewState extends State<TodayAnchoredScrollView> {
  final _endKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.center != null) _scheduleFill();
  }

  @override
  void didUpdateWidget(TodayAnchoredScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The anchor can arrive after the first frame (the trip loading after
    // its days); it then needs the same fill the first frame would have had.
    if (widget.center != null && oldWidget.center == null) _scheduleFill();
  }

  void _scheduleFill() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _fillBelow());

  void _fillBelow() {
    if (!mounted) return;
    final endContext = _endKey.currentContext;
    // No controller of our own: the view keeps the platform's primary one
    // (tap the status bar to scroll to the top), and its position is read
    // from the end marker's Scrollable instead.
    final position = endContext == null
        ? null
        : Scrollable.maybeOf(endContext)?.position;
    if (position == null) return;
    // Content runs past the window below the anchor: nothing to fill.
    if (position.maxScrollExtent > position.pixels) return;
    final end = endContext?.findRenderObject();
    if (end is! RenderBox || !end.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(end);
    if (viewport == null) return;
    final endY = end.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final blank = position.viewportDimension - endY;
    if (blank <= 0) return;
    position.jumpTo(
      math.max(position.minScrollExtent, position.pixels - blank),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      center: widget.center,
      slivers: [
        ...widget.slivers,
        // Zero-height marker for the end of the content, measured once.
        SliverToBoxAdapter(child: SizedBox.shrink(key: _endKey)),
      ],
    );
  }
}
