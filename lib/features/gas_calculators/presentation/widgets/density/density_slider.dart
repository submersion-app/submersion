import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_display.dart';

/// A labelled slider with its current value in a pill and the range beneath,
/// in the style the other gas calculators use.
///
/// [value], [min] and [max] are in storage units (meters, percent, bar);
/// [convert] maps them to display units, so a depth slider can store meters
/// and still read in feet.
class DensitySlider extends StatelessWidget {
  const DensitySlider({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.icon = Icons.air,
    this.fractionDigits = 0,
    this.convert,
  });

  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final IconData icon;
  final int fractionDigits;
  final double Function(double)? convert;

  String _format(double stored) =>
      '${formatFixedForDisplay(convert?.call(stored) ?? stored, fractionDigits)}'
      '$unit';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final clamped = value.clamp(min, max).toDouble();
    final shown = _format(clamped);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                shown,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: '$label: $shown',
          child: Slider(
            value: clamped,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _format(min),
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                _format(max),
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
