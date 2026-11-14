import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/utils/weight_axis.dart';

/// The scale under the balance bar: zero at the centre rule and round weights
/// outward along each half, in the diver's own unit.
///
/// It is drawn to the same geometry as the bar's segments ([usable] pixels
/// stand for [scaleKg] on each side of the rule), so a segment can be read
/// against it. The bar's scale is fixed for a dive, so the ruler never moves
/// while the dive is scrubbed.
class BalanceRuler extends StatelessWidget {
  /// The weight one half of the bar stands for.
  final double scaleKg;

  /// The width of one half of the bar, beside the centre rule.
  final double halfWidth;

  /// The part of [halfWidth] that [scaleKg] spans.
  final double usable;

  /// The centre rule's width.
  final double ruleWidth;

  final UnitFormatter units;

  const BalanceRuler({
    super.key,
    required this.scaleKg,
    required this.halfWidth,
    required this.usable,
    required this.ruleWidth,
    required this.units,
  });

  static const double _tickHeight = 5;
  static const double _labelGap = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final lineColor = theme.colorScheme.outlineVariant;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final span = units.convertWeight(scaleKg);
    final width = halfWidth * 2 + ruleWidth;

    Size measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final size = Size(painter.width.ceilToDouble(), painter.height);
      painter.dispose();
      return size;
    }

    // The finest round step whose labels still clear each other; a narrow
    // card gets fewer, coarser marks rather than overlapping ones.
    var marks = const <(double, String, double)>[];
    for (var intervals = 4; intervals >= 1; intervals--) {
      final axis = WeightAxis.within(span, maxIntervals: intervals);
      if (axis.ticks.length < 2) break;
      final candidate = [
        for (final t in axis.ticks.skip(1))
          () {
            final label = units.formatWeight(
              units.weightToKg(t),
              decimals: axis.decimals,
            );
            return (t / span * usable, label, measure(label).width);
          }(),
      ];
      final widest = candidate.fold(0.0, (m, c) => math.max(m, c.$3));
      if (candidate.first.$1 >= widest + _labelGap) {
        marks = candidate;
        break;
      }
    }
    final zero = formatFixedForDisplay(0, 0);
    final zeroSize = measure(zero);

    final centre = halfWidth + ruleWidth / 2;
    Widget tick(double x) => PositionedDirectional(
      start: x - 0.5,
      top: 0,
      width: 1,
      height: _tickHeight,
      child: ColoredBox(color: lineColor),
    );
    Widget label(double x, String text, double w) => PositionedDirectional(
      start: (x - w / 2).clamp(0.0, math.max(0.0, width - w)),
      top: _tickHeight + 2,
      width: w,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: style,
      ),
    );

    return SizedBox(
      key: const ValueKey('balance-ruler'),
      width: width,
      height: _tickHeight + 2 + zeroSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: halfWidth - usable,
            top: 0,
            width: usable * 2 + ruleWidth,
            height: 1,
            child: ColoredBox(color: lineColor),
          ),
          tick(centre),
          label(centre, zero, zeroSize.width),
          for (final (offset, text, w) in marks) ...[
            // The pulling-down half reads outward from the rule toward the
            // start edge, the holding-up half toward the end edge.
            tick(halfWidth - offset),
            label(halfWidth - offset, text, w),
            tick(halfWidth + ruleWidth + offset),
            label(halfWidth + ruleWidth + offset, text, w),
          ],
        ],
      ),
    );
  }
}
