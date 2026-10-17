import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/widgets/summary/scene_text.dart';

/// Where a depth sits on the water column, as a fraction of the pane
/// height: the surface line is at 18 %, [maxMeters] at 90 %.
double depthToFraction(double meters, double maxMeters) =>
    0.18 + (meters / maxMeters).clamp(0.0, 1.0) * 0.72;

/// The hairline depth scale at the end edge of the water column, with tick
/// labels at the surface, one step and two steps down.
class DepthScale extends StatelessWidget {
  const DepthScale({super.key, required this.maxMeters, required this.units});

  final double maxMeters;
  final UnitFormatter units;

  static const double width = 56;

  @override
  Widget build(BuildContext context) {
    final ink = SceneInk.of(context);
    final tickStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: ink.withValues(alpha: 0.55),
      letterSpacing: 0.6,
      shadows: SceneInk.shadowsOf(context),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        // The maximum is two and a quarter steps (scaleMaxMeters), so the
        // ticks fall on the round step and its double.
        final step = maxMeters / 2.25;
        return SizedBox(
          width: width,
          height: h,
          child: Stack(
            children: [
              PositionedDirectional(
                end: 0,
                top: h * 0.18,
                bottom: h * 0.10,
                child: Container(width: 1, color: ink.withValues(alpha: 0.4)),
              ),
              for (final meters in [0.0, step, step * 2])
                PositionedDirectional(
                  end: 8,
                  top: h * depthToFraction(meters, maxMeters) - 7,
                  child: Text(
                    units.formatDepth(meters, decimals: 0),
                    style: tickStyle,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A depth placed on the water column: a glowing dot, the value, a label,
/// and a hairline running across the pane at that depth.
///
/// The scene positions it so its top sits [lineOffset] above the depth.
class DepthMarker extends StatelessWidget {
  const DepthMarker({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
    this.semanticsLabel,
    this.compact = false,
  });

  final String value;
  final String label;

  /// Opens what the marker stands for; null for a plain label.
  final VoidCallback? onTap;
  final String? semanticsLabel;

  /// Hides the label (another marker sits close by, or the pane is narrow);
  /// the value then carries the link.
  final bool compact;

  /// Distance from the marker's top to the depth line it marks.
  static const double lineOffset = 15;

  @override
  Widget build(BuildContext context) {
    final ink = SceneInk.of(context);
    final valueStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w300,
      color: ink,
      height: 1.1,
      shadows: SceneInk.shadowsOf(context),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: lineOffset - 3),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ink.withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(color: ink.withValues(alpha: 0.9), blurRadius: 10),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            // The text wraps inside two thirds of the row; the hairline takes
            // whatever is left, out to the depth scale.
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 2 / 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (compact && onTap != null)
                  SceneLink(
                    text: value,
                    onTap: onTap!,
                    semanticsLabel: semanticsLabel ?? '$value, $label',
                    style: valueStyle,
                  )
                else
                  Text(value, style: valueStyle),
                if (!compact)
                  onTap == null
                      ? SceneLabel(label)
                      : SceneLink(
                          text: label,
                          onTap: onTap!,
                          semanticsLabel: semanticsLabel ?? '$value, $label',
                        ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: lineOffset),
              child: Container(
                key: const ValueKey('depth-marker-line'),
                height: 1,
                color: ink.withValues(alpha: 0.12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
