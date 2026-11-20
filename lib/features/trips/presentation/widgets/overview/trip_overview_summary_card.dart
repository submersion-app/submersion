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
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_slots.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';

/// The Prepare overview's one card (#2845): a row per thing to prepare,
/// each a one-line summary that opens its tab. A row whose data has not
/// loaded shows its label alone rather than a zero.
class TripOverviewSummaryCard extends ConsumerWidget {
  final Trip trip;

  /// Where a row goes; without one the page's DefaultTabController is used.
  final ValueChanged<TripDetailTab>? onOpenTab;

  /// Whether the rows that open the other tabs show: not for a new trip,
  /// whose page has no tabs and nothing stored to count (issue #4527, plan
  /// 11). The Plan row always shows.
  final bool tabRows;

  const TripOverviewSummaryCard({
    super.key,
    required this.trip,
    this.onOpenTab,
    this.tabRows = true,
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
    if (!tabRows) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: _planRow(context, l10n),
      );
    }
    final status = StatusColors.of(context);
    final checklist = ref.watch(tripChecklistAllItemsProvider(trip.id)).value;
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
          _planRow(context, l10n),
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

  /// The Plan row: what the trip plans with. It is the Plan card (issue
  /// #4527): a tap opens it, unlocking the page first when it is locked, as
  /// the plan's edit address does.
  Widget _planRow(BuildContext context, AppLocalizations l10n) {
    final slots = TripCardSlotsScope.maybeOf(context);
    final row = _Row(
      icon: Icons.tune,
      label: l10n.trips_overview_plan,
      summary: [TextSpan(text: _planText(l10n, editsInPlace: slots != null))],
      // Locked it keeps its chevron: a tap still opens the card.
      trailing: slots?.isUnlocked ?? false
          ? RecordCardPencil(cardTitle: l10n.trips_overview_plan)
          : null,
      onTap: slots == null ? null : () => slots.openCard(TripCardId.plan),
    );
    return slots?.frame(TripCardId.plan, row) ?? row;
  }

  String _planText(AppLocalizations l10n, {bool editsInPlace = false}) =>
      tripPlanText(l10n, trip, editsInPlace: editsInPlace);
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<InlineSpan>? summary;

  /// Null when there is nothing to open: the Plan row outside a trip page.
  final VoidCallback? onTap;

  /// In place of the chevron: the Plan card's pencil while the page is
  /// unlocked.
  final Widget? trailing;

  const _Row({
    required this.icon,
    required this.label,
    required this.summary,
    required this.onTap,
    this.trailing,
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
      // A row with nothing to open shows no chevron.
      trailing:
          trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
      onTap: onTap,
    );
  }
}

/// The plan in a line. Where the page edits in place it also names the
/// expected dives and runtime once set, which nothing else shows.
String tripPlanText(
  AppLocalizations l10n,
  Trip trip, {
  bool editsInPlace = false,
}) {
  final parts = [
    if (trip.divesPerDayTarget != null)
      l10n.trips_overview_plan_divesPerDay(trip.divesPerDayTarget!),
    if (trip.diversSharingCylinders > 1)
      l10n.trips_overview_plan_sharing(trip.diversSharingCylinders),
    if (editsInPlace && trip.expectedDives != null)
      l10n.trips_scrubber_expectedDives(trip.expectedDives!),
    if (editsInPlace && trip.expectedRuntimeMinutes != null)
      l10n.trips_overview_plan_runtime(trip.expectedRuntimeMinutes!),
  ];
  return parts.isEmpty ? l10n.trips_overview_plan_notSet : parts.join(' · ');
}
