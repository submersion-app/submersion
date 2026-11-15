import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/utils/text_measure.dart';

/// A callout to place over the balance bar: [anchor] is the centre of the
/// segment it names and [width] the callout's own, both measured from the
/// bar's start edge.
class BalanceCalloutRequest {
  final Object id;
  final double anchor;
  final double width;

  const BalanceCalloutRequest({
    required this.id,
    required this.anchor,
    required this.width,
  });
}

/// Where a callout landed: its start edge and its row, row 0 being the one
/// nearest the bar.
class BalanceCalloutPlacement {
  final Object id;
  final double anchor;
  final double start;
  final double width;
  final int row;

  const BalanceCalloutPlacement({
    required this.id,
    required this.anchor,
    required this.start,
    required this.width,
    required this.row,
  });

  double get end => start + width;
}

/// Lays callouts out over the bar: each as near its anchor as it can sit
/// without overlapping a neighbour, in as few rows as hold them all.
///
/// One row is the usual case; a second appears only when a narrow screen
/// cannot fit every callout side by side. Callouts keep their anchors' order
/// within a row, so a leader never has to cross another to reach its segment.
List<BalanceCalloutPlacement> placeBalanceCallouts(
  List<BalanceCalloutRequest> requests, {
  required double laneWidth,
  double gap = 4,
}) {
  if (requests.isEmpty) return const [];
  final sorted = [...requests]..sort((a, b) => a.anchor.compareTo(b.anchor));
  for (var rows = 1; ; rows++) {
    // Dealt out in turn, so neighbours land in different rows.
    final byRow = [
      for (var r = 0; r < rows; r++)
        [for (var i = r; i < sorted.length; i += rows) sorted[i]],
    ];
    final last = rows >= sorted.length;
    if (!last && !byRow.every((row) => _fits(row, laneWidth, gap))) continue;
    return [
      for (var r = 0; r < rows; r++) ..._spread(byRow[r], r, laneWidth, gap),
    ];
  }
}

/// The rows a lane needs for [placed], never fewer than one: the lane keeps
/// its height when no part needs a callout, so the bar does not jump as parts
/// come and go while the dive is scrubbed.
int balanceCalloutRows(List<BalanceCalloutPlacement> placed) =>
    placed.fold(1, (rows, p) => math.max(rows, p.row + 1));

bool _fits(List<BalanceCalloutRequest> row, double laneWidth, double gap) =>
    row.fold(0.0, (sum, q) => sum + q.width) + gap * (row.length - 1) <=
    laneWidth;

List<BalanceCalloutPlacement> _spread(
  List<BalanceCalloutRequest> row,
  int rowIndex,
  double laneWidth,
  double gap,
) {
  if (row.isEmpty) return const [];
  final starts = <double>[
    for (final q in row)
      (q.anchor - q.width / 2)
          .clamp(0.0, math.max(0.0, laneWidth - q.width))
          .toDouble(),
  ];
  // Push right past each left neighbour...
  for (var i = 1; i < row.length; i++) {
    starts[i] = math.max(starts[i], starts[i - 1] + row[i - 1].width + gap);
  }
  // ...then back left from the far edge, if that pushed any past it.
  final lastIndex = row.length - 1;
  if (starts[lastIndex] + row[lastIndex].width > laneWidth) {
    starts[lastIndex] = math.max(0.0, laneWidth - row[lastIndex].width);
    for (var i = lastIndex - 1; i >= 0; i--) {
      starts[i] = math.max(
        0.0,
        math.min(starts[i], starts[i + 1] - gap - row[i].width),
      );
    }
  }
  return [
    for (var i = 0; i < row.length; i++)
      BalanceCalloutPlacement(
        id: row[i].id,
        anchor: row[i].anchor,
        start: starts[i],
        width: row[i].width,
        row: rowIndex,
      ),
  ];
}

/// One part's name and figure, floating over its segment.
class BalanceCallout {
  final Object id;
  final String label;

  /// The segment's centre, from the bar's start edge.
  final double anchor;

  /// The side's colour, for the outline and the leader.
  final Color color;

  const BalanceCallout({
    required this.id,
    required this.label,
    required this.anchor,
    required this.color,
  });
}

/// The strip above the balance bar that holds the callouts for parts too
/// narrow to carry their own label, each with a leader down to its segment.
///
/// Its height holds at least one row whether or not anything is in it, so the
/// bar and the chart under it stay put while the dive is scrubbed.
class BalanceCalloutLane extends StatelessWidget {
  final List<BalanceCallout> callouts;
  final double width;

  const BalanceCalloutLane({
    super.key,
    required this.callouts,
    required this.width,
  });

  static const double pillHeight = 20;
  static const double _rowGap = 4;
  static const double _leader = 10;
  static const double _padding = 6;

  /// The lane's height for [rows] rows of callouts.
  static double heightFor(int rows) =>
      rows * pillHeight + (rows - 1) * _rowGap + _leader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface,
    );
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final byId = {for (final c in callouts) c.id: c};
    final placed = placeBalanceCallouts([
      for (final c in callouts)
        BalanceCalloutRequest(
          id: c.id,
          anchor: c.anchor,
          width: _pillWidth(c.label, style, direction, scaler),
        ),
    ], laneWidth: width);
    final height = heightFor(balanceCalloutRows(placed));
    double top(int row) =>
        height - _leader - pillHeight - row * (pillHeight + _rowGap);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _LeaderPainter(
                leaders: [
                  for (final p in placed)
                    _Leader(
                      fromX: p.width < 16
                          ? p.start + p.width / 2
                          : p.anchor.clamp(p.start + 8, p.end - 8),
                      fromY: top(p.row) + pillHeight,
                      toX: p.anchor,
                      color: byId[p.id]!.color,
                    ),
                ],
                direction: direction,
              ),
            ),
          ),
          for (final p in placed)
            PositionedDirectional(
              start: p.start,
              top: top(p.row),
              width: p.width,
              height: pillHeight,
              child: Container(
                key: ValueKey('balance-callout-${p.id}'),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: _padding),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: byId[p.id]!.color),
                  borderRadius: BorderRadius.circular(pillHeight / 2),
                ),
                child: Text(
                  byId[p.id]!.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: style,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static double _pillWidth(
    String label,
    TextStyle? style,
    TextDirection direction,
    TextScaler scaler,
  ) {
    final text = measureSingleLine(
      label,
      style,
      direction: direction,
      scaler: scaler,
    );
    // Text, its padding and the outline either side.
    return text.width + _padding * 2 + 2;
  }
}

class _Leader {
  final double fromX;
  final double fromY;
  final double toX;
  final Color color;

  const _Leader({
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.color,
  });
}

/// Draws each leader from its callout's lower edge to the top of its segment.
/// Positions arrive measured from the start edge and are mirrored here for a
/// right-to-left layout.
class _LeaderPainter extends CustomPainter {
  final List<_Leader> leaders;
  final TextDirection direction;

  const _LeaderPainter({required this.leaders, required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    double x(double fromStart) =>
        direction == TextDirection.rtl ? size.width - fromStart : fromStart;
    for (final l in leaders) {
      canvas.drawLine(
        Offset(x(l.fromX), l.fromY),
        Offset(x(l.toX), size.height),
        Paint()
          ..color = l.color
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_LeaderPainter old) =>
      old.direction != direction || !_sameLeaders(old.leaders, leaders);

  static bool _sameLeaders(List<_Leader> a, List<_Leader> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].fromX != b[i].fromX ||
          a[i].fromY != b[i].fromY ||
          a[i].toX != b[i].toX ||
          a[i].color != b[i].color) {
        return false;
      }
    }
    return true;
  }
}
