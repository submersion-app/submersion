import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/tides/presentation/widgets/tide_chart_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The key above a [TideChart]: the tide curve, the high and low marks, and
/// the dashed Now line.
class TideChartLegend extends StatelessWidget {
  const TideChartLegend({
    super.key,
    this.showExtremeMarkers = true,
    this.showNowMarker = true,
  });

  final bool showExtremeMarkers;
  final bool showNowMarker;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final marks = TideChartColors.of(context);

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: colorScheme.primary,
          label: context.l10n.tides_legend_tideLevel,
        ),
        if (showExtremeMarkers) ...[
          _LegendItem(
            color: marks.high,
            label: context.l10n.tides_legend_highTide,
          ),
          _LegendItem(
            color: marks.low,
            label: context.l10n.tides_legend_lowTide,
          ),
        ],
        if (showNowMarker)
          _LegendItem(
            color: colorScheme.primary,
            label: context.l10n.tides_legend_now,
            isDashed: true,
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.isDashed = false,
  });

  final Color color;
  final String label;
  final bool isDashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDashed)
          SizedBox(
            width: 12,
            height: 2,
            child: CustomPaint(painter: _DashedLinePainter(color: color)),
          )
        else
          Container(
            width: 12,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Simple painter for dashed line in legend
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 3.0;
    const dashSpace = 2.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(math.min(startX + dashWidth, size.width), size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}
