import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_weather_badge.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A leading day-number badge plus two compact lines - "Wed, Jul 8" and the
/// day-type/port/sites subtitle - on an opaque tinted band
/// (surfaceContainer, one step above the page surface) so the sticky headers
/// read as chapter anchors and day cards scroll underneath cleanly. The badge
/// echoes the map's primary-colored day pins, tying header and pin together.
/// Days with logged or stored weather get a trailing badge: conditions icon
/// plus air temperature in the diver's temperature unit. The header never
/// fetches: it renders whatever weather it is handed.
///
/// Today's header steps out of that grey ladder: its band is primaryContainer,
/// its text onPrimaryContainer, its badge primary, and it carries a Today
/// chip, so the current day stands out while the trip is under way.
///
/// Every day of the trip gets one of these, including surface days (which
/// carry no card body at all and are nothing but this header). Presenting a
/// dive-free day in some slimmer, quieter form makes it read as a lesser entry
/// and easy to miss when scanning the story.
///
/// Mounted in a [PinnedHeaderSliver] inside a SliverMainAxisGroup, so it sticks
/// at the top of its day chapter until the next day's header pushes it out.
/// PinnedHeaderSliver lets the header size itself, so scaled accessibility text
/// grows the header rather than being clipped by a fixed sliver extent;
/// [minHeight] only keeps short (subtitle-less) days from looking cramped.
class TripStoryDayHeader extends ConsumerWidget {
  /// Floor so every day header reads as the same band at default text scale.
  static const double minHeight = 52;

  final TripStoryDay day;

  /// Weather stored for this day, passed down by the story view from one
  /// per-trip read. Null when nothing is stored yet.
  final TripStoryDayWeather? storedWeather;

  /// Compact form for the story band's docked panel: no Planned chip (it would
  /// consume the subtitle at half width, and the chapter's own full-width
  /// heading still carries it) and no background of its own, since the band
  /// paints one.
  final bool compact;

  const TripStoryDayHeader({
    super.key,
    required this.day,
    this.storedWeather,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itinerary = day.itineraryDay;
    // Trim and drop blanks before joining: the itinerary edit sheet normalizes
    // an empty port to null, but sync and import payloads write the nullable
    // column directly, and a site name is equally free to be blank. Joining
    // either verbatim would render a doubled separator ("Dive Day -  - Site").
    // A surface day has no itinerary and no dives by definition, so it owns the
    // subtitle outright - it reads in the same slot where an itinerary day
    // leads with its day type ("Dive Day", "Travel Day"). A dive day planned
    // at 0 dives reads the same way: its stored type contradicts the plan.
    // A rest day with a dive logged reads as a dive day (#2875).
    final surfaceLabel = day.isSurface || day.isPlannedRest;
    final subtitleParts = <String>[
      if (surfaceLabel) context.l10n.trips_story_surfaceDay,
      if (itinerary != null && !surfaceLabel)
        shownDayType(
          itinerary,
          hasDives: day.dives.isNotEmpty,
        ).localizedName(context),
      if (itinerary?.portName != null) itinerary!.portName!,
      ...day.siteNames,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).toList();

    final weather = TripStoryDayWeather.resolve(
      logged: day.weather,
      stored: storedWeather,
    );
    final units = UnitFormatter(ref.watch(settingsProvider));
    final scheme = theme.colorScheme;
    final isToday = day.kind == TripStoryDayKind.today;
    // The compact form sits on a band that paints its own background, so only
    // the full-width heading takes the tint.
    final tinted = isToday && !compact;
    final weatherBadge = DayWeatherBadge.rendersAnything(weather)
        ? DayWeatherBadge(
            weather: weather!,
            units: units,
            color: tinted ? scheme.onPrimaryContainer : null,
          )
        : null;

    return Material(
      color: compact
          ? Colors.transparent
          : (tinted ? scheme.primaryContainer : scheme.surfaceContainer),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _DayNumberBadge(dayNumber: day.dayNumber, highlighted: tinted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      UnitFormatter(
                        ref.watch(settingsProvider),
                      ).formatWeekdayMonthDay(day.date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tinted ? scheme.onPrimaryContainer : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitleParts.isNotEmpty)
                      Text(
                        subtitleParts.join(' - '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tinted
                              ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                              : scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (weatherBadge != null) ...[
                const SizedBox(width: 8),
                weatherBadge,
              ],
              if (isToday) ...[const SizedBox(width: 8), const TodayChip()],
              if (!compact && day.kind == TripStoryDayKind.future)
                Chip(
                  label: Text(context.l10n.trips_story_planned),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round day-number chip leading the header, echoing the map's day pins so
/// the sticky headers give the story a scannable chapter rhythm. Visually it
/// is just the number; assistive tech hears the full "Day N" label instead.
class _DayNumberBadge extends StatelessWidget {
  final int dayNumber;

  /// On today's primaryContainer band the usual primaryContainer fill would
  /// vanish, so the badge takes the stronger primary pair there.
  final bool highlighted;

  const _DayNumberBadge({required this.dayNumber, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: context.l10n.trips_story_dayLabel(dayNumber),
      excludeSemantics: true,
      // A Container given an alignment fills loose bounded constraints (here
      // the whole band height); unbounding it makes it shrink-wrap the number
      // while still honoring the minimum size below.
      child: UnconstrainedBox(
        child: Container(
          key: const Key('day-number-badge'),
          // Min sizes with padding (not a fixed box) so scaled accessibility
          // text grows the badge instead of clipping the number; the near-round
          // corner radius keeps it pill-shaped if it does grow.
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: highlighted
                ? theme.colorScheme.primary
                : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            '$dayNumber',
            style: theme.textTheme.labelLarge?.copyWith(
              color: highlighted
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
