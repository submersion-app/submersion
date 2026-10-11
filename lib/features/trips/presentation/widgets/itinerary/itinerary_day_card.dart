import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/itinerary_dive_row.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary_day_edit_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Card for a single itinerary day showing type, date, port, and dives.
class ItineraryDayCard extends ConsumerWidget {
  final ItineraryDay day;
  final List<Dive> dives;
  final String tripId;
  final bool isLiveaboard;

  const ItineraryDayCard({
    super.key,
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
                          (dive) => ItineraryDiveRow(dive: dive, units: units),
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
