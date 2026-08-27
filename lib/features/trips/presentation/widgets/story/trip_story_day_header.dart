import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/features/trips/presentation/helpers/weather_icon.dart';
import 'package:submersion/features/trips/presentation/providers/surface_day_weather_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A leading day-number badge plus two compact lines - "Wed, Jul 8" and the
/// day-type/port/sites subtitle - on an opaque tinted band
/// (surfaceContainer, one step above the page surface) so the sticky headers
/// read as chapter anchors and day cards scroll underneath cleanly. The badge
/// echoes the map's primary-colored day pins, tying header and pin together.
/// Days with logged weather get a trailing badge: conditions icon plus air
/// temperature in the diver's temperature unit.
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
  final SurfaceDayWeatherRequest? surfaceWeatherRequest;

  const TripStoryDayHeader({
    super.key,
    required this.day,
    this.surfaceWeatherRequest,
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
    // leads with its day type ("Dive Day", "Travel Day").
    final subtitleParts = <String>[
      if (day.isSurface) context.l10n.trips_story_surfaceDay,
      if (itinerary != null) itinerary.dayType.localizedName(context),
      if (itinerary?.portName != null) itinerary!.portName!,
      ...day.siteNames,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).toList();

    final request = day.isSurface ? surfaceWeatherRequest : null;
    final fetchedWeather = request == null
        ? null
        : ref.watch(surfaceDayWeatherProvider(request)).asData?.value;
    final weather = day.weather ?? fetchedWeather;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final weatherBadge = _weatherBadge(context, theme, units, weather);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _DayNumberBadge(dayNumber: day.dayNumber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.MMMEd().format(day.date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitleParts.isNotEmpty)
                      Text(
                        subtitleParts.join(' - '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
              if (day.kind == TripStoryDayKind.future)
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

  /// Conditions icon plus air temperature, or null when the day's dives
  /// logged nothing displayable (wind, humidity, and the free-text weather
  /// description stay out of the compact band on purpose).
  Widget? _weatherBadge(
    BuildContext context,
    ThemeData theme,
    UnitFormatter units,
    TripStoryDayWeather? weather,
  ) {
    if (weather == null) return null;

    final icon = weatherIconFor(
      cloudCover: weather.cloudCover,
      precipitation: weather.precipitation,
    );
    final airTemp = weather.airTemp;
    if (icon == null && airTemp == null) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        if (icon != null)
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
            semanticLabel: _conditionsLabel(context.l10n, weather),
          ),
        if (airTemp != null)
          Text(
            units.formatTemperature(airTemp),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  /// Localized name of what the icon depicts, for screen readers. Mirrors
  /// [weatherIconFor]: active precipitation first, then cloud cover.
  String? _conditionsLabel(AppLocalizations l10n, TripStoryDayWeather weather) {
    final precipitation = weather.precipitation;
    if (precipitation != null && precipitation != Precipitation.none) {
      return precipitation.localizedName(l10n);
    }
    return weather.cloudCover?.localizedName(l10n);
  }
}

/// Round day-number chip leading the header, echoing the map's day pins so
/// the sticky headers give the story a scannable chapter rhythm. Visually it
/// is just the number; assistive tech hears the full "Day N" label instead.
class _DayNumberBadge extends StatelessWidget {
  final int dayNumber;

  const _DayNumberBadge({required this.dayNumber});

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
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            '$dayNumber',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
