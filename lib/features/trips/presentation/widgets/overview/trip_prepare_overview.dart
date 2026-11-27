import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_slots.dart';
import 'package:submersion/features/trips/presentation/editing/trip_header_card_editor.dart';
import 'package:submersion/features/trips/presentation/widgets/overview/trip_overview_summary_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_vessel_section.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';

/// The Overview before departure (#2845): the hero with its countdown, the
/// line of the trip's type, location, resort and sharing, one summary card
/// whose rows open the other tabs, and the notes. No map, no
/// stats, no story: there is nothing to tell yet.
class TripPrepareOverview extends StatelessWidget {
  final TripStory story;
  final ValueChanged<TripDetailTab>? onOpenTab;

  /// Whether the summary card's rows that open the other tabs show; see
  /// [TripOverviewSummaryCard.tabRows].
  final bool tabRows;

  const TripPrepareOverview({
    super.key,
    required this.story,
    this.onOpenTab,
    this.tabRows = true,
  });

  @override
  Widget build(BuildContext context) {
    // On the trip page, the cards show the sitting's trip and sit in its frames
    // (issue #4527).
    final slots = TripCardSlotsScope.maybeOf(context);
    final trip = slots?.shown ?? story.trip;
    Widget framed(TripCardId id, Widget child) =>
        slots?.frame(id, child) ?? child;
    final theme = Theme.of(context);
    return ListView(
      key: const Key('trip-prepare-overview'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TripStoryHero(
            story: story,
            // The header block's name and dates as the sitting holds them.
            trip: trip,
            showEmptyState: false,
            showChecklist: false,
          ),
        ),
        // The trip's type, where it is, its resort and who it is shared
        // with, on one line under the hero, and the header block's editor
        // (issue #4927).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: framed(TripCardId.header, TripHeaderRows(trip: trip)),
        ),
        TripOverviewSummaryCard(
          trip: trip,
          onOpenTab: onOpenTab,
          tabRows: tabRows,
        ),
        // A liveaboard's vessel, before departure too, on the trip page
        // (issue #4527).
        if (slots != null && trip.isLiveaboard)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: framed(
              TripCardId.vessel,
              TripVesselSection(tripId: trip.id, session: slots.session),
            ),
          ),
        if (trip.notes.isNotEmpty ||
            (slots?.showsWhileEmpty(TripCardId.notes) ?? false))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: framed(
              TripCardId.notes,
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.trips_detail_sectionTitle_notes,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // The card's pencil while the page edits in place.
                          RecordCardPencil(
                            cardTitle:
                                context.l10n.trips_detail_sectionTitle_notes,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      MarkdownNotesView(trip.notes),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: framed(
            TripCardId.documents,
            DocumentsSection(
              owner: DocumentOwner(DocumentOwnerKind.trip, trip.id),
            ),
          ),
        ),
      ],
    );
  }
}
