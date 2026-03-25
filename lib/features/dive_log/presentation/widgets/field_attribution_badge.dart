import 'package:flutter/material.dart';

/// Inline badge showing which data source provided a metric value.
///
/// Only rendered when [sourceName] is non-null. Designed to sit at the
/// trailing edge of a metric row.
class FieldAttributionBadge extends StatelessWidget {
  final String? sourceName;

  const FieldAttributionBadge({super.key, this.sourceName});

  @override
  Widget build(BuildContext context) {
    if (sourceName == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        sourceName!,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontSize: 10,
        ),
      ),
    );
  }
}
