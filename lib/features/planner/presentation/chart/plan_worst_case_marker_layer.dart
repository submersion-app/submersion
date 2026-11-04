import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_issue_marker_layer.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_paint_utils.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_popup_layout.dart';
import 'package:submersion/features/planner/presentation/providers/plan_worst_case_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Gap between the profile line and the worst-case pill: clear of a warning
/// sign at the same point, which sits 5 to 17 px above its anchor.
const worstCasePillGap = 22.0;

/// The band under the top of the plot where the gas-switch flags sit. A pill
/// that would reach into it goes below the line instead.
const _flagRowHeight = 24.0;

/// Half the diagonal of the diamond on the line.
const _diamondRadius = 5.0;

/// The worst-case bailout marker where the chart draws it (issue #4211): the
/// [anchor] on the profile line, the [pill] with its label, and the end of
/// the stem that joins them.
class PlacedWorstCaseMarker {
  const PlacedWorstCaseMarker({
    required this.worstCase,
    required this.anchor,
    required this.pill,
    required this.above,
  });

  final PlanChartWorstCase worstCase;
  final Offset anchor;
  final Rect pill;

  /// Whether the pill sits above the line (else below it).
  final bool above;

  /// Where the stem meets the pill.
  Offset get stemEnd => Offset(anchor.dx, above ? pill.bottom : pill.top);

  /// The diamond and the pill together, so the card sits clear of both.
  Rect get footprint => pill.expandToInclude(
    Rect.fromCircle(center: anchor, radius: _diamondRadius + 1),
  );
}

/// The size of the pill for [label] in [style]: the label with its padding.
Size worstCasePillSize(String label, TextStyle style, TextDirection direction) {
  final painter = layoutLabel(label, style, direction);
  final size = Size(painter.width + 12, painter.height + 6);
  painter.dispose();
  return size;
}

/// Places [worstCase] on the profile [depthAt] describes. The pill goes up
/// and to the left of the anchor, ending at it: stop tags sit right of and
/// below their stops, and the gas flags along the top, so that side is free.
/// Next to the gas flag row it goes below the line instead. It always stays
/// inside the plot horizontally.
PlacedWorstCaseMarker placeWorstCaseMarker({
  required PlanChartWorstCase worstCase,
  required PlanChartGeometry geometry,
  required double Function(double timeSeconds) depthAt,
  required Size pillSize,
}) {
  final plot = geometry.plotRect;
  final time = worstCase.runtimeSeconds.toDouble();
  final anchor = geometry.toPixel(time, depthAt(time));

  final aboveTop = anchor.dy - worstCasePillGap - pillSize.height;
  final above = aboveTop >= plot.top + _flagRowHeight;
  final top = above ? aboveTop : anchor.dy + worstCasePillGap;
  final left = (anchor.dx - pillSize.width)
      .clamp(plot.left, math.max(plot.left, plot.right - pillSize.width))
      .toDouble();
  return PlacedWorstCaseMarker(
    worstCase: worstCase,
    anchor: anchor,
    pill: Rect.fromLTWH(left, top, pillSize.width, pillSize.height),
    above: above,
  );
}

/// How far [position] is from [placed]'s pill, or null when it is farther
/// than [radius]. Only the pill is a target, not the diamond: the worst case
/// usually sits on the waypoint that ends the bottom, which must stay
/// draggable. A distance, not a yes or no, so the chart can give a press to
/// whichever of this and a warning sign is closer.
double? worstCasePillDistance(
  PlacedWorstCaseMarker placed,
  Offset position, {
  double radius = 4,
}) {
  final pill = placed.pill;
  final dx = math.max(
    0.0,
    math.max(pill.left - position.dx, position.dx - pill.right),
  );
  final dy = math.max(
    0.0,
    math.max(pill.top - position.dy, position.dy - pill.bottom),
  );
  final distance = math.sqrt(dx * dx + dy * dy);
  return distance <= radius ? distance : null;
}

/// Whether a pointer at [position] is on the worst-case pill rather than on a
/// warning sign: the pill is within [pillRadius] and closer than every sign
/// within [signRadius]. A fixed "signs first" rule would let a warning at the
/// same instant take most of the pill on touch, where a sign's reach extends
/// into it.
bool pointerOnWorstCase(
  PlacedWorstCaseMarker? placed,
  List<PlacedIssueMarker> signs,
  Offset position, {
  required double pillRadius,
  required double signRadius,
}) {
  if (placed == null) return false;
  final pill = worstCasePillDistance(placed, position, radius: pillRadius);
  if (pill == null) return false;
  for (final sign in signs) {
    final distance = (sign.glyph.center - position).distance;
    if (distance <= signRadius && distance < pill) return false;
  }
  return true;
}

/// A screen reader's target for [pill]: the pill itself, grown to the 48 px
/// a fingertip needs and kept inside [size] so the layer's edge never cuts
/// it short.
Rect worstCaseTarget(Rect pill, Size size) {
  final target = Size(
    math.max(pill.width, kMinInteractiveDimension),
    math.max(pill.height, kMinInteractiveDimension),
  );
  final corner = pill.center - target.center(Offset.zero);
  final left = corner.dx
      .clamp(0.0, math.max(0.0, size.width - target.width))
      .toDouble();
  final top = corner.dy
      .clamp(0.0, math.max(0.0, size.height - target.height))
      .toDouble();
  return Offset(left, top) & target;
}

/// The colour of [worstCase]'s marker: the secondary colour while the
/// bailout gas suffices, the error colour when it does not.
Color worstCaseColor(ColorScheme scheme, PlanChartWorstCase worstCase) =>
    worstCase.sufficient ? scheme.secondary : scheme.error;

/// Draws the worst-case bailout marker over the chart, gives it to screen
/// readers, and shows its card while [active]. It takes no pointer input
/// itself: the chart's own pointer handling hit-tests the pill, as it does
/// the warning markers.
class PlanWorstCaseMarkerLayer extends StatelessWidget {
  const PlanWorstCaseMarkerLayer({
    super.key,
    required this.placed,
    required this.label,
    required this.active,
    required this.palette,
    required this.units,
    required this.labelStyle,
    required this.onActivate,
  });

  final PlacedWorstCaseMarker placed;

  /// The pill's text.
  final String label;
  final bool active;
  final PlanChartPalette palette;
  final UnitFormatter units;
  final TextStyle labelStyle;

  /// Called when a screen reader activates the marker.
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = worstCaseColor(theme.colorScheme, placed.worstCase);
    final lines = worstCaseCardLines(context, placed.worstCase, units);
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              key: const Key('planChartWorstCaseMarker'),
              painter: PlanWorstCaseMarkerPainter(
                placed: placed,
                label: label,
                labelStyle: labelStyle,
                textDirection: Directionality.of(context),
                color: color,
                background: Color.alphaBlend(
                  color.withValues(alpha: 0.18),
                  theme.colorScheme.surface,
                ),
                outline: palette.backdrop,
                opacity: placed.worstCase.stale ? 0.5 : 1,
              ),
            ),
          ),
          Positioned.fromRect(
            rect: worstCaseTarget(placed.pill, constraints.biggest),
            child: Semantics(
              key: const Key('planChartWorstCaseTarget'),
              button: true,
              label: lines.join('\n'),
              onTap: onActivate,
              child: const SizedBox.expand(),
            ),
          ),
          if (active)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomSingleChildLayout(
                    delegate: PlanChartPopupLayout(placed.footprint),
                    child: _WorstCaseCard(
                      key: const Key('planChartWorstCaseCard'),
                      worstCase: placed.worstCase,
                      lines: lines,
                      palette: palette,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The card's text, line by line, with the strings the results sheet's
/// bailout section uses: where and when, the time to surface, the gas
/// needed and the gas carried, and a warning when that is short.
List<String> worstCaseCardLines(
  BuildContext context,
  PlanChartWorstCase worstCase,
  UnitFormatter units,
) {
  final l10n = context.l10n;
  return [
    l10n.plannerCanvas_bailout_worstCase(
      '${(worstCase.runtimeSeconds / 60).round()}',
      units.formatDepth(worstCase.depthMeters, decimals: 0),
    ),
    l10n.plannerCanvas_bailout_tts('${(worstCase.ttsSeconds / 60).ceil()}'),
    l10n.plannerCanvas_bailout_required(
      units.formatVolume(worstCase.litersRequired),
    ),
    l10n.plannerCanvas_bailout_available(
      units.formatVolume(worstCase.availableLiters),
    ),
    if (!worstCase.sufficient) l10n.plannerCanvas_bailout_insufficient,
  ];
}

/// The diamond on the line, the stem and the pill with its label, in the
/// marker's [color], outlined in the chart backdrop so the diamond reads over
/// the profile and the fill. A [opacity] below 1 dims all of it.
class PlanWorstCaseMarkerPainter extends CustomPainter {
  const PlanWorstCaseMarkerPainter({
    required this.placed,
    required this.label,
    required this.labelStyle,
    required this.textDirection,
    required this.color,
    required this.background,
    required this.outline,
    required this.opacity,
  });

  final PlacedWorstCaseMarker placed;
  final String label;
  final TextStyle labelStyle;
  final TextDirection textDirection;
  final Color color;
  final Color background;
  final Color outline;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    Color dim(Color c) => c.withValues(alpha: c.a * opacity);
    final anchor = placed.anchor;
    final pill = placed.pill;

    canvas.drawLine(
      anchor,
      placed.stemEnd,
      Paint()
        ..color = dim(color)
        ..strokeWidth = 1.2,
    );

    final diamond = Path()
      ..moveTo(anchor.dx, anchor.dy - _diamondRadius)
      ..lineTo(anchor.dx + _diamondRadius, anchor.dy)
      ..lineTo(anchor.dx, anchor.dy + _diamondRadius)
      ..lineTo(anchor.dx - _diamondRadius, anchor.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = dim(color));
    canvas.drawPath(
      diamond,
      Paint()
        ..color = dim(outline)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );

    final rrect = RRect.fromRectAndRadius(pill, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = dim(background));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = dim(color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final text = layoutLabel(
      label,
      labelStyle.copyWith(color: dim(color)),
      textDirection,
    );
    text.paint(canvas, Offset(pill.left + 6, pill.top + 3));
    text.dispose();
  }

  @override
  bool shouldRepaint(PlanWorstCaseMarkerPainter oldDelegate) =>
      oldDelegate.placed.anchor != placed.anchor ||
      oldDelegate.placed.pill != placed.pill ||
      oldDelegate.label != label ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.color != color ||
      oldDelegate.background != background ||
      oldDelegate.outline != outline ||
      oldDelegate.opacity != opacity;
}

class _WorstCaseCard extends StatelessWidget {
  const _WorstCaseCard({
    super.key,
    required this.worstCase,
    required this.lines,
    required this.palette,
  });

  final PlanChartWorstCase worstCase;
  final List<String> lines;
  final PlanChartPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodySmall?.copyWith(
      color: palette.readoutText,
    );
    final error = theme.colorScheme.error;
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
              lines[0],
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: palette.readoutText,
              ),
            ),
            const SizedBox(height: 4),
            Text(lines[1], style: body),
            Text(
              lines[2],
              style: body?.copyWith(
                fontWeight: FontWeight.w600,
                color: worstCase.sufficient ? null : error,
              ),
            ),
            Text(lines[3], style: body),
            if (!worstCase.sufficient)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error, size: 16, color: error),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        lines[4],
                        style: body?.copyWith(color: error),
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
