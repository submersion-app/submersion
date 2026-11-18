import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_format.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_subtitle.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_weather_badge.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The head of a day's page in the trip story: the date, where the day sits
/// in the trip and what kind of day it was, and what it added up to.
///
/// The day's totals are words on one line, not a grid of stat tiles: the
/// page under this head is the day itself, so its numbers do not need a box
/// of their own. There is no band and no number badge either; the day picker
/// above the page already says which day this is.
///
/// The weather it shows is whatever it is handed; it never fetches.
class TripStoryDayHead extends ConsumerWidget {
  const TripStoryDayHead({
    super.key,
    required this.day,
    required this.dayCount,
    this.storedWeather,
  });

  final TripStoryDay day;

  /// How many days the trip has, for "Day 2 of 6".
  final int dayCount;

  /// Weather stored for this day; null when nothing is stored yet.
  final TripStoryDayWeather? storedWeather;

  static const _separator = ' · ';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);

    final where = [
      l10n.trips_story_dayOfTrip(day.dayNumber, dayCount),
      ...tripDaySubtitleParts(context, day),
    ].join(_separator);
    final maxDepth = day.maxDepth;
    final totals = day.dives.isEmpty
        ? null
        : [
            l10n.diveLog_listPage_tripGroupDiveCount(day.diveCount),
            formatDayRuntime(day.totalRuntime),
            if (maxDepth != null)
              l10n.trips_story_dayMaxDepth(units.formatDepth(maxDepth)),
          ].join(_separator);

    final weather = TripStoryDayWeather.resolve(
      logged: day.weather,
      stored: storedWeather,
    );

    final chip = switch (day.kind) {
      TripStoryDayKind.today => const TodayChip(),
      TripStoryDayKind.future => Chip(
        label: Text(l10n.trips_story_planned),
        visualDensity: VisualDensity.compact,
      ),
      TripStoryDayKind.past => null,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // The chip follows the date, or takes the next line when the
              // two do not fit: at large text sizes a chip held beside the
              // date would squeeze it into a column a few letters wide.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    units.formatWeekdayMonthDay(day.date),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ?chip,
                ],
              ),
              const SizedBox(height: 2),
              Text(
                where,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (totals != null) ...[
                const SizedBox(height: 4),
                Text(
                  totals,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (DayWeatherBadge.rendersAnything(weather))
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
            child: DayWeatherBadge(weather: weather!, units: units),
          ),
      ],
    );
  }
}
