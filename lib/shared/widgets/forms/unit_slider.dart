import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_axis.dart';

/// A labelled slider bound to a [UnitAxis].
///
/// [value] and the value emitted by [onChanged] are always CANONICAL. The axis
/// owns every conversion, so a caller cannot accidentally mix display and
/// canonical values.
class UnitSlider extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Current value in canonical (storage) units.
  final double value;

  final UnitAxis axis;

  /// Receives canonical (storage) units.
  final ValueChanged<double> onChanged;

  const UnitSlider({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.axis,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Clamped because a stored value may predate a units change, and Slider
    // asserts when handed a value outside its own bounds.
    final display = axis.toDisplay(value).clamp(axis.min, axis.max).toDouble();
    final readout = '${axis.format(display)} ${axis.symbol}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                readout,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.surfaceContainerHighest,
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Semantics(
            label: '$label: $readout',
            child: Slider(
              value: display,
              min: axis.min,
              max: axis.max,
              divisions: axis.divisions,
              onChanged: (v) => onChanged(axis.toCanonical(v)),
            ),
          ),
        ),
      ],
    );
  }
}
