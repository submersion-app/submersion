import 'package:flutter/material.dart';

/// Shared row and flag widgets for the Best Mix calculator's cards, split
/// out of the single widget file so every card can use the same look.

Widget bestMixBreakdownRow(
  BuildContext context,
  String label,
  String value, {
  bool isHighlight = false,
  bool onContainer = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  final labelColor = onContainer
      ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
      : (isHighlight ? colorScheme.primary : colorScheme.onSurfaceVariant);
  final valueColor = onContainer
      ? colorScheme.onPrimaryContainer
      : (isHighlight ? colorScheme.primary : null);

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: labelColor,
              fontWeight: isHighlight ? FontWeight.w600 : null,
            ),
          ),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    ),
  );
}

Widget bestMixFlag(BuildContext context, String text, Color color) {
  final textTheme = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: textTheme.bodySmall?.copyWith(color: color)),
        ),
      ],
    ),
  );
}

/// A small caption above a toggle, shared by the input and density cards.
class BestMixLabelled extends StatelessWidget {
  const BestMixLabelled({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
