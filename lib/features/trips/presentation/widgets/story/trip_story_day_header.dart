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
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Two compact lines - "Day 3 - Wed, Jul 8" plus the day-type/port/sites
/// subtitle - on an opaque surface so day cards scroll underneath cleanly.
/// Days with logged weather get a trailing badge: conditions icon plus air
/// temperature in the diver's temperature unit.
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

  const TripStoryDayHeader({super.key, required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itinerary = day.itineraryDay;
    // Trim and drop blanks before joining: the itinerary edit sheet normalizes
    // an empty port to null, but sync and import payloads write the nullable
    // column directly, and a site name is equally free to be blank. Joining
    // either verbatim would render a doubled separator ("Dive Day -  - Site").
    final subtitleParts = <String>[
      if (itinerary != null) itinerary.dayType.localizedName(context),
      if (itinerary?.portName != null) itinerary!.portName!,
      ...day.siteNames,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).toList();

    final units = UnitFormatter(ref.watch(settingsProvider));
    final weatherBadge = _weatherBadge(context, theme, units);

    return Material(
      color: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.l10n.trips_story_dayLabel(day.dayNumber)}'
                      ' - ${DateFormat.MMMEd().format(day.date)}',
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
  ) {
    final weather = day.weather;
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
