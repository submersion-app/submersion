import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/domain/services/trip_gear_split.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Prepare overview's one card (#2845): a row per thing to prepare,
/// each a one-line summary that opens its tab. A row whose data has not
/// loaded shows its label alone rather than a zero.
class TripOverviewSummaryCard extends ConsumerWidget {
  final Trip trip;

  /// Where a row goes; without one the page's DefaultTabController is used.
  final ValueChanged<TripDetailTab>? onOpenTab;

  /// Where the Plan row goes; without one the edit page is pushed, open at
  /// its Planning section. The page passes one so that in the master-detail
  /// pane the edit opens in the pane (#2880).
  final VoidCallback? onEditPlan;

  const TripOverviewSummaryCard({
    super.key,
    required this.trip,
    this.onOpenTab,
    this.onEditPlan,
  });

  void _open(BuildContext context, TripDetailTab tab) {
    final handler = onOpenTab;
    if (handler != null) {
      handler(tab);
    } else {
      DefaultTabController.of(context).animateTo(tab.index);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = StatusColors.of(context);
    final checklist = ref.watch(tripChecklistProvider(trip.id)).value;
    final gear = ref.watch(tripGearProvider(trip.id)).value;
    final slots = ref.watch(tripCylinderStatesProvider(trip.id)).value;
    final alerts = ref.watch(tripServiceAlertsProvider(trip.id)).value;
    final days = ref.watch(itineraryDaysProvider(trip.id)).value;

    List<InlineSpan>? gearSpans;
    if (gear != null && slots != null) {
      final alertCount = alerts == null ? 0 : tripServiceAlertItemCount(alerts);
      // Counted as the Gear tab lists them (#2873): a slotted tank once, as
      // its slot, and a packed tank with no slot as a cylinder.
      final (:packed, :unslottedTanks) = splitTripGear(gear, [
        for (final s in slots) s.cylinder,
      ]);
      final cylinderCount = slots.length + unslottedTanks.length;
      gearSpans = [
        TextSpan(text: l10n.trips_overview_gear_packed(packed.length)),
        if (cylinderCount > 0)
          TextSpan(
            text: ' · ${l10n.trips_overview_gear_cylinders(cylinderCount)}',
          ),
        if (alertCount > 0)
          TextSpan(
            text: ' · ${l10n.trips_overview_gear_serviceAlerts(alertCount)}',
            style: TextStyle(
              color: tripServiceAlertsAnyOverdue(alerts!)
                  ? status.alert.accent
                  : status.warn.accent,
            ),
          ),
      ];
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _Row(
            icon: Icons.checklist,
            label: l10n.trips_detail_tab_checklist,
            summary: checklist == null
                ? null
                : _checklistSpans(l10n, status, checklist),
            onTap: () => _open(context, TripDetailTab.checklist),
          ),
          _Row(
            icon: Icons.luggage_outlined,
            label: l10n.trips_detail_tab_gear,
            summary: gearSpans,
            onTap: () => _open(context, TripDetailTab.gear),
          ),
          _Row(
            icon: Icons.event_note,
            label: l10n.trips_detail_tab_itinerary,
            // The days the Itinerary tab lists: a plan-only row outside the
            // trip's dates is left over from a moved trip (#2663).
            summary: days == null
                ? null
                : _itinerarySpans(l10n, tripStoryItinerary(trip, days)),
            onTap: () => _open(context, TripDetailTab.itinerary),
          ),
          _Row(
            icon: Icons.tune,
            label: l10n.trips_overview_plan,
            summary: [TextSpan(text: _planText(l10n))],
            onTap:
                onEditPlan ??
                () => openTripEdit(
                  context,
                  trip.id,
                  embedded: false,
                  section: TripEditSection.planning,
                ),
          ),
        ],
      ),
    );
  }

  /// Done count, then what presses within a week or is already late.
  List<InlineSpan> _checklistSpans(
    AppLocalizations l10n,
    StatusColors status,
    List<TripChecklistItem> checklist,
  ) {
    final today = tripDay(clock.now());
    final weekOut = DateTime(today.year, today.month, today.day + 7);
    var overdue = 0;
    var dueSoon = 0;
    for (final item in checklist) {
      final due = item.dueDate;
      if (item.isDone || due == null) continue;
      final day = tripDay(due);
      if (day.isBefore(today)) {
        overdue++;
      } else if (!day.isAfter(weekOut)) {
        dueSoon++;
      }
    }
    final done = checklist.where((i) => i.isDone).length;
    return [
      TextSpan(
        text: l10n.trips_overview_checklist_progress(done, checklist.length),
      ),
      if (dueSoon > 0)
        TextSpan(
          text: ' · ${l10n.trips_overview_checklist_dueSoon(dueSoon)}',
          style: TextStyle(color: status.warn.accent),
        ),
      if (overdue > 0)
        TextSpan(
          text: ' · ${l10n.trips_overview_checklist_overdue(overdue)}',
          style: TextStyle(color: status.alert.accent),
        ),
    ];
  }

  /// Rows, and the dives they plan: a set count, else the per-day target
  /// on a dive day, else nothing (plan ruling R5).
  List<InlineSpan> _itinerarySpans(
    AppLocalizations l10n,
    List<ItineraryDay> days,
  ) {
    if (days.isEmpty) {
      return [TextSpan(text: l10n.trips_overview_itinerary_none)];
    }
    var planned = 0;
    for (final d in days) {
      planned +=
          d.plannedDives ??
          (d.dayType == DayType.diveDay ? (trip.divesPerDayTarget ?? 0) : 0);
    }
    return [
      TextSpan(text: l10n.trips_overview_itinerary_days(days.length)),
      if (planned > 0)
        TextSpan(
          text: ' · ${l10n.trips_overview_itinerary_divesPlanned(planned)}',
        ),
    ];
  }

  /// The edit page's planning numbers.
  String _planText(AppLocalizations l10n) {
    final parts = [
      if (trip.divesPerDayTarget != null)
        l10n.trips_overview_plan_divesPerDay(trip.divesPerDayTarget!),
      if (trip.diversSharingCylinders > 1)
        l10n.trips_overview_plan_sharing(trip.diversSharingCylinders),
    ];
    return parts.isEmpty ? l10n.trips_overview_plan_notSet : parts.join(' · ');
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<InlineSpan>? summary;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.label,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spans = summary;
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      // The summary is the subtitle, never the trailing slot: a trailing
      // widget takes its width before the title is laid out.
      subtitle: spans == null
          ? null
          : Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                children: spans,
              ),
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
