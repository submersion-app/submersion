import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/helpers/weather_icon.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Conditions icon plus air temperature in the diver's unit. Wind, humidity
/// and the free-text weather description stay out of this compact badge on
/// purpose.
class DayWeatherBadge extends StatelessWidget {
  final TripStoryDayWeather weather;
  final UnitFormatter units;

  /// Foreground for icon and text; defaults to onSurfaceVariant.
  final Color? color;

  const DayWeatherBadge({
    super.key,
    required this.weather,
    required this.units,
    this.color,
  });

  /// Whether a badge for [weather] would draw anything at all: a day whose
  /// dives logged nothing displayable gets no badge.
  static bool rendersAnything(TripStoryDayWeather? weather) =>
      weather != null &&
      (weather.airTemp != null ||
          weatherIconFor(
                cloudCover: weather.cloudCover,
                precipitation: weather.precipitation,
              ) !=
              null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.onSurfaceVariant;
    final icon = weatherIconFor(
      cloudCover: weather.cloudCover,
      precipitation: weather.precipitation,
    );
    final airTemp = weather.airTemp;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        if (icon != null)
          Icon(
            icon,
            size: 16,
            color: foreground,
            semanticLabel: _conditionsLabel(context.l10n),
          ),
        // Flexible so a narrow slot (a phone with large text) ellipsizes the
        // temperature instead of overflowing.
        if (airTemp != null)
          Flexible(
            child: Text(
              units.formatTemperature(airTemp),
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  /// Localized name of what the icon depicts, for screen readers. Mirrors
  /// [weatherIconFor]: active precipitation first, then cloud cover.
  String? _conditionsLabel(AppLocalizations l10n) {
    final precipitation = weather.precipitation;
    if (precipitation != null && precipitation != Precipitation.none) {
      return precipitation.localizedName(l10n);
    }
    return weather.cloudCover?.localizedName(l10n);
  }
}
