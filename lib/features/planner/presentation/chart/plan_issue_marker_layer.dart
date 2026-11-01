import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_grouping.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_markers.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_issue_text.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A warning marker where the chart draws it (#3738): [anchor] is the point
/// on the profile line where the warnings start, [glyph] the small warning
/// sign drawn just above it (below it when the anchor is too close to the
/// top of the plot). A [highlighted] marker shows a ring around its anchor
/// in place of its sign.
class PlacedIssueMarker {
  const PlacedIssueMarker({
    required this.marker,
    required this.depthMeters,
    required this.anchor,
    required this.glyph,
    this.highlighted = false,
  });

  final PlanIssueMarker marker;
  final double depthMeters;
  final Offset anchor;
  final Rect glyph;
  final bool highlighted;

  /// The sign and the ring together, whichever is showing, so the popup
  /// sits in the same place on hover and once picked, clear of both.
  Rect get footprint => glyph.expandToInclude(
    Rect.fromCircle(
      center: anchor,
      radius: issueMarkerRingRadius + _ringStroke / 2,
    ),
  );
}

/// Width and height of a marker's warning sign, in logical pixels.
const issueMarkerGlyphSize = Size(14, 12);

/// Gap between the profile line and the warning sign, so the sign never
/// covers the line it points at.
const _glyphGap = 5.0;

/// Radius of the ring around a highlighted marker's anchor.
const issueMarkerRingRadius = 7.0;

/// Width of the ring's stroke.
const _ringStroke = 2.0;

/// Places [markers] on the profile [depthAt] describes. Markers whose
/// anchors land closer than [mergeDistance] pixels share one, so warnings
/// that start at nearly the same point never pile up at the current zoom.
/// A marker with any of the [highlighted] rows is placed highlighted.
List<PlacedIssueMarker> placeIssueMarkers({
  required List<PlanIssueMarker> markers,
  required PlanChartGeometry geometry,
  required double Function(double timeSeconds) depthAt,
  Set<PlanIssueKey> highlighted = const {},
  double mergeDistance = 16,
}) {
  final plot = geometry.plotRect;
  final merged = <(PlanIssueMarker, double, Offset)>[];
  for (final marker in markers) {
    final depth = depthAt(marker.runtimeSeconds.toDouble());
    final anchor = geometry.toPixel(marker.runtimeSeconds.toDouble(), depth);
    if (merged.isNotEmpty &&
        (merged.last.$3 - anchor).distance < mergeDistance) {
      final (previous, previousDepth, previousAnchor) = merged.removeLast();
      merged.add((
        PlanIssueMarker(
          runtimeSeconds: previous.runtimeSeconds,
          groups: [...previous.groups, ...marker.groups]
            ..sort(
              (a, b) =>
                  b.issue.severity.index.compareTo(a.issue.severity.index),
            ),
        ),
        previousDepth,
        previousAnchor,
      ));
      continue;
    }
    merged.add((marker, depth, anchor));
  }

  const size = issueMarkerGlyphSize;
  return [
    for (final (marker, depth, anchor) in merged)
      () {
        final above = anchor.dy - _glyphGap - size.height;
        final top = above >= plot.top ? above : anchor.dy + _glyphGap;
        final left = (anchor.dx - size.width / 2)
            .clamp(plot.left, math.max(plot.left, plot.right - size.width))
            .toDouble();
        return PlacedIssueMarker(
          marker: marker,
          depthMeters: depth,
          anchor: anchor,
          glyph: Rect.fromLTWH(left, top, size.width, size.height),
          highlighted: marker.keys.any(highlighted.contains),
        );
      }(),
  ];
}

/// The marker under [position], or null. [radius] widens the target past
/// the small sign, to the 48 px minimum a fingertip needs on touch.
int? hitTestIssueMarker(
  List<PlacedIssueMarker> placed,
  Offset position, {
  double radius = 16,
}) {
  int? best;
  var bestDistance = radius;
  for (var i = 0; i < placed.length; i++) {
    final distance = (placed[i].glyph.center - position).distance;
    if (distance <= bestDistance) {
      best = i;
      bestDistance = distance;
    }
  }
  return best;
}

/// Where a screen reader's target for [glyph] goes: the same 48 px square a
/// fingertip gets, moved back inside [size] so the layer's edge never cuts
/// it short, as it would for a marker at the surface.
Rect issueMarkerTarget(Rect glyph, Size size) {
  const target = Size.square(kMinInteractiveDimension);
  final corner = glyph.center - target.center(Offset.zero);
  final left = corner.dx
      .clamp(0.0, math.max(0.0, size.width - target.width))
      .toDouble();
  final top = corner.dy
      .clamp(0.0, math.max(0.0, size.height - target.height))
      .toDouble();
  return Offset(left, top) & target;
}

/// Draws the warning markers over the chart, gives each one to screen
/// readers, and shows the warnings of the [activeIndex] marker in a small
/// card beside it. It takes no pointer input itself: the chart's own
/// pointer handling hit-tests the markers, so a tap on one never also
/// selects a segment or adds a waypoint.
class PlanIssueMarkerLayer extends StatelessWidget {
  const PlanIssueMarkerLayer({
    super.key,
    required this.placed,
    required this.activeIndex,
    required this.palette,
    required this.units,
    required this.onActivate,
  });

  final List<PlacedIssueMarker> placed;
  final int? activeIndex;
  final PlanChartPalette palette;
  final UnitFormatter units;

  /// Called when a screen reader activates the marker at this index.
  final ValueChanged<int> onActivate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = activeIndex;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              key: const Key('planChartIssueMarkers'),
              painter: PlanIssueMarkerPainter(
                placed: placed,
                colors: [
                  for (final p in placed)
                    planIssueSeverityColor(scheme, p.marker.severity),
                ],
                highlighted: [for (final p in placed) p.highlighted],
                outline: palette.backdrop,
              ),
            ),
          ),
          for (var i = 0; i < placed.length; i++)
            Positioned.fromRect(
              rect: issueMarkerTarget(placed[i].glyph, constraints.biggest),
              child: Semantics(
                button: true,
                label: _semanticsLabel(context, placed[i]),
                onTap: () => onActivate(i),
                child: const SizedBox.expand(),
              ),
            ),
          if (active != null && active < placed.length)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomSingleChildLayout(
                    delegate: _PopupLayout(placed[active].footprint),
                    child: _IssuePopup(
                      key: const Key('planChartIssuePopup'),
                      placed: placed[active],
                      palette: palette,
                      units: units,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _semanticsLabel(BuildContext context, PlacedIssueMarker placed) => [
    _positionText(context, placed, units),
    for (final group in placed.marker.groups) _groupText(context, group, units),
  ].join('\n');
}

String _positionText(
  BuildContext context,
  PlacedIssueMarker placed,
  UnitFormatter units,
) => context.l10n.plannerCanvas_scrub_readout(
  (placed.marker.runtimeSeconds / 60).round().toString(),
  units.formatDepth(placed.depthMeters, decimals: 0),
);

/// A row's text exactly as the warnings list prints it.
String _groupText(
  BuildContext context,
  GroupedPlanIssue group,
  UnitFormatter units,
) {
  final message = planIssueMessage(context, group.issue, units);
  return group.count > 1
      ? context.l10n.plannerCanvas_issue_repeated(message, group.count)
      : message;
}

/// Each marker as a small warning sign in its severity's colour, outlined
/// in the chart backdrop so it reads over the profile, the fill and the
/// ceiling band, with a dot on the line where the warnings start. A
/// highlighted marker shows a ring centred on that dot instead of its sign.
class PlanIssueMarkerPainter extends CustomPainter {
  const PlanIssueMarkerPainter({
    required this.placed,
    required this.colors,
    required this.highlighted,
    required this.outline,
  });

  final List<PlacedIssueMarker> placed;
  final List<Color> colors;
  final List<bool> highlighted;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < placed.length; i++) {
      final marker = placed[i];
      final color = colors[i];
      final fill = Paint()..color = color;

      canvas.drawCircle(marker.anchor, 2.5, fill);
      canvas.drawCircle(marker.anchor, 2.5, outlinePaint);

      if (highlighted[i]) {
        canvas.drawCircle(
          marker.anchor,
          issueMarkerRingRadius,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = _ringStroke,
        );
        continue;
      }

      final glyph = marker.glyph;
      final sign = Path()
        ..moveTo(glyph.center.dx, glyph.top)
        ..lineTo(glyph.right, glyph.bottom)
        ..lineTo(glyph.left, glyph.bottom)
        ..close();
      canvas.drawPath(sign, fill);
      canvas.drawPath(sign, outlinePaint);

      // The exclamation mark, in the outline colour so it contrasts with
      // the sign in both themes.
      final mark = Paint()
        ..color = outline
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(glyph.center.dx, glyph.top + 4),
        Offset(glyph.center.dx, glyph.bottom - 4.5),
        mark,
      );
      canvas.drawCircle(Offset(glyph.center.dx, glyph.bottom - 2.2), 0.9, mark);
    }
  }

  @override
  bool shouldRepaint(PlanIssueMarkerPainter oldDelegate) =>
      outline != oldDelegate.outline ||
      !listEquals(colors, oldDelegate.colors) ||
      !listEquals(highlighted, oldDelegate.highlighted) ||
      !listEquals(
        [for (final p in placed) p.glyph],
        [for (final p in oldDelegate.placed) p.glyph],
      );
}

/// Puts the warnings card beside its marker's [footprint]: to the right
/// when it fits, else to the left, vertically centred on it. When the card
/// fits on neither side it goes below the marker, else above, so it never
/// covers the sign or the ring. It always stays inside the chart.
class _PopupLayout extends SingleChildLayoutDelegate {
  const _PopupLayout(this.footprint);

  final Rect footprint;

  static const _margin = 4.0;
  static const _gap = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.min(260, constraints.maxWidth - 2 * _margin),
        maxHeight: constraints.maxHeight - 2 * _margin,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final right = footprint.right + _gap;
    final left = footprint.left - _gap - childSize.width;
    final below = footprint.bottom + _gap;
    final above = footprint.top - _gap - childSize.height;
    final besideY = footprint.center.dy - childSize.height / 2;
    final centredX = footprint.center.dx - childSize.width / 2;
    final Offset position;
    if (right + childSize.width <= size.width - _margin) {
      position = Offset(right, besideY);
    } else if (left >= _margin) {
      position = Offset(left, besideY);
    } else if (below + childSize.height <= size.height - _margin) {
      position = Offset(centredX, below);
    } else if (above >= _margin) {
      position = Offset(centredX, above);
    } else {
      position = Offset(left, besideY);
    }
    return Offset(
      position.dx.clamp(
        _margin,
        math.max(_margin, size.width - childSize.width - _margin),
      ),
      position.dy.clamp(
        _margin,
        math.max(_margin, size.height - childSize.height - _margin),
      ),
    );
  }

  @override
  bool shouldRelayout(_PopupLayout oldDelegate) =>
      footprint != oldDelegate.footprint;
}

class _IssuePopup extends StatelessWidget {
  const _IssuePopup({
    super.key,
    required this.placed,
    required this.palette,
    required this.units,
  });

  final PlacedIssueMarker placed;
  final PlanChartPalette palette;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.readoutBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.readoutBorder),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _positionText(context, placed, units),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: palette.readoutText,
              ),
            ),
            for (final group in placed.marker.groups)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      planIssueIcon(group.issue.severity),
                      size: 16,
                      color: planIssueSeverityColor(
                        theme.colorScheme,
                        group.issue.severity,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _groupText(context, group, units),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.readoutText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
