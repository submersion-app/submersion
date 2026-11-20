import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/checklists/presentation/widgets/trip_checklists_panel.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/start_session_sheet.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_slots.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_picker_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_view.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_dives_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_itinerary_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_overview_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_photos_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tab.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_tabs.dart';

export 'package:submersion/features/trips/presentation/widgets/trip_detail_tab.dart';

/// The trip page's body (#2845): one scrolling tab row and six views, the
/// same for every trip type and width.
class TripDetailTabs extends ConsumerStatefulWidget {
  final TripWithStats tripWithStats;

  /// Where the Overview's Plan row goes; null pushes the edit page.
  final VoidCallback? onEditPlan;

  /// Opens the trip editor at a day's note (#4625); null hides the action.
  final ValueChanged<TripNoteDay>? onEditDayNote;

  /// The tab controller of a page that edits in place (issue #4527), which
  /// needs to know the tab in view and to bring another forward. With one,
  /// each tab is kept alive while the trip is unlocked. Null uses a tab
  /// controller of its own.
  final TabController? controller;

  /// Which page of the Overview's story shows, held by a page that opens
  /// the story at a day. Null holds it here.
  final ValueNotifier<TripStorySelection?>? storySelection;

  const TripDetailTabs({
    super.key,
    required this.tripWithStats,
    this.onEditPlan,
    this.onEditDayNote,
    this.controller,
    this.storySelection,
  });

  @override
  ConsumerState<TripDetailTabs> createState() => _TripDetailTabsState();
}

class _TripDetailTabsState extends ConsumerState<TripDetailTabs> {
  /// Which page of the Overview's story shows. Held here, above the tab
  /// view, because the tab view does not keep an off-screen tab alive: kept
  /// inside the Overview it would be lost on a visit to another tab. Null
  /// until a page is chosen, when the story opens where it opens by rule.
  final _ownSelection = ValueNotifier<TripStorySelection?>(null);

  ValueNotifier<TripStorySelection?> get _storySelection =>
      widget.storySelection ?? _ownSelection;

  @override
  void didUpdateWidget(TripDetailTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The master-detail pane reuses this widget for the next trip, which
    // starts from its own opening page.
    if (oldWidget.tripWithStats.trip.id != widget.tripWithStats.trip.id &&
        widget.storySelection == null) {
      _ownSelection.value = null;
    }
  }

  @override
  void dispose() {
    _ownSelection.dispose();
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
    // A page that edits in place keeps the gear and checklists read only
    // until they join its sitting (issue #4527).
    final editsInPlace = TripCardSlotsScope.maybeOf(context) != null;
    final controller = widget.controller;
    // Kept alive while unlocked, so an open card survives a visit to
    // another tab.
    Widget kept(Widget view) =>
        controller == null ? view : RecordEditKeepAlive<Trip>(child: view);
    final body = Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: controller,
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
            controller: controller,
            children: [
              kept(
                TripOverviewTab(
                  tripWithStats: tripWithStats,
                  // With the page's controller there is no
                  // DefaultTabController for the rows to find.
                  onOpenTab: controller == null
                      ? null
                      : (tab) => controller.animateTo(tab.index),
                  onEditPlan: onEditPlan,
                  selection: _storySelection,
                  onEditDayNote: widget.onEditDayNote,
                ),
              ),
              kept(TripItineraryTab(tripId: trip.id)),
              kept(TripGearTab(trip: trip, readOnly: editsInPlace)),
              kept(_ChecklistTab(trip: trip, readOnly: editsInPlace)),
              kept(TripDivesTab(tripId: trip.id)),
              kept(TripPhotosTab(tripId: trip.id)),
            ],
          ),
        ),
      ],
    );
    if (controller != null) return body;
    return DefaultTabController(
      // Keyed by trip: the master-detail pane reuses this widget for the next
      // trip, which opens on its Overview, not on the tab left open before.
      key: ValueKey(trip.id),
      length: TripDetailTab.values.length,
      child: body,
    );
  }
}

/// The pre-dive checklist button over the trip's to-do list, as the
/// liveaboard tab had it.
class _ChecklistTab extends StatelessWidget {
  final Trip trip;

  /// The checklists offer no change; starting a pre-dive session, which
  /// makes a record of its own, still works.
  final bool readOnly;

  const _ChecklistTab({required this.trip, this.readOnly = false});

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
          TripChecklistsPanel(trip: trip, readOnly: readOnly),
        ],
      ),
    );
  }
}
