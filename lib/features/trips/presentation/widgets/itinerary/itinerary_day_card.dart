import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/day_conditions.dart';
import 'package:submersion/features/trips/domain/services/day_plan_progress.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_conditions_line.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_format.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_plan_line.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_weather_badge.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_card_shape.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_chip.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/itinerary_dive_row.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary_day_edit_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/text/markdown/notes_plain_text.dart';

/// Card for a single itinerary day: type, date and weather, port, notes, the
/// plan, the day's totals and conditions, its dives, and its photos and
/// species. Today's card is tinted and outlined in the primary colour.
class ItineraryDayCard extends ConsumerWidget {
  final ItineraryDay day;
  final List<Dive> dives;
  final String tripId;
  final bool isLiveaboard;

  /// Where the day sits against today; drives the Today styling and whether
  /// the plan reads as a plan or as progress.
  final TripStoryDayKind kind;

  /// The day's photos and sightings, from the trip story. Empty while the
  /// story loads or when it failed: they only add a line, never gate the card.
  final List<MediaItem> media;
  final List<Sighting> sightings;

  /// Weather stored for this day; logged dive weather wins over it.
  final TripStoryDayWeather? storedWeather;

  /// Space under the card. The list's anchored sliver brings its own gap
  /// above today, so the card just before it takes none.
  final double bottomGap;

  const ItineraryDayCard({
    super.key,
    required this.day,
    required this.dives,
    required this.tripId,
    required this.isLiveaboard,
    required this.kind,
    this.media = const [],
    this.sightings = const [],
    this.storedWeather,
    this.bottomGap = 8,
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
    final isToday = kind == TripStoryDayKind.today;
    final weather = TripStoryDayWeather.resolve(
      logged: diveDayWeather(dives),
      stored: storedWeather,
    );
    final progress = dayPlanProgress(
      row: day,
      logged: dives.length,
      kind: kind,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Card(
        // Today's tint is blended onto the card's own surface colour rather
        // than handed to Material as a bare translucent fill, which would
        // composite with whatever is behind the card and with the theme's
        // elevation tint, and read differently on each.
        color: isToday
            ? Color.alphaBlend(
                colorScheme.primaryContainer.withValues(alpha: 0.35),
                theme.cardTheme.color ?? colorScheme.surfaceContainerLow,
              )
            : null,
        shape: isToday ? todayCardShape(theme) : null,
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
                          // Both lines wrap rather than overflow: on a phone
                          // with large text the chip or the weather drops to
                          // a line of its own.
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                context.l10n.trips_itinerary_dayLabel(
                                  day.dayNumber,
                                ),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isToday) const TodayChip(),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                units.formatWeekdayMonthDay(day.date),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (DayWeatherBadge.rendersAnything(weather))
                                DayWeatherBadge(
                                  weather: weather!,
                                  units: units,
                                ),
                            ],
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
                      markdownToPlainText(day.notes),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                // The plan: what a day ahead holds, or how a day under way or
                // done measured up against it.
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: DayPlanLine(progress: progress),
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
                          _totals(context, units),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        DayConditionsLine(
                          conditions: DayConditions.fromDives(dives),
                          units: units,
                        ),
                        const SizedBox(height: 4),
                        ...dives.map(
                          (dive) => ItineraryDiveRow(dive: dive, units: units),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_mediaLine(context) case final line?) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Row(
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            line,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
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

  /// "2 dives · 1h 40m · 24.0m": count, time in the water, deepest dive.
  String _totals(BuildContext context, UnitFormatter units) {
    final runtime = diveDayRuntime(dives);
    final maxDepth = diveDayMaxDepth(dives);
    return [
      context.l10n.trips_itinerary_diveCount(dives.length),
      if (runtime > Duration.zero) formatDayRuntime(runtime),
      if (maxDepth != null) units.formatDepth(maxDepth),
    ].join(' · ');
  }

  /// "12 photos · 5 species", or null when the day has neither. Species are
  /// counted by id, so a turtle seen on two dives counts once.
  String? _mediaLine(BuildContext context) {
    final l10n = context.l10n;
    final speciesCount = sightings.map((s) => s.speciesId).toSet().length;
    // Trip media also holds videos, signatures and documents; the line
    // counts photos.
    final photoCount = media
        .where((m) => m.mediaType == MediaType.photo)
        .length;
    final parts = [
      if (photoCount > 0) l10n.trips_day_photoCount(photoCount),
      if (speciesCount > 0) l10n.trips_day_speciesCount(speciesCount),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
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
