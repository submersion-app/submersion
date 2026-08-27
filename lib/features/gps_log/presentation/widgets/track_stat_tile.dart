import 'package:flutter/material.dart';

/// One labelled figure: a small muted label over a medium-weight value.
///
/// Shared by the per-track stats header and the logger page's summary strip
/// so the two read as one system rather than two hand-rolled columns.
class TrackStatTile extends StatelessWidget {
  const TrackStatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
