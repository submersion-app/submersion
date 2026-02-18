import 'package:flutter/material.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/features/settings/presentation/widgets/custom_gradient_dialog.dart';

/// A horizontal scrollable row of gradient swatch cards.
/// Each card shows a linear gradient preview. The selected preset has a
/// checkmark overlay. The last card labeled "Custom" opens the
/// [CustomGradientDialog].
class GradientPresetPicker extends StatelessWidget {
  final String selectedPreset;
  final int? customStart;
  final int? customEnd;
  final ValueChanged<String> onPresetSelected;
  final void Function(int start, int end) onCustomSelected;

  const GradientPresetPicker({
    super.key,
    required this.selectedPreset,
    this.customStart,
    this.customEnd,
    required this.onPresetSelected,
    required this.onCustomSelected,
  });

  @override
  Widget build(BuildContext context) {
    final presetEntries = cardColorPresets.entries.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Built-in presets
          for (final entry in presetEntries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _GradientSwatch(
                label: entry.value.name,
                startColor: entry.value.startColor,
                endColor: entry.value.endColor,
                isSelected: selectedPreset == entry.key,
                onTap: () => onPresetSelected(entry.key),
              ),
            ),
          // Custom swatch
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CustomGradientSwatch(
              customStart: customStart,
              customEnd: customEnd,
              isSelected: selectedPreset == 'custom',
              onTap: () => _openCustomDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCustomDialog(BuildContext context) async {
    final initialStart = customStart != null ? Color(customStart!) : null;
    final initialEnd = customEnd != null ? Color(customEnd!) : null;

    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => CustomGradientDialog(
        initialStart: initialStart,
        initialEnd: initialEnd,
      ),
    );

    if (result != null) {
      onCustomSelected(result.$1, result.$2);
    }
  }
}

/// A single gradient swatch card showing a gradient preview with an
/// optional checkmark overlay.
class _GradientSwatch extends StatelessWidget {
  final String label;
  final Color startColor;
  final Color endColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _GradientSwatch({
    required this.label,
    required this.startColor,
    required this.endColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(colors: [startColor, endColor]),
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : null,
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Custom" swatch at the end of the preset row. Shows the custom
/// gradient if colors are provided, otherwise shows a dashed-border
/// placeholder.
class _CustomGradientSwatch extends StatelessWidget {
  final int? customStart;
  final int? customEnd;
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomGradientSwatch({
    this.customStart,
    this.customEnd,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCustomColors = customStart != null && customEnd != null;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (hasCustomColors)
                Container(
                  width: 60,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [Color(customStart!), Color(customEnd!)],
                    ),
                    border: isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                )
              else
                CustomPaint(
                  size: const Size(60, 40),
                  painter: _DashedBorderPainter(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: 8,
                  ),
                ),
              if (isSelected)
                const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                )
              else if (!hasCustomColors)
                Icon(
                  Icons.add,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Custom',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a dashed rounded rectangle border as a placeholder for the
/// custom gradient swatch when no custom colors have been chosen.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  _DashedBorderPainter({required this.color, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1),
      Radius.circular(borderRadius),
    );

    const dashLength = 4.0;
    const gapLength = 3.0;

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0, metric.length);
        final segment = metric.extractPath(distance, end.toDouble());
        canvas.drawPath(segment, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        borderRadius != oldDelegate.borderRadius;
  }
}
