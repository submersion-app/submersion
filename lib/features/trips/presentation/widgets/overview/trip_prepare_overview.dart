import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/presentation/widgets/overview/trip_overview_summary_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Overview before departure (#2845): the hero with its countdown, one
/// summary card whose rows open the other tabs, and the notes. No map, no
/// stats, no story: there is nothing to tell yet.
class TripPrepareOverview extends StatelessWidget {
  final TripStory story;
  final ValueChanged<TripDetailTab>? onOpenTab;

  const TripPrepareOverview({super.key, required this.story, this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final trip = story.trip;
    final theme = Theme.of(context);
    return ListView(
      key: const Key('trip-prepare-overview'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TripStoryHero(
            story: story,
            showEmptyState: false,
            showChecklist: false,
          ),
        ),
        TripOverviewSummaryCard(trip: trip, onOpenTab: onOpenTab),
        if (trip.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.trips_detail_sectionTitle_notes,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(trip.notes),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
