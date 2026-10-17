import 'package:flutter/material.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';

/// A feature's health as a round symbol: a glyph as well as a colour, so the
/// meaning never rests on colour alone. Not set up is a hollow outline, so
/// an unused feature reads as absent rather than as a fourth status.
class HealthSymbol extends StatelessWidget {
  const HealthSymbol({
    super.key,
    required this.level,
    this.size = 26,
    this.semanticLabel,
  });

  final HealthLevel level;
  final double size;

  /// Read by screen readers; null leaves the symbol out of semantics, for a
  /// caller that labels the whole item.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final status = StatusColors.of(context);
    final outline = Theme.of(context).colorScheme.outline;
    final (Color? fill, Color glyphColor, IconData glyph) = switch (level) {
      HealthLevel.healthy => (
        status.ok.accent,
        status.ok.onAccent,
        Icons.check,
      ),
      HealthLevel.attention => (
        status.warn.accent,
        status.warn.onAccent,
        Icons.priority_high,
      ),
      HealthLevel.failing => (
        status.alert.accent,
        status.alert.onAccent,
        Icons.close,
      ),
      HealthLevel.notSetUp => (null, outline, Icons.remove),
    };
    final symbol = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: fill == null ? Border.all(color: outline, width: 1.5) : null,
      ),
      child: Icon(glyph, size: size * 0.62, color: glyphColor),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: symbol);
    return Semantics(label: label, excludeSemantics: true, child: symbol);
  }
}
