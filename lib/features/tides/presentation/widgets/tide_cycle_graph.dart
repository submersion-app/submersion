import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact visualization showing where a tide is in its cycle.
///
/// Displays a sinusoidal wave with a marker indicating the current position,
/// useful for quickly understanding tide state during a dive.
///
/// The graph shows:
/// - A sine wave representing the tide cycle
/// - High/Low labels at the peaks and troughs with times and heights
/// - A marker dot showing the position at dive time
/// - The current height and time at the marker
///
/// Usage:
/// ```dart
/// TideCycleGraph(
///   record: tideRecord,
///   referenceTime: dive.entryTime,
///   height: 60,
/// )
/// ```
class TideCycleGraph extends StatelessWidget {
  /// The tide record containing state and height information.
  final TideRecord record;

  /// The reference time being visualized (e.g., dive entry time).
  final DateTime? referenceTime;

  /// Time format preference (12h or 24h). Defaults to 24-hour if not specified.
  final TimeFormat timeFormat;

  /// Height of the graph widget.
  final double height;

  /// Width of the graph widget. Defaults to double.infinity.
  final double? width;

  /// Whether to show height labels. Defaults to true.
  final bool showLabels;

  /// Depth unit preference for height display. Defaults to meters.
  final DepthUnit depthUnit;

  const TideCycleGraph({
    super.key,
    required this.record,
    this.referenceTime,
    this.timeFormat = TimeFormat.twentyFourHour,
    this.height = 60,
    this.width,
    this.showLabels = true,
    this.depthUnit = DepthUnit.meters,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Calculate the position in the cycle (0.0 to 1.0)
    final cyclePosition = _calculateCyclePosition();

    final displayHeight = DepthUnit.meters
        .convert(record.heightMeters, depthUnit)
        .toStringAsFixed(1);
    final stateLabel = record.tideState.name;
    final chartSummary = context.l10n.tides_semantic_tideCycle(
      stateLabel,
      '$displayHeight${depthUnit.symbol}',
    );

    return Semantics(
      label: chartSummary,
      child: SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: CustomPaint(
          painter: _TideCyclePainter(
            cyclePosition: cyclePosition,
            tideState: record.tideState,
            waveColor: colorScheme.primary,
            fillColor: colorScheme.primary.withValues(alpha: 0.1),
            markerColor: _getStateColor(record.tideState),
            gridColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
            labelColor: colorScheme.onSurfaceVariant,
            labelStyle: textTheme.labelSmall ?? const TextStyle(fontSize: 10),
            showLabels: showLabels,
            currentHeight: record.heightMeters,
            highTideHeight: record.highTideHeight,
            lowTideHeight: record.lowTideHeight,
            highTideTime: record.highTideTime,
            lowTideTime: record.lowTideTime,
            referenceTime: referenceTime,
            timeFormat: timeFormat,
            depthUnit: depthUnit,
          ),
        ),
      ),
    );
  }

  /// Calculate the position in the tide cycle (0.0 = low, 0.5 = high, 1.0 = low).
  ///
  /// Uses available height data to interpolate position, falling back to
  /// state-based estimation if heights aren't available.
  double _calculateCyclePosition() {
    // If we have both high and low tide heights, interpolate based on current height
    if (record.highTideHeight != null && record.lowTideHeight != null) {
      final range = record.highTideHeight! - record.lowTideHeight!;
      if (range > 0) {
        // Normalize height to 0-1 range (0 = low, 1 = high)
        final normalizedHeight =
            (record.heightMeters - record.lowTideHeight!) / range;
        final clampedHeight = normalizedHeight.clamp(0.0, 1.0);

        // Convert to cycle position based on tide state
        // Rising: 0.0 (low) to 0.5 (high)
        // Falling: 0.5 (high) to 1.0 (low)
        switch (record.tideState) {
          case TideState.rising:
            return clampedHeight * 0.5;
          case TideState.falling:
            return 0.5 + (1.0 - clampedHeight) * 0.5;
          case TideState.slackHigh:
            return 0.5;
          case TideState.slackLow:
            return 0.0;
        }
      }
    }

    // Fallback: estimate position based on state
    switch (record.tideState) {
      case TideState.rising:
        return 0.25; // Midway through rising
      case TideState.falling:
        return 0.75; // Midway through falling
      case TideState.slackHigh:
        return 0.5; // At high tide
      case TideState.slackLow:
        return 0.0; // At low tide
    }
  }

  Color _getStateColor(TideState state) {
    switch (state) {
      case TideState.rising:
        return Colors.green.shade600;
      case TideState.falling:
        return Colors.orange.shade600;
      case TideState.slackHigh:
        return Colors.red.shade600;
      case TideState.slackLow:
        return Colors.blue.shade600;
    }
  }
}

/// Custom painter for the tide cycle visualization.
class _TideCyclePainter extends CustomPainter {
  final double cyclePosition;
  final TideState tideState;
  final Color waveColor;
  final Color fillColor;
  final Color markerColor;
  final Color gridColor;
  final Color labelColor;
  final TextStyle labelStyle;
  final bool showLabels;
  final double currentHeight;
  final double? highTideHeight;
  final double? lowTideHeight;
  final DateTime? highTideTime;
  final DateTime? lowTideTime;
  final DateTime? referenceTime;
  final TimeFormat timeFormat;
  final DepthUnit depthUnit;

  _TideCyclePainter({
    required this.cyclePosition,
    required this.tideState,
    required this.waveColor,
    required this.fillColor,
    required this.markerColor,
    required this.gridColor,
    required this.labelColor,
    required this.labelStyle,
    required this.showLabels,
    required this.currentHeight,
    this.highTideHeight,
    this.lowTideHeight,
    this.highTideTime,
    this.lowTideTime,
    this.referenceTime,
    required this.timeFormat,
    required this.depthUnit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Skip painting if size is too small (e.g., during collapse animation)
    // Minimum size must accommodate padding: left(70) + right(46) = 116 width, top(12) + bottom(18) = 30 height
    if (size.width < 120 || size.height < 35) return;

    final wavePaint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final markerPaint = Paint()
      ..color = markerColor
      ..style = PaintingStyle.fill;

    final markerStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Padding for labels (extra space for timestamps and heights)
    final leftPadding = showLabels ? 70.0 : 8.0;
    final rightPadding = showLabels ? 46.0 : 8.0;
    const topPadding = 12.0;
    const bottomPadding = 18.0;

    final graphWidth = size.width - leftPadding - rightPadding;
    final graphHeight = size.height - topPadding - bottomPadding;
    final centerY = topPadding + graphHeight / 2;

    // Draw center line (mean level)
    canvas.drawLine(
      Offset(leftPadding, centerY),
      Offset(size.width - rightPadding, centerY),
      gridPaint,
    );

    // Build the sine wave path
    final wavePath = Path();
    final fillPath = Path();

    // We draw 1.5 cycles to show context
    // Position 0.0 starts at low tide
    final amplitude = graphHeight * 0.4;
    const totalCycles = 1.0;

    // Start at the left edge
    for (int i = 0; i <= 100; i++) {
      final t = i / 100.0;
      final x = leftPadding + t * graphWidth;

      // Sine wave: starts at low (position 0), peaks at high (position 0.5)
      // y = -amplitude * cos(2π * position)
      // At position 0: cos(0) = 1, y = -amplitude (low)
      // At position 0.5: cos(π) = -1, y = amplitude (high)
      final wavePosition = t * totalCycles;
      final y = centerY - amplitude * math.sin(wavePosition * math.pi);

      if (i == 0) {
        wavePath.moveTo(x, y);
        fillPath.moveTo(x, centerY + amplitude);
        fillPath.lineTo(x, y);
      } else {
        wavePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete fill path
    fillPath.lineTo(size.width - rightPadding, centerY + amplitude);
    fillPath.close();

    // Draw fill and wave
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(wavePath, wavePaint);

    // Calculate marker position on the wave
    final markerX = leftPadding + cyclePosition * graphWidth;
    final markerWavePosition = cyclePosition * totalCycles;
    final markerY =
        centerY - amplitude * math.sin(markerWavePosition * math.pi);

    // Draw marker
    canvas.drawCircle(Offset(markerX, markerY), 8, markerPaint);
    canvas.drawCircle(Offset(markerX, markerY), 8, markerStrokePaint);

    // Draw labels if enabled
    if (showLabels) {
      final textPainter = TextPainter(textDirection: TextDirection.ltr);

      // High label with time (at peak, position 0.5)
      final highX = leftPadding + 0.5 * graphWidth;
      final highY = centerY - amplitude;

      // Build high tide label text (H with time and height)
      final highTimeStr = highTideTime != null
          ? _formatTime(highTideTime!)
          : null;
      final highHeightStr = highTideHeight != null
          ? '${DepthUnit.meters.convert(highTideHeight!, depthUnit).toStringAsFixed(1)}${depthUnit.symbol}'
          : null;
      textPainter.text = TextSpan(
        children: [
          TextSpan(
            text: 'H',
            style: labelStyle.copyWith(
              color: Colors.red.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (highTimeStr != null)
            TextSpan(
              text: ' $highTimeStr',
              style: labelStyle.copyWith(color: labelColor, fontSize: 9),
            ),
          if (highHeightStr != null)
            TextSpan(
              text: ' $highHeightStr',
              style: labelStyle.copyWith(
                color: Colors.red.shade600,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(highX - textPainter.width / 2, highY - textPainter.height - 2),
      );

      // Low label with height (at start, position 0)
      final lowY = centerY + amplitude;
      final lowHeightStr = lowTideHeight != null
          ? '${DepthUnit.meters.convert(lowTideHeight!, depthUnit).toStringAsFixed(1)}${depthUnit.symbol}'
          : null;

      // Left low label (L with height only - time shown on x-axis)
      textPainter.text = TextSpan(
        children: [
          TextSpan(
            text: 'L',
            style: labelStyle.copyWith(
              color: Colors.blue.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (lowHeightStr != null)
            TextSpan(
              text: ' $lowHeightStr',
              style: labelStyle.copyWith(
                color: Colors.blue.shade600,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          leftPadding - textPainter.width - 4,
          lowY - textPainter.height / 2,
        ),
      );

      // Right low label (L with height)
      textPainter.text = TextSpan(
        children: [
          TextSpan(
            text: 'L',
            style: labelStyle.copyWith(
              color: Colors.blue.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (lowHeightStr != null)
            TextSpan(
              text: ' $lowHeightStr',
              style: labelStyle.copyWith(
                color: Colors.blue.shade600,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - rightPadding + 4, lowY - textPainter.height / 2),
      );

      // Current time and height label near marker
      final refTimeStr = referenceTime != null
          ? _formatTime(referenceTime!)
          : null;
      final heightText =
          '${DepthUnit.meters.convert(currentHeight, depthUnit).toStringAsFixed(1)}${depthUnit.symbol}';
      textPainter.text = TextSpan(
        children: [
          if (refTimeStr != null)
            TextSpan(
              text: '$refTimeStr ',
              style: labelStyle.copyWith(color: labelColor, fontSize: 9),
            ),
          TextSpan(
            text: heightText,
            style: labelStyle.copyWith(
              color: markerColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      );
      textPainter.layout();

      // Position label above or below marker depending on wave position
      final labelOffset = markerY < centerY ? 12.0 : -textPainter.height - 4;
      final labelX = (markerX - textPainter.width / 2).clamp(
        leftPadding,
        size.width - rightPadding - textPainter.width,
      );
      textPainter.paint(canvas, Offset(labelX, markerY + labelOffset));

      // Draw timestamps at the ends of the x-axis (center line)
      // Calculate cycle start and end times based on high/low tide times
      final (startTime, endTime) = _calculateCycleTimes();

      if (startTime != null) {
        textPainter.text = TextSpan(
          text: _formatTime(startTime),
          style: labelStyle.copyWith(color: labelColor, fontSize: 9),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(leftPadding, centerY + 4));
      }

      if (endTime != null) {
        textPainter.text = TextSpan(
          text: _formatTime(endTime),
          style: labelStyle.copyWith(color: labelColor, fontSize: 9),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(size.width - rightPadding - textPainter.width, centerY + 4),
        );
      }
    }
  }

  /// Format a DateTime using the configured time format.
  String _formatTime(DateTime time) {
    return DateFormat(timeFormat.pattern).format(time.toLocal());
  }

  /// Calculate the start and end times for the tide cycle.
  ///
  /// The graph shows low → high → low. This method determines the times
  /// for the start (first low) and end (second low) based on available data.
  (DateTime?, DateTime?) _calculateCycleTimes() {
    if (highTideTime == null || lowTideTime == null) {
      return (null, null);
    }

    // Calculate half-cycle duration (time between low and high)
    final halfCycle = highTideTime!.difference(lowTideTime!).abs();

    if (lowTideTime!.isBefore(highTideTime!)) {
      // Low tide is before high tide: low → high, need to find end low
      final startTime = lowTideTime!;
      final endTime = highTideTime!.add(halfCycle);
      return (startTime, endTime);
    } else {
      // Low tide is after high tide: need to find start low
      final startTime = highTideTime!.subtract(halfCycle);
      final endTime = lowTideTime!;
      return (startTime, endTime);
    }
  }

  @override
  bool shouldRepaint(covariant _TideCyclePainter oldDelegate) {
    return cyclePosition != oldDelegate.cyclePosition ||
        tideState != oldDelegate.tideState ||
        waveColor != oldDelegate.waveColor ||
        markerColor != oldDelegate.markerColor ||
        showLabels != oldDelegate.showLabels ||
        currentHeight != oldDelegate.currentHeight ||
        highTideTime != oldDelegate.highTideTime ||
        lowTideTime != oldDelegate.lowTideTime ||
        referenceTime != oldDelegate.referenceTime;
  }
}
