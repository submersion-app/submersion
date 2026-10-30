import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/theme/backdrop_color.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_fill_levels.dart';

/// The valve drawn on top of the cylinder, and the space between the
/// cylinder (with its ticks) and the labels.
const _valveHeight = 6.0;
const _tickLength = 6.0;
const _labelGap = 10.0;

/// The least space between two labels, and the narrowest a label is
/// squeezed to before it is allowed past the figure's width.
const _labelSpacing = 2.0;
const _minLabelWidth = 24.0;

/// Body width at the smallest and the largest figure height.
const _minBodyWidth = 18.0;
const _maxBodyWidth = 28.0;

/// One cylinder on the Cylinders card drawn as an upright tank (issue
/// #3773): solid in [gasColor] up to the gas left at the end, a lighter
/// tint of it over the gas used, and empty above the start pressure, so a
/// short fill reads as a tank never quite full. [startLabel] and
/// [endLabel] sit at their levels with a tick, and [usedLabel] (bold)
/// between them with a bracket over the used zone. Crowded labels are
/// pushed apart and joined to their levels by short leader lines.
///
/// The labels arrive formatted; the figure only places them. A label whose
/// value is missing has no level ([markStart] or [markEnd] false) and sits
/// at the top (start) or bottom (end) of the cylinder.
class TankFigure extends StatelessWidget {
  const TankFigure({
    super.key,
    required this.levels,
    required this.gasColor,
    required this.volumeLiters,
    required this.startLabel,
    required this.endLabel,
    this.usedLabel,
    this.markStart = true,
    this.markEnd = true,
  });

  final TankFillLevels levels;
  final Color gasColor;

  /// Scales the cylinder's height (see [tankFigureHeight]).
  final double? volumeLiters;
  final String startLabel;
  final String endLabel;
  final String? usedLabel;
  final bool markStart;
  final bool markEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: [startLabel, endLabel, ?usedLabel].join(', '),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _layout(context, constraints.maxWidth),
      ),
    );
  }

  /// Within [maxWidth] a label too wide for the space beside the cylinder
  /// wraps onto another line rather than crowding what sits beside the
  /// figure; the figure grows taller to make room.
  Widget _layout(BuildContext context, double maxWidth) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Measured and drawn in the same style, so a label breaks and stands as
    // tall as the space it was given.
    final base = DefaultTextStyle.of(context).style
        .merge(theme.textTheme.bodySmall)
        .copyWith(color: colors.onSurfaceVariant);
    final usedStyle = base.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w700,
    );

    final bodyHeight = tankFigureHeight(volumeLiters);
    final bodyWidth =
        _minBodyWidth +
        (bodyHeight - tankFigureMinHeight) /
            (tankFigureMaxHeight - tankFigureMinHeight) *
            (_maxBodyWidth - _minBodyWidth);

    final texts = [
      (startLabel, base),
      if (usedLabel != null) (usedLabel!, usedStyle),
      (endLabel, base),
    ];
    final labelX = bodyWidth + _labelGap;
    final labelMaxWidth = maxWidth.isFinite
        ? math.max(maxWidth - labelX, _minLabelWidth)
        : double.infinity;
    final sizes = [
      for (final (text, style) in texts)
        _measure(text, style, textScaler, direction, labelMaxWidth, context),
    ];
    final labelsHeight =
        sizes.fold(0.0, (sum, s) => sum + s.height) +
        _labelSpacing * (sizes.length - 1);
    final figureHeight = _valveHeight + bodyHeight;
    final extent = math.max(figureHeight, labelsHeight);
    final bodyTop = (extent - figureHeight) / 2 + _valveHeight;
    final bodyBottom = bodyTop + bodyHeight;
    double y(double level) => bodyBottom - level * bodyHeight;

    // Where each label points: its level when it has one, else the top
    // (start) or bottom (end) of the cylinder.
    final fill = levels.hasFill;
    final startY = fill && markStart ? y(levels.start!) : bodyTop;
    final endY = fill && markEnd ? y(levels.end!) : bodyBottom;
    final targets = [startY, if (usedLabel != null) (startY + endY) / 2, endY];
    final tops = spreadLabels(
      centres: targets,
      heights: [for (final s in sizes) s.height],
      extent: extent,
      gap: _labelSpacing,
    );

    // Each label is laid out at its width rounded up (below), so the figure
    // is as wide as the widest of those, or the Stack would clip it.
    final width =
        labelX +
        sizes.fold(
          0.0,
          (widest, s) => math.max(widest, s.width.ceilToDouble()),
        );
    // A label pointing at a level gets a leader when it was moved off it;
    // one without a level (a missing value, an outline) points at nothing.
    final startMarked = fill && markStart;
    final endMarked = fill && markEnd;
    final hasBracket =
        usedLabel != null && startMarked && endMarked && endY - startY > 1;
    final marked = [
      startMarked,
      if (usedLabel != null) startMarked && endMarked,
      endMarked,
    ];
    // The used label's leader starts on its bracket, the others on a tick.
    final fromBracket = [false, if (usedLabel != null) hasBracket, false];
    return SizedBox(
      width: width,
      height: extent,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TankPainter(
                bodyTop: bodyTop,
                bodyWidth: bodyWidth,
                bodyHeight: bodyHeight,
                levels: levels,
                solid: gasColor,
                used: Color.alphaBlend(
                  gasColor.withValues(alpha: 0.35),
                  backdropColorOf(context),
                ),
                outline: colors.outline,
                marks: colors.onSurfaceVariant,
                startTick: startMarked ? startY : null,
                endTick: endMarked ? endY : null,
                bracket: hasBracket ? (startY, endY) : null,
                leaders: [
                  for (var i = 0; i < targets.length; i++)
                    if (marked[i])
                      (
                        level: targets[i],
                        centre: tops[i] + sizes[i].height / 2,
                        fromBracket: fromBracket[i],
                      ),
                ],
                labelX: labelX,
                textDirection: direction,
              ),
            ),
          ),
          for (var i = 0; i < texts.length; i++)
            PositionedDirectional(
              start: labelX,
              top: tops[i],
              // Rounded up, so the label breaks where it was measured.
              width: sizes[i].width.ceilToDouble(),
              child: Text(texts[i].$1, style: texts[i].$2),
            ),
        ],
      ),
    );
  }

  static Size _measure(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
    double maxWidth,
    BuildContext context,
  ) {
    // The settings a Text below takes from its context, so the label is
    // measured as it will be drawn (the locale picks a script's font).
    final defaults = DefaultTextStyle.of(context);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      locale: Localizations.maybeLocaleOf(context),
      textHeightBehavior: defaults.textHeightBehavior,
      textWidthBasis: defaults.textWidthBasis,
    )..layout(maxWidth: maxWidth);
    final size = painter.size;
    painter.dispose();
    return size;
  }
}

typedef _Leader = ({double level, double centre, bool fromBracket});

class _TankPainter extends CustomPainter {
  _TankPainter({
    required this.bodyTop,
    required this.bodyWidth,
    required this.bodyHeight,
    required this.levels,
    required this.solid,
    required this.used,
    required this.outline,
    required this.marks,
    required this.startTick,
    required this.endTick,
    required this.bracket,
    required this.leaders,
    required this.labelX,
    required this.textDirection,
  });

  final double bodyTop;
  final double bodyWidth;
  final double bodyHeight;
  final TankFillLevels levels;
  final Color solid;
  final Color used;
  final Color outline;
  final Color marks;
  final double? startTick;
  final double? endTick;
  final (double, double)? bracket;

  /// Each label that has a level: where it points, where its centre sits,
  /// and whether its leader starts on the used bracket rather than a tick.
  final List<_Leader> leaders;
  final double labelX;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn left to right, then mirrored for a right-to-left locale so the
    // labels stay on the side the layout puts them.
    if (textDirection == TextDirection.rtl) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final bodyBottom = bodyTop + bodyHeight;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, bodyTop, bodyWidth - 1.5, bodyHeight),
      Radius.circular(bodyWidth * 0.42),
    );

    final valveWidth = bodyWidth * 0.36;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (bodyWidth - valveWidth) / 2,
          bodyTop - _valveHeight,
          valveWidth,
          _valveHeight,
        ),
        const Radius.circular(1.5),
      ),
      Paint()..color = outline,
    );

    if (levels.hasFill) {
      double y(double level) => bodyBottom - level * bodyHeight;
      canvas.save();
      canvas.clipRRect(body);
      final endY = y(levels.end!);
      final startY = y(levels.start!);
      canvas.drawRect(
        Rect.fromLTRB(0, startY, bodyWidth, endY),
        Paint()..color = used,
      );
      canvas.drawRect(
        Rect.fromLTRB(0, endY, bodyWidth, bodyBottom),
        Paint()..color = solid,
      );
      canvas.restore();
    }

    canvas.drawRRect(
      body,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    final line = Paint()
      ..color = marks
      ..strokeWidth = 1;
    final tickEnd = bodyWidth + _tickLength;
    for (final tick in [?startTick, ?endTick]) {
      canvas.drawLine(Offset(bodyWidth, tick), Offset(tickEnd, tick), line);
    }
    final span = bracket;
    final bracketX = bodyWidth + _tickLength / 2;
    if (span != null) {
      canvas.drawLine(
        Offset(bracketX, span.$1),
        Offset(bracketX, span.$2),
        line,
      );
    }

    // A label moved off its level is joined to it by a leader line.
    for (final leader in leaders) {
      if ((leader.level - leader.centre).abs() < 1) continue;
      canvas.drawLine(
        Offset(leader.fromBracket ? bracketX : tickEnd, leader.level),
        Offset(labelX - 2, leader.centre),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(_TankPainter old) =>
      old.bodyTop != bodyTop ||
      old.bodyWidth != bodyWidth ||
      old.bodyHeight != bodyHeight ||
      old.levels != levels ||
      old.solid != solid ||
      old.used != used ||
      old.outline != outline ||
      old.marks != marks ||
      old.startTick != startTick ||
      old.endTick != endTick ||
      old.bracket != bracket ||
      old.labelX != labelX ||
      old.textDirection != textDirection ||
      !_sameLeaders(old.leaders, leaders);

  static bool _sameLeaders(List<_Leader> a, List<_Leader> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
