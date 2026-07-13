import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/services/day_rhythm_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One day's dives plotted as blocks on a 24h axis. Night dives are tinted
/// with the tertiary color; surface intervals appear as gaps.
class DayRhythmBar extends StatelessWidget {
  final List<Dive> dives;
  final double height;

  const DayRhythmBar({super.key, required this.dives, this.height = 28});

  @override
  Widget build(BuildContext context) {
    final blocks = computeRhythmBlocks(dives);
    if (blocks.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return Semantics(
      label: context.l10n.trips_story_rhythm_semantics,
      child: SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _RhythmPainter(
            blocks: blocks,
            trackColor: colorScheme.surfaceContainerHighest,
            dayColor: colorScheme.primary,
            nightColor: colorScheme.tertiary,
            tickTextStyle: labelStyle,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

class _RhythmPainter extends CustomPainter {
  final List<RhythmBlock> blocks;
  final Color trackColor;
  final Color dayColor;
  final Color nightColor;
  final TextStyle? tickTextStyle;
  final TextDirection textDirection;
  final TextScaler textScaler;

  const _RhythmPainter({
    required this.blocks,
    required this.trackColor,
    required this.dayColor,
    required this.nightColor,
    required this.tickTextStyle,
    required this.textDirection,
    required this.textScaler,
  });

  static const _tickHours = [6, 12, 18];

  @override
  void paint(Canvas canvas, Size size) {
    // Reserve scaled label height so ticks aren't clipped at larger text sizes,
    // but clamp it so labels never consume the whole bar (which would make
    // trackHeight negative and produce invalid paint rects at large text scales
    // or small heights).
    final fontSize = tickTextStyle?.fontSize ?? 11.0;
    final labelHeight = (textScaler.scale(fontSize) + 2).clamp(
      0.0,
      size.height,
    );
    final trackHeight = size.height - labelHeight;
    final blockHeight = (trackHeight - 4).clamp(0.0, double.infinity);
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, trackHeight),
      const Radius.circular(4),
    );
    canvas.drawRRect(trackRect, Paint()..color = trackColor);

    for (final block in blocks) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          block.startFraction * size.width,
          2,
          block.widthFraction * size.width,
          blockHeight,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = block.isNight ? nightColor : dayColor,
      );
    }

    for (final hour in _tickHours) {
      final x = hour / 24 * size.width;
      final painter = TextPainter(
        text: TextSpan(text: '$hour:00', style: tickTextStyle),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          (x - painter.width / 2).clamp(0, size.width - painter.width),
          trackHeight + 1,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_RhythmPainter oldDelegate) =>
      oldDelegate.blocks != blocks ||
      oldDelegate.dayColor != dayColor ||
      oldDelegate.nightColor != nightColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.tickTextStyle != tickTextStyle ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.textScaler != textScaler;
}
