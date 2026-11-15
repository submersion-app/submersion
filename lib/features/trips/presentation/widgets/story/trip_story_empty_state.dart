import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// What a trip with no dives and no itinerary shows in place of its story,
/// with the action that looks for dives in the trip's dates.
class TripStoryEmptyState extends StatelessWidget {
  const TripStoryEmptyState({super.key, required this.onScanForDives});

  /// Looks for dives in the trip's dates; null hides the button.
  final VoidCallback? onScanForDives;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.auto_stories,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.trips_story_empty_title,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.trips_story_empty_subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (onScanForDives != null)
            FilledButton.icon(
              icon: const Icon(Icons.playlist_add, size: 18),
              label: Text(context.l10n.trips_diveScan_findButton),
              onPressed: onScanForDives,
            ),
        ],
      ),
    );
  }
}
