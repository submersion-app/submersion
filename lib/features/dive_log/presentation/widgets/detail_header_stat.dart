import 'package:flutter/material.dart';

/// One stat in the row along the bottom of a detail page's header card: an
/// icon over a value over its label.
///
/// Shared by the dive and site detail headers so the two rows read the same.
class DetailHeaderStat extends StatelessWidget {
  const DetailHeaderStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;

  /// The formatted value, already in the active diver's units.
  final String value;

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ExcludeSemantics(child: Icon(icon, color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
