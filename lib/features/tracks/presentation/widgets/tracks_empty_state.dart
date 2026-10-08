import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the list shows with no rows: why the area exists, or, when filters
/// are active, that the filters hid everything and a way to clear them.
class TracksEmptyState extends ConsumerWidget {
  const TracksEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Filters explain an empty list only when the library has tracks; an
    // empty library keeps the onboarding text whatever a link set.
    final hasTracks =
        (ref.watch(gpsTracksProvider).value?.isNotEmpty ?? false) ||
        (ref.watch(allNavTracksProvider).value?.isNotEmpty ?? false);
    final filtered =
        hasTracks &&
        (ref.watch(trackKindFilterProvider) != TrackKindFilter.all ||
            ref.watch(trackDateFilterProvider) != null);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered ? Icons.filter_alt_off_outlined : Icons.route_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            filtered ? l10n.tracks_empty_filtered : l10n.tracks_empty_title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (filtered)
            TextButton(
              key: const ValueKey('tracks-clear-filters'),
              onPressed: () {
                ref.read(trackKindFilterProvider.notifier).state =
                    TrackKindFilter.all;
                ref.read(trackDateFilterProvider.notifier).state = null;
              },
              child: Text(l10n.tracks_empty_clearFilters),
            )
          else
            Text(
              l10n.tracks_empty_body,
              style: muted,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
