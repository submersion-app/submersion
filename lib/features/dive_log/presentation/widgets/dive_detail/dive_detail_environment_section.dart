import 'package:flutter/material.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_water_conditions.dart';
import 'package:submersion/features/reef/presentation/widgets/water_conditions_lines.dart';
import 'package:submersion/features/weather/presentation/widgets/weather_description_builder.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';

/// The Environment card: what the diver logged about the weather and the
/// dive conditions, then the satellite water conditions on the dive date.
///
/// Each subsection shows only when it has something to say, so callers gate
/// the card as a whole on [watchHasEnvironmentData].
class DiveEnvironmentSection extends ConsumerWidget {
  const DiveEnvironmentSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
    final hasWeather =
        dive.airTemp != null ||
        dive.surfacePressure != null ||
        dive.windSpeed != null ||
        dive.windDirection != null ||
        dive.cloudCover != null ||
        dive.precipitation != null ||
        dive.humidity != null ||
        dive.weatherDescription != null;

    final hasDiveConditions =
        trimmedOrNull(dive.surfaceConditions) != null ||
        dive.currentDirection != null ||
        dive.currentStrength != null ||
        dive.swellHeight != null ||
        dive.effectiveEntryMethod != null ||
        dive.exitMethod != null;

    final satellite = watchSatelliteWaterConditions(ref, dive);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.diveLog_detail_section_environment,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              if (hasWeather) ...[
                Text(
                  context.l10n.diveLog_detail_subsection_weather,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (dive.airTemp != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_airTemp,
                    value: units.formatTemperature(dive.airTemp),
                  ),
                if (dive.surfacePressure != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_surfacePressure,
                    value: units.formatSurfacePressure(dive.surfacePressure),
                  ),
                if (dive.windSpeed != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_windSpeed,
                    value: units.formatWindSpeed(dive.windSpeed),
                  ),
                if (dive.windDirection != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_windDirection,
                    value: dive.windDirection!.localizedName(context.l10n),
                  ),
                if (dive.cloudCover != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_cloudCover,
                    value: dive.cloudCover!.localizedName(context.l10n),
                  ),
                if (dive.precipitation != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_precipitation,
                    value: dive.precipitation!.localizedName(context.l10n),
                  ),
                if (dive.humidity != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_humidity,
                    value: '${dive.humidity!.toStringAsFixed(0)}%',
                  ),
                // Rendered at display time so it follows the diver's locale and
                // units. Text the diver typed or that arrived with an import is
                // user data and is shown verbatim; the prose we used to generate
                // for fetched weather is rebuilt from the structured fields.
                Builder(
                  builder: (context) {
                    final description = buildLocalizedWeatherDescription(
                      l10n: context.l10n,
                      units: units,
                      weatherCode: dive.weatherCode,
                      cloudCover: dive.cloudCover,
                      airTempCelsius: dive.airTemp,
                      windSpeedMs: dive.windSpeed,
                      windDirection: dive.windDirection,
                      precipitation: dive.precipitation,
                      storedDescription:
                          dive.weatherSource == WeatherSource.openMeteo
                          ? null
                          : dive.weatherDescription,
                    );
                    if (description == null) return const SizedBox.shrink();
                    return DiveDetailRow(
                      label:
                          context.l10n.diveLog_detail_label_weatherDescription,
                      value: description,
                    );
                  },
                ),
                if (dive.weatherSource == WeatherSource.openMeteo)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      context.l10n.diveLog_detail_weatherSourceOpenMeteo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
              if (hasWeather && hasDiveConditions) ...[
                const SizedBox(height: 16),
                const Divider(),
              ],
              if (hasDiveConditions) ...[
                Text(
                  context.l10n.diveLog_detail_subsection_diveConditions,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (dive.currentDirection != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_currentDirection,
                    value: dive.currentDirection!.localizedName(context.l10n),
                  ),
                if (dive.currentStrength != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_currentStrength,
                    value: dive.currentStrength!.localizedName(context.l10n),
                  ),
                if (dive.swellHeight != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_swellHeight,
                    value: units.formatDepth(dive.swellHeight, decimals: 1),
                  ),
                if (trimmedOrNull(dive.surfaceConditions) case final surface?)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_surfaceConditions,
                    value: surface,
                  ),
                // Effective, so a dive that never had an entry method of its
                // own still shows the one its site carries (issue #1427).
                if (dive.effectiveEntryMethod != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_entryMethod,
                    value: dive.effectiveEntryMethod!.localizedName(
                      context.l10n,
                    ),
                  ),
                if (dive.exitMethod != null)
                  DiveDetailRow(
                    label: context.l10n.diveLog_detail_label_exitMethod,
                    value: dive.exitMethod!.localizedName(context.l10n),
                  ),
              ],
              if ((hasWeather || hasDiveConditions) && satellite != null) ...[
                const SizedBox(height: 16),
                const Divider(),
              ],
              if (satellite != null)
                EnvironmentWaterConditions(
                  lines: buildWaterConditionsLines(
                    l10n: context.l10n,
                    units: units,
                    health: satellite.health,
                    reefPossible: satellite.reefPossible,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
