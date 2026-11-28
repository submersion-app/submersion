import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_strings.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The trim verdict and its two gauges (issue #5028): pitch from head-heavy
/// to feet-heavy and roll from left to right, each a bar from the centre.
class TrimGauges extends StatelessWidget {
  const TrimGauges({super.key, required this.result});

  final TrimResult result;

  /// The pull, in kg m, at which a bar reaches its end.
  static const double fullScaleKgM = kSlightBandKgM * 1.5;

  /// Roll's full scale, from its own tighter bands.
  static const double rollFullScaleKgM = kRollSlightBandKgM * 1.5;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(trimVerdictLine(result, l10n), style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _Gauge(
          label: l10n.trim_gauge_pitch,
          value: result.pitchKgM,
          fullScale: fullScaleKgM,
          start: l10n.trim_gauge_headHeavy,
          end: l10n.trim_gauge_feetHeavy,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 6),
        _Gauge(
          label: l10n.trim_gauge_roll,
          value: result.rollKgM,
          fullScale: rollFullScaleKgM,
          start: l10n.trim_gauge_left,
          end: l10n.trim_gauge_right,
          color: theme.colorScheme.tertiary,
        ),
      ],
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.label,
    required this.value,
    required this.fullScale,
    required this.start,
    required this.end,
    required this.color,
  });

  final String label;
  final double value;

  /// The pull, in kg m, at which the bar reaches its end.
  final double fullScale;
  final String start;
  final String end;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final fraction = (value / fullScale).clamp(-1.0, 1.0);
    // Head to feet and left to right are physical directions, drawn as the
    // figure faces: they never mirror in a right-to-left language.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56, child: Text(label, style: small)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 8,
                  child: CustomPaint(
                    painter: _GaugePainter(
                      fraction: fraction,
                      color: color,
                      track: theme.colorScheme.surfaceContainerHighest,
                      centre: theme.colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(child: Text(start, style: small)),
                    Expanded(
                      child: Text(end, style: small, textAlign: TextAlign.end),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.centre,
  });

  final double fraction;
  final Color color;
  final Color track;
  final Color centre;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.width / 2;
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = track,
    );
    final reach = mid * fraction;
    final bar = Rect.fromLTRB(
      reach < 0 ? mid + reach : mid,
      0,
      reach < 0 ? mid : mid + reach,
      size.height,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(bar, r), Paint()..color = color);
    canvas.drawRect(
      Rect.fromLTWH(mid - 0.5, -2, 1, size.height + 4),
      Paint()..color = centre,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
