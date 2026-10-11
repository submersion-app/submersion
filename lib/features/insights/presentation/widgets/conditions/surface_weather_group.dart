import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_band_card.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_card_parts.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_category_card.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Surface & weather group of the Conditions tab (issue #3118): air
/// temperature, cloud, precipitation, wind, humidity and surface pressure.
/// Hidden when none of them is recorded on any dive in the filter.
class SurfaceWeatherGroup extends ConsumerWidget {
  const SurfaceWeatherGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = context.l10n.insights_conditions_group_surfaceWeather;
    return ref
        .watch(conditionsStatsProvider)
        .when(
          // A background re-query (sync, download, unit switch) keeps the
          // cards; a spinner would shrink the page and lose the scroll.
          skipLoadingOnReload: true,
          loading: () => ConditionsGroupStatus(title: title, failed: false),
          error: (_, _) => ConditionsGroupStatus(title: title, failed: true),
          data: (stats) {
            final hasAny = [
              stats.airTemp.isEmpty,
              stats.cloudCover.isEmpty,
              stats.precipitation.isEmpty,
              stats.windSpeed.isEmpty,
              stats.windDirection.isEmpty,
              stats.humidity.isEmpty,
              stats.surfacePressure.isEmpty,
            ].any((empty) => !empty);
            if (!hasAny) return const SizedBox.shrink();
            final units = UnitFormatter(ref.watch(settingsProvider));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConditionsGroupHeader(title: title),
                ..._cards(context, stats, units),
              ],
            );
          },
        );
  }

  List<Widget> _cards(
    BuildContext context,
    ConditionsStats stats,
    UnitFormatter units,
  ) {
    final l10n = context.l10n;
    final total = stats.totalDives;
    return [
      if (!stats.airTemp.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TrendChartSection(
            chartId: TrendChartIds.airTemp,
            onDiveSelected: (diveId) => context.push('/dives/$diveId'),
            title: l10n.insights_conditions_airTempTrend_title,
            subtitle: l10n.insights_conditions_airTempTrend_subtitle,
            pointsAsync: AsyncData(stats.airTempTrend),
            errorMessage: l10n.insights_conditions_airTempTrend_error,
            lineColor: Colors.deepOrange,
            valueFormatter: (value) => units.formatTemperature(value),
            // A per-year rate is a difference: no 32-degree offset in F.
            rateFormatter: (value) => units.formatTemperatureDelta(value),
            footer: ConditionsCoverageLine(
              recorded: stats.airTemp.recorded,
              total: total,
            ),
          ),
        ),
      ConditionsBandCard(
        title: l10n.insights_conditions_airTempBands_title,
        subtitle: l10n.insights_conditions_airTempBands_subtitle,
        stat: stats.airTemp,
        totalDives: total,
        unitSymbol: units.temperatureSymbol,
        barColor: Colors.deepOrange.shade300,
      ),
      ConditionsCategoryCard<CloudCover>(
        title: l10n.insights_conditions_cloudCover_title,
        subtitle: l10n.insights_conditions_cloudCover_subtitle,
        stat: stats.cloudCover,
        totalDives: total,
        labelOf: (v) => v.localizedName(l10n),
        kind: ConditionsChartKind.pie,
        colorOf: _cloudColor,
      ),
      ConditionsCategoryCard<Precipitation>(
        title: l10n.insights_conditions_precipitation_title,
        subtitle: l10n.insights_conditions_precipitation_subtitle,
        stat: stats.precipitation,
        totalDives: total,
        labelOf: (v) => v.localizedName(l10n),
        kind: ConditionsChartKind.bar,
        barColor: Colors.indigo.shade300,
      ),
      ConditionsBandCard(
        title: l10n.insights_conditions_windSpeed_title,
        subtitle: l10n.insights_conditions_windSpeed_subtitle,
        stat: stats.windSpeed,
        totalDives: total,
        unitSymbol: units.windSpeedSymbol,
        barColor: Colors.blueGrey.shade400,
      ),
      ConditionsCategoryCard<CurrentDirection>(
        title: l10n.insights_conditions_windDirection_title,
        subtitle: l10n.insights_conditions_windDirection_subtitle,
        stat: stats.windDirection,
        totalDives: total,
        labelOf: (v) => v.localizedName(l10n),
        kind: ConditionsChartKind.bar,
        barColor: Colors.blueGrey.shade400,
      ),
      ConditionsBandCard(
        title: l10n.insights_conditions_humidity_title,
        subtitle: l10n.insights_conditions_humidity_subtitle,
        stat: stats.humidity,
        totalDives: total,
        unitSymbol: '%',
        barColor: Colors.lightBlue.shade400,
      ),
      ConditionsBandCard(
        title: l10n.insights_conditions_surfacePressure_title,
        subtitle: l10n.insights_conditions_surfacePressure_subtitle,
        stat: stats.surfacePressure,
        totalDives: total,
        unitSymbol: units.surfacePressureSymbol,
        barColor: Colors.purple.shade300,
      ),
    ];
  }

  /// Keyed by value so each sky keeps its color whatever its share.
  static Color _cloudColor(CloudCover value) => switch (value) {
    CloudCover.clear => Colors.amber.shade400,
    CloudCover.partlyCloudy => Colors.lightBlue.shade300,
    CloudCover.mostlyCloudy => Colors.blueGrey.shade300,
    CloudCover.overcast => Colors.grey.shade600,
  };
}
