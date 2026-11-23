import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_stop_tags.dart';

/// The plan's stops as a list, for the phone chart's readouts where tags on
/// the profile would cover each other (#4981). The shallowest stop is on
/// top; a change is plain warning-coloured text. Six rows show at once,
/// fewer when the chart has less room; the rest scroll, with a fade and a
/// thin scrollbar showing that there is more.
class PlanStopList extends StatefulWidget {
  const PlanStopList({
    super.key,
    required this.tags,
    required this.formatDepth,
    this.bottomReserve = 0,
  });

  /// In time order, deepest first, as [planStopTags] gives them.
  final List<PlanStopTag> tags;
  final String Function(double meters) formatDepth;

  /// Room to leave free below the list, out of the height it is given: it
  /// gives up rows before it lets what follows it run into that strip, and
  /// shows nothing when not even one row fits.
  final double bottomReserve;

  static const visibleRows = 6;

  @override
  State<PlanStopList> createState() => _PlanStopListState();
}

class _PlanStopListState extends State<PlanStopList> {
  final _controller = ScrollController();
  ScrollMetrics? _metrics;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static bool _atStart(ScrollMetrics? m) =>
      m == null || m.pixels <= m.minScrollExtent;
  static bool _atEnd(ScrollMetrics? m) =>
      m != null && m.pixels >= m.maxScrollExtent;

  void _track(ScrollMetrics metrics) {
    if (_atStart(metrics) != _atStart(_metrics) ||
        _atEnd(metrics) != _atEnd(_metrics)) {
      setState(() => _metrics = metrics);
    } else {
      _metrics = metrics;
    }
  }

  /// Passes a swipe past either end of the list on to the page, so the
  /// list never traps the finger.
  bool _forwardOverscroll(OverscrollNotification n) {
    if (n.dragDetails == null || n.depth != 0) return false;
    Scrollable.maybeOf(
      context,
      axis: Axis.vertical,
    )?.position.pointerScroll(n.overscroll);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.tags;
    if (tags.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = PlanChartPalette.of(theme);
    final rowHeight = MediaQuery.textScalerOf(context).scale(18);
    final style = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final hasChanges = tags.any((t) => t.change != null);

    Widget cell(Widget child, Alignment alignment) => SizedBox(
      height: rowHeight,
      child: Align(alignment: alignment, child: child),
    );

    TableRow row(PlanStopTag tag) {
      final rowStyle = tag.isNew
          ? style?.copyWith(color: palette.stopTagChangeText)
          : style;
      final change = tag.change;
      return TableRow(
        children: [
          cell(
            Text(widget.formatDepth(tag.marker.depth), style: rowStyle),
            Alignment.centerRight,
          ),
          cell(
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                "${tag.marker.durationSeconds ~/ 60}'",
                style: rowStyle,
              ),
            ),
            Alignment.centerRight,
          ),
          if (hasChanges)
            cell(
              change == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Text(
                        change,
                        style: style?.copyWith(
                          color: palette.stopTagChangeText,
                        ),
                      ),
                    ),
              Alignment.centerLeft,
            ),
        ],
      );
    }

    final table = Padding(
      // Room for the scrollbar.
      padding: const EdgeInsets.only(right: 6),
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [for (final tag in tags.reversed) row(tag)],
      ),
    );

    const fade = 0.25;
    final contentHeight = tags.length * rowHeight;
    // The divider above the rows and the gap under it.
    const topInset = 4.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = math.min(
          constraints.maxHeight - topInset - widget.bottomReserve,
          rowHeight * PlanStopList.visibleRows,
        );
        if (viewport < rowHeight) return const SizedBox.shrink();
        // Known from the row count, so the first frame already gets
        // the pointers and the fade right.
        final scrollable = contentHeight > viewport + 0.5;
        final hiddenAbove = scrollable && !_atStart(_metrics);
        final hiddenBelow = scrollable && !_atEnd(_metrics);
        // A list that fits leaves the chart under it to the chart: its
        // waypoints, scrub and double-tap.
        return IgnorePointer(
          ignoring: !scrollable,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Container(
              height: math.min(viewport, contentHeight) + topInset,
              padding: const EdgeInsets.only(top: topInset),
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (n) {
                  _track(n.metrics);
                  return false;
                },
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (n) {
                    _track(n.metrics);
                    return false;
                  },
                  child: NotificationListener<OverscrollNotification>(
                    onNotification: _forwardOverscroll,
                    child: RawScrollbar(
                      controller: _controller,
                      thumbVisibility: scrollable,
                      thickness: 2,
                      radius: const Radius.circular(1),
                      thumbColor: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            hiddenAbove ? Colors.transparent : Colors.black,
                            Colors.black,
                            Colors.black,
                            hiddenBelow ? Colors.transparent : Colors.black,
                          ],
                          stops: const [0, fade, 1 - fade, 1],
                        ).createShader(rect),
                        child: SingleChildScrollView(
                          controller: _controller,
                          physics: const ClampingScrollPhysics(),
                          child: table,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
