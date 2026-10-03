import 'package:flutter/material.dart';

import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_section.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/start_session_sheet.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_tab.dart';
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
class TripDetailTabs extends StatelessWidget {
  final TripWithStats tripWithStats;

  const TripDetailTabs({super.key, required this.tripWithStats});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trip = tripWithStats.trip;
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
                TripOverviewTab(tripWithStats: tripWithStats),
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
          TripChecklistSection(trip: trip),
        ],
      ),
    );
  }
}
