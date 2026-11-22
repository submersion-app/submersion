import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A horizontal run of status lights that a mouse can drag as well as a
/// finger: on desktop the lights can run past the end of the bar, and
/// Material drag-scrolls a horizontal list with a mouse only when told to.
///
/// Each edge with lights scrolled past it fades out, so the row shows it
/// scrolls and a pill is never cut off hard against its neighbour (issue
/// #4920). With every light in view neither edge fades.
class HomeLightsScroller extends StatefulWidget {
  final List<Widget> children;

  const HomeLightsScroller({super.key, required this.children});

  /// How far in from an edge its fade runs.
  static const double fadeExtent = 24;

  /// The space between two lights.
  static const double gap = 6;

  @override
  State<HomeLightsScroller> createState() => HomeLightsScrollerState();
}

class HomeLightsScrollerState extends State<HomeLightsScroller> {
  bool _fadesStart = false;
  bool _fadesEnd = false;

  /// Keeps the scroll view, and so its position, when the fade mask goes
  /// in above it or comes out.
  final _rowKey = GlobalKey();

  /// Whether lights are scrolled past the leading edge, which then fades.
  @visibleForTesting
  bool get fadesStart => _fadesStart;

  /// Whether lights run past the trailing edge, which then fades.
  @visibleForTesting
  bool get fadesEnd => _fadesEnd;

  /// Takes the fades from [metrics]. Before and after count in reading
  /// order, so a right-to-left bar fades its right edge as its start.
  void _update(ScrollMetrics metrics) {
    if (!metrics.hasContentDimensions) return;
    // A fling or a fractional pixel ratio can stop a hair short of an end.
    final start = metrics.extentBefore > precisionErrorTolerance;
    final end = metrics.extentAfter > precisionErrorTolerance;
    if (start == _fadesStart && end == _fadesEnd) return;
    setState(() {
      _fadesStart = start;
      _fadesEnd = end;
    });
  }

  bool _onNotification(Notification notification) {
    // Only the row's own scroll view (depth 0), never one inside a light.
    switch (notification) {
      case ScrollMetricsNotification(:final metrics, depth: 0):
        _update(metrics);
      case ScrollNotification(:final metrics, depth: 0):
        _update(metrics);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Widget row = ScrollConfiguration(
      key: _rowKey,
      behavior: ScrollConfiguration.of(
        context,
      ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          // The gap goes between lights only: one after the last would
          // count as hidden content and fade an end with every light in
          // view.
          children: [
            for (final (i, c) in widget.children.indexed)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: i == 0 ? 0 : HomeLightsScroller.gap,
                ),
                child: c,
              ),
          ],
        ),
      ),
    );
    if (_fadesStart || _fadesEnd) {
      final direction = Directionality.of(context);
      row = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          // Each fade is a fixed width, at most half the row.
          final f = bounds.width <= 0
              ? 0.0
              : (HomeLightsScroller.fadeExtent / bounds.width).clamp(0.0, 0.5);
          return LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [
              _fadesStart ? Colors.transparent : Colors.black,
              Colors.black,
              Colors.black,
              _fadesEnd ? Colors.transparent : Colors.black,
            ],
            stops: [0, f, 1 - f, 1],
          ).createShader(bounds, textDirection: direction);
        },
        child: row,
      );
    }
    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: row,
    );
  }
}
