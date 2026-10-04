import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary_day_edit_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';

/// Itinerary tab showing the day-by-day timeline of a trip, any type
/// (#2845): Generate fills the dates, each day opens its edit sheet.
///
/// Groups dives by date under each itinerary day. Each day row is tappable
/// to edit day type, port name, and notes via a bottom sheet.
class TripItineraryTab extends ConsumerWidget {
  final String tripId;

  const TripItineraryTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(numberedItineraryDaysProvider(tripId));
    final divesAsync = ref.watch(divesForTripProvider(tripId));
    // The trip types the days Generate writes and labels the sheet's place
    // field; a trip that is gone shows the list without the button.
    final trip = ref.watch(tripByIdProvider(tripId)).value;

    // Keep the list on a reload: the numbered itinerary rebuilds whenever
    // the itinerary, the trip or its dives change (an edit-sheet save among
    // them), and `when` shows its loading branch on a reload by default,
    // which would swap the list for a spinner and lose the scroll position.
    return daysAsync.when(
      skipLoadingOnReload: true,
      data: (days) => divesAsync.when(
        data: (dives) => _buildTimeline(context, ref, days, dives, trip),
        loading: () => const Center(child: CircularProgressIndicator()),
        // The repositories log the failure; the diver gets a plain line.
        error: (_, _) =>
            Center(child: Text(context.l10n.trips_itinerary_error_loading)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(context.l10n.trips_itinerary_error_loading)),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    WidgetRef ref,
    List<ItineraryDay> days,
    List<Dive> dives,
    Trip? trip,
  ) {
    if (days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.trips_itinerary_empty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (trip != null) ...[
                const SizedBox(height: 16),
                TripItineraryGenerateButton(trip: trip, days: days),
              ],
            ],
          ),
        ),
      );
    }

    // Group dives by date (year-month-day key)
    final divesByDate = <String, List<Dive>>{};
    for (final dive in dives) {
      final key = _dateKey(dive.dateTime);
      divesByDate.putIfAbsent(key, () => []).add(dive);
    }

    // Sort each group by time (creating sorted copies to avoid mutation)
    final sortedDivesByDate = divesByDate.map(
      (key, group) => MapEntry(
        key,
        List<Dive>.of(group)..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
      ),
    );

    // The fill-in button renders nothing once every date has a row.
    final header = trip == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TripItineraryGenerateButton(trip: trip, days: days),
            ),
          );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length + (header == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (header != null) {
          if (index == 0) return header;
          index -= 1;
        }
        final day = days[index];
        final dayDives = sortedDivesByDate[_dateKey(day.date)] ?? [];
        return _ItineraryDayCard(
          day: day,
          dives: dayDives,
          tripId: tripId,
          isLiveaboard: trip?.isLiveaboard ?? false,
        );
      },
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}

/// Card for a single itinerary day showing type, date, port, and dives.
class _ItineraryDayCard extends ConsumerWidget {
  final ItineraryDay day;
  final List<Dive> dives;
  final String tripId;
  final bool isLiveaboard;

  const _ItineraryDayCard({
    required this.day,
    required this.dives,
    required this.tripId,
    required this.isLiveaboard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // The badge, icon and colour follow the dives logged; the edit sheet
    // keeps the stored type.
    final dayType = shownDayType(day, hasDives: dives.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          onTap: () => showItineraryDayEditSheet(
            context: context,
            day: day,
            tripId: tripId,
            isLiveaboard: isLiveaboard,
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day header row
                Row(
                  children: [
                    // Day type icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _dayTypeColor(
                          dayType,
                          colorScheme,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          _dayTypeIcon(dayType),
                          size: 20,
                          color: _dayTypeColor(dayType, colorScheme),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Day label and date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.trips_itinerary_dayLabel(
                              day.dayNumber,
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            units.formatWeekdayMonthDay(day.date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Day type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _dayTypeColor(
                          dayType,
                          colorScheme,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        dayType.localizedName(context),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _dayTypeColor(dayType, colorScheme),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                // Port name
                if (day.portName != null && day.portName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 48),
                      Icon(
                        Icons.anchor,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        day.portName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],

                // Notes
                if (day.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Text(
                      day.notes,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                // A day ahead with a plan: the count the forecast uses. A past
                // day's plan is history, not a promise.
                if (dives.isEmpty &&
                    (day.plannedDives ?? 0) > 0 &&
                    !tripDay(day.date).isBefore(tripDay(clock.now()))) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Text(
                      context.l10n.trips_itinerary_plannedDives(
                        day.plannedDives!,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],

                // Dives for this day
                if (dives.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.trips_itinerary_diveCount(dives.length),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...dives.map(
                          (dive) => _DiveRow(dive: dive, units: units),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _dayTypeIcon(DayType dayType) {
    switch (dayType) {
      case DayType.embark:
        return Icons.login;
      case DayType.disembark:
        return Icons.logout;
      case DayType.diveDay:
        return Icons.scuba_diving;
      case DayType.seaDay:
        return Icons.waves;
      case DayType.portDay:
        return Icons.anchor;
      case DayType.travel:
        return Icons.flight_takeoff;
      case DayType.rest:
        return Icons.beach_access;
    }
  }

  Color _dayTypeColor(DayType dayType, ColorScheme colorScheme) {
    switch (dayType) {
      case DayType.embark:
        return Colors.green.shade700;
      case DayType.disembark:
        return Colors.red.shade700;
      case DayType.diveDay:
        return colorScheme.primary;
      case DayType.seaDay:
        return Colors.blue.shade600;
      case DayType.portDay:
        return Colors.orange.shade700;
      case DayType.travel:
        return colorScheme.tertiary;
      case DayType.rest:
        return colorScheme.onSurfaceVariant;
    }
  }
}

/// A compact dive row shown under an itinerary day.
class _DiveRow extends StatelessWidget {
  final Dive dive;
  final UnitFormatter units;

  const _DiveRow({required this.dive, required this.units});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat.Hm();

    return InkWell(
      onTap: () => context.push('/dives/${dive.id}'),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(
              '#${dive.diveNumber ?? '-'}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dive.site?.name ?? '-',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              timeFormat.format(dive.dateTime),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (dive.maxDepth != null) ...[
              const SizedBox(width: 8),
              Text(
                units.formatDepth(dive.maxDepth),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
