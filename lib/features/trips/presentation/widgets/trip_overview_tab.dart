import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_scan_actions.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Overview tab for a trip: the interactive day-by-day trip story.
class TripOverviewTab extends ConsumerWidget {
  final TripWithStats tripWithStats;

  const TripOverviewTab({super.key, required this.tripWithStats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = tripWithStats.trip;
    final storyAsync = ref.watch(tripStoryProvider(trip.id));
    // Render last-known data during reloads to avoid loading flashes on
    // sync invalidations.
    final story = storyAsync.valueOrNull;

    if (story == null) {
      if (storyAsync.hasError) {
        return Center(
          child: Text(
            '${context.l10n.common_label_error}: ${storyAsync.error}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return TripStoryView(
      story: story,
      stats: tripWithStats,
      onScanForDives: () => scanForTripDives(context, ref, trip),
    );
  }
}
