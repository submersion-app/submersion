import 'package:flutter/material.dart';

/// A labelled slider row used by the surface interval input cards.
///
/// Renders the field label and icon on the left, the current value in a pill
/// on the right, the [slider] beneath, and the range bounds under that.
class SiSliderRow extends StatelessWidget {
  const SiSliderRow({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.slider,
    required this.minLabel,
    required this.maxLabel,
  });

  /// Field name shown next to [icon].
  final String label;

  /// Leading icon for the field.
  final IconData icon;

  /// Formatted current value shown in the trailing pill.
  final String value;

  /// The slider itself, supplied by the caller so it can own its state binding.
  final Widget slider;

  /// Formatted lower bound shown under the slider.
  final String minLabel;

  /// Formatted upper bound shown under the slider.
  final String maxLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.bodyMedium),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        slider,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel, style: theme.textTheme.bodySmall),
              Text(maxLabel, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
