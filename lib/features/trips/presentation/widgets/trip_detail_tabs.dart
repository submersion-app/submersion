import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/checklists/presentation/widgets/trip_checklists_panel.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/start_session_sheet.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_picker_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_view.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_dives_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_itinerary_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_overview_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_photos_tab.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The trip page's tabs, in display order (#2845). Every trip type shows all
/// six; the index doubles as the TabController index.
enum TripDetailTab { overview, itinerary, gear, checklist, dives, photos }

/// The trip page's body (#2845): one scrolling tab row and six views, the
/// same for every trip type and width.
class TripDetailTabs extends ConsumerStatefulWidget {
  final TripWithStats tripWithStats;

  /// Where the Overview's Plan row goes; null pushes the edit page.
  final VoidCallback? onEditPlan;

  /// Opens the trip editor at a day's note (#4625); null hides the action.
  final ValueChanged<TripNoteDay>? onEditDayNote;

  const TripDetailTabs({
    super.key,
    required this.tripWithStats,
    this.onEditPlan,
    this.onEditDayNote,
  });

  @override
  ConsumerState<TripDetailTabs> createState() => _TripDetailTabsState();
}

class _TripDetailTabsState extends ConsumerState<TripDetailTabs> {
  /// Which page of the Overview's story shows. Held here, above the tab
  /// view, because the tab view does not keep an off-screen tab alive: kept
  /// inside the Overview it would be lost on a visit to another tab. Null
  /// until a page is chosen, when the story opens where it opens by rule.
  final _storySelection = ValueNotifier<TripStorySelection?>(null);

  @override
  void didUpdateWidget(TripDetailTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The master-detail pane reuses this widget for the next trip, which
    // starts from its own opening page.
    if (oldWidget.tripWithStats.trip.id != widget.tripWithStats.trip.id) {
      _storySelection.value = null;
    }
  }

  @override
  void dispose() {
    _storySelection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tripWithStats = widget.tripWithStats;
    final onEditPlan = widget.onEditPlan;
    final trip = tripWithStats.trip;
    // Held here for the same reason as the selection above: the story's day
    // picker reads which plans were dived, and that read is dropped with the
    // Overview when another tab shows. Read again on each return, the picker
    // would draw the trip's plans a moment after everything else.
    //
    // Listened to, not watched: the picker reads the answer itself, and
    // nothing here shows it, so an answer must not rebuild every tab. Only
    // once the trip has begun: before that the Overview is the Prepare page,
    // which has no picker.
    if (!trip.startsAfter(clock.now())) {
      ref.listen(tripUndivedPlanIdsProvider(trip.id), (_, _) {});
    }
    return DefaultTabController(
      // Keyed by trip: the master-detail pane reuses this widget for the next
      // trip, which opens on its Overview, not on the tab left open before.
      key: ValueKey(trip.id),
      length: TripDetailTab.values.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l10n.trips_detail_tab_overview),
                Tab(text: l10n.trips_detail_tab_itinerary),
                Tab(text: l10n.trips_detail_tab_gear),
                Tab(text: l10n.trips_detail_tab_checklist),
                Tab(text: l10n.trips_detail_tab_dives),
                Tab(text: l10n.trips_detail_tab_photos),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                TripOverviewTab(
                  tripWithStats: tripWithStats,
                  onEditPlan: onEditPlan,
                  selection: _storySelection,
                  onEditDayNote: widget.onEditDayNote,
                ),
                TripItineraryTab(tripId: trip.id),
                TripGearTab(trip: trip),
                _ChecklistTab(trip: trip),
                TripDivesTab(tripId: trip.id),
                TripPhotosTab(tripId: trip.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The pre-dive checklist button over the trip's to-do list, as the
/// liveaboard tab had it.
class _ChecklistTab extends StatelessWidget {
  final Trip trip;

  const _ChecklistTab({required this.trip});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.fact_check),
              label: Text(context.l10n.trips_detail_preDive_action),
              onPressed: () => showStartSessionSheet(context, tripId: trip.id),
            ),
          ),
          const SizedBox(height: 12),
          TripChecklistsPanel(trip: trip),
        ],
      ),
    );
  }
}
