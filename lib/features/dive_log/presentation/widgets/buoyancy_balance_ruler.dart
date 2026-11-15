import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/utils/text_measure.dart';
import 'package:submersion/features/dive_log/presentation/utils/weight_axis.dart';

/// The scale under the balance bar: zero at the centre rule and round weights
/// outward along each half, in the diver's own unit.
///
/// It is drawn to the same geometry as the bar's segments ([usable] pixels
/// stand for [scaleKg] on each side of the rule), so a segment can be read
/// against it. The bar's scale is fixed for a dive, so the ruler never moves
/// while the dive is scrubbed, and its marks are worked out once rather than
/// on every scrub frame.
class BalanceRuler extends StatefulWidget {
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

  @override
  State<BalanceRuler> createState() => _BalanceRulerState();
}

/// One mark: its distance out from the rule, its label and the label's width.
typedef _Mark = (double offset, String label, double width);

class _BalanceRulerState extends State<BalanceRuler> {
  static const double _tickHeight = 5;
  static const double _labelGap = 8;

  Object? _cacheKey;
  List<_Mark> _marks = const [];
  Size _zeroSize = Size.zero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final lineColor = theme.colorScheme.outlineVariant;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final halfWidth = widget.halfWidth;
    final ruleWidth = widget.ruleWidth;
    final width = halfWidth * 2 + ruleWidth;
    final zero = formatFixedForDisplay(0, 0);

    final key = (
      widget.scaleKg,
      halfWidth,
      widget.usable,
      ruleWidth,
      widget.units.settings.weightUnit,
      style,
      direction,
      scaler,
    );
    if (key != _cacheKey) {
      _cacheKey = key;
      Size measure(String text) =>
          measureSingleLine(text, style, direction: direction, scaler: scaler);
      _zeroSize = measure(zero);
      _marks = _chooseMarks(measure, width);
    }

    final centre = halfWidth + ruleWidth / 2;
    Widget tick(double x) => PositionedDirectional(
      start: x - 0.5,
      top: 0,
      width: 1,
      height: _tickHeight,
      child: ColoredBox(color: lineColor),
    );
    Widget label(double x, String text, double w) => PositionedDirectional(
      start: _labelStart(x, w, width),
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
      height: _tickHeight + 2 + _zeroSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: halfWidth - widget.usable,
            top: 0,
            width: widget.usable * 2 + ruleWidth,
            height: 1,
            child: ColoredBox(color: lineColor),
          ),
          tick(centre),
          label(centre, zero, _zeroSize.width),
          for (final (offset, text, w) in _marks) ...[
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

  /// The finest round step whose labels, where they will actually sit (an
  /// outer label is pulled in from the card's edge), still clear each other;
  /// a narrow card gets fewer, coarser marks rather than overlapping ones.
  List<_Mark> _chooseMarks(Size Function(String) measure, double width) {
    final units = widget.units;
    final span = units.convertWeight(widget.scaleKg);
    final inner = widget.halfWidth + widget.ruleWidth;
    for (var intervals = 4; intervals >= 1; intervals--) {
      final axis = WeightAxis.within(span, maxIntervals: intervals);
      if (axis.ticks.length < 2) break;
      final candidate = <_Mark>[
        for (final t in axis.ticks.skip(1))
          () {
            final text = units.formatWeight(
              units.weightToKg(t),
              decimals: axis.decimals,
            );
            return (t / span * widget.usable, text, measure(text).width);
          }(),
      ];
      // The halves mirror each other, so checking the holding-up half,
      // starting from the zero label at the rule, covers both.
      var previousEnd =
          _labelStart(
            widget.halfWidth + widget.ruleWidth / 2,
            _zeroSize.width,
            width,
          ) +
          _zeroSize.width;
      var clear = true;
      for (final (offset, _, w) in candidate) {
        final start = _labelStart(inner + offset, w, width);
        if (start < previousEnd + _labelGap) {
          clear = false;
          break;
        }
        previousEnd = start + w;
      }
      if (clear) return candidate;
    }
    return const [];
  }

  static double _labelStart(double centre, double w, double width) =>
      (centre - w / 2).clamp(0.0, math.max(0.0, width - w)).toDouble();
}
