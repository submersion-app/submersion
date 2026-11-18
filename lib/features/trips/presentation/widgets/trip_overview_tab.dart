import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_scan_actions.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/overview/trip_prepare_overview.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_view.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Overview tab for a trip: the Prepare page before the first day, the
/// story from then on (#2845), one day at a time.
class TripOverviewTab extends ConsumerWidget {
  final TripWithStats tripWithStats;

  /// Where the Prepare overview's rows go; null uses the page's
  /// DefaultTabController.
  final ValueChanged<TripDetailTab>? onOpenTab;

  /// Where the Prepare overview's Plan row goes; null pushes the edit page.
  final VoidCallback? onEditPlan;

  /// Which page of the story shows, held above the tabs so it survives a
  /// visit to another tab; null lets the story keep its own.
  final ValueNotifier<TripStorySelection?>? selection;

  /// Opens the trip editor at a day's note (#4625); null hides the action.
  final ValueChanged<TripNoteDay>? onEditDayNote;

  const TripOverviewTab({
    super.key,
    required this.tripWithStats,
    this.onOpenTab,
    this.onEditPlan,
    this.selection,
    this.onEditDayNote,
  });

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

    // Before the first day there is nothing to tell: the page prepares.
    // From the first day on, in progress or past, it tells the story.
    if (trip.startsAfter(clock.now())) {
      return TripPrepareOverview(
        story: story,
        onOpenTab: onOpenTab,
        onEditPlan: onEditPlan,
      );
    }
    return TripStoryView(
      story: story,
      stats: tripWithStats,
      selection: selection,
      onScanForDives: () => scanForTripDives(context, ref, trip),
      onEditDayNote: onEditDayNote,
    );
  }
}
