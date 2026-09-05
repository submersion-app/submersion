import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/legend_candidates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_cell_readout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

/// One read-only entry of the inline legend: a metric that is currently drawn
/// on the chart, with the colour it is drawn in.
@immutable
class ActiveLegendEntry {
  final String label;
  final Color color;

  const ActiveLegendEntry({required this.label, required this.color});
}

/// The metrics currently drawn on the chart, in the order the options dialog
/// lists them.
///
/// Mirrors the catalog in `ChartOptionsDialog`: an entry appears when the
/// dive has the data ([config]) and the user has the metric switched on
/// ([state]). Colours come from [ProfileMetricColors] so the dash beside each
/// label matches both the chart line and the dialog swatch.
///
/// On a multi-source dive (see [ProfileLegendConfig.overlays]) every metric an
/// overlaid computer can draw gets one entry per computer, suffixed with the
/// computer's name and coloured like that computer's trace (see
/// [overlayTint]). Depth is listed only then: on a single-source dive it is
/// the chart itself, but with two computers the two depth traces need telling
/// apart. The gas strip and display behaviours have no single line colour and
/// are never listed.
List<ActiveLegendEntry> activeLegendEntries(
  BuildContext context, {
  required ProfileLegendConfig config,
  required ProfileLegendState state,
}) {
  final l10n = context.l10n;
  final colorScheme = Theme.of(context).colorScheme;
  final entries = <ActiveLegendEntry>[];
  final multiSource = config.overlays.isNotEmpty;

  /// A metric drawn only for the active source.
  void add(bool present, bool active, String label, Color color) {
    if (present && active) {
      entries.add(ActiveLegendEntry(label: label, color: color));
    }
  }

  /// A metric every source can draw: the active source's entry first, then
  /// one per overlay that has the data, each in that overlay's colour.
  void addPerSource(
    LegendMetric metric,
    bool present,
    bool active,
    String label,
    Color color,
  ) {
    if (!active) return;
    if (present) {
      final name = config.activeSourceName;
      entries.add(
        ActiveLegendEntry(
          label: multiSource && name != null ? '$label · $name' : label,
          color: color,
        ),
      );
    }
    for (var i = 0; i < config.overlays.length; i++) {
      final overlay = config.overlays[i];
      if (!overlay.metrics.contains(metric)) continue;
      entries.add(
        ActiveLegendEntry(
          label: '$label · ${overlay.name}',
          color: overlay.tintByMetric ? overlayTint(color, i) : overlay.color,
        ),
      );
    }
  }

  // Depth: only worth listing once there is more than one depth trace.
  addPerSource(
    LegendMetric.depth,
    multiSource,
    true,
    l10n.diveLog_legend_label_depth,
    ProfileMetricColors.depth,
  );

  // Overlays
  addPerSource(
    LegendMetric.temperature,
    config.hasTemperatureData,
    state.showTemperature,
    l10n.diveLog_legend_label_temp,
    colorScheme.tertiary,
  );
  add(
    config.hasPressureData && !config.hasMultiTankPressure,
    state.showPressure,
    l10n.diveLog_legend_label_pressure,
    ProfileMetricColors.pressure,
  );
  add(
    config.hasEvents,
    state.showEvents,
    l10n.diveLog_legend_label_events,
    ProfileMetricColors.events,
  );
  add(
    config.hasHeartRateData,
    state.showHeartRate,
    l10n.diveLog_legend_label_heartRate,
    ProfileMetricColors.heartRate,
  );
  add(
    config.hasSacCurve,
    state.showSac,
    l10n.diveLog_legend_label_sacRate,
    ProfileMetricColors.sac,
  );
  add(
    config.hasAscentRates,
    state.showAscentRateColors,
    l10n.diveLog_legend_label_ascentRate,
    ProfileMetricColors.ascentRateColors,
  );
  add(
    config.hasAscentRates,
    state.showAscentRateLine,
    l10n.diveLog_legend_label_ascentRateLine,
    ProfileMetricColors.ascentRateLine,
  );

  // Markers
  add(
    config.hasMaxDepthMarker,
    state.showMaxDepthMarker,
    l10n.diveLog_legend_label_maxDepth,
    ProfileMetricColors.maxDepth,
  );
  add(
    config.hasPressureMarkers,
    state.showPressureMarkers,
    l10n.diveLog_legend_label_pressureThresholds,
    ProfileMetricColors.pressureMarkers,
  );
  add(
    config.hasGasSwitches,
    state.showGasSwitchMarkers,
    l10n.diveLog_legend_label_gasSwitches,
    GasColors.nitrox,
  );
  add(
    config.hasPhotoMarkers,
    state.showPhotoMarkers,
    l10n.diveLog_legend_label_photoMarkers,
    colorScheme.primary,
  );

  // Tank pressures
  if (config.hasMultiTankPressure && config.tankPressures != null) {
    final sortedTankIds = sortTankIdsByOrder(
      config.tankPressures!.keys,
      config.tanks,
    );
    for (var i = 0; i < sortedTankIds.length; i++) {
      final tankId = sortedTankIds[i];
      final tank = _tankById(config.tanks, tankId);
      final baseLabel = tank != null
          ? tankLegendLabel(context, tank, fallbackIndex: i + 1)
          : l10n.diveLog_tank_title(i + 1);
      add(
        true,
        state.showTankPressure[tankId] ?? true,
        config.estimatedTankIds.contains(tankId)
            ? '$baseLabel ${l10n.diveLog_pressure_estimatedSuffix}'
            : baseLabel,
        tank != null ? GasColors.forGasMix(tank.gasMix) : tankFallbackColor(i),
      );
    }
  }

  // Decompression
  addPerSource(
    LegendMetric.decoStops,
    config.hasDecoStopCurve,
    state.showDecoStops,
    l10n.diveLog_legend_label_decoStops,
    ProfileMetricColors.decoStops,
  );
  addPerSource(
    LegendMetric.ceiling,
    config.hasCeilingCurve,
    state.showCeiling,
    l10n.diveLog_legend_label_ceiling,
    ProfileMetricColors.ceiling,
  );
  addPerSource(
    LegendMetric.ndl,
    config.hasNdlData,
    state.showNdl,
    l10n.diveLog_legend_label_ndl,
    ProfileMetricColors.ndl,
  );
  addPerSource(
    LegendMetric.tts,
    config.hasTtsData,
    state.showTts,
    l10n.diveLog_legend_label_tts,
    ProfileMetricColors.tts,
  );
  addPerSource(
    LegendMetric.gtr,
    config.hasGtrData,
    state.showGtr,
    l10n.diveLog_legend_label_gtr,
    ProfileMetricColors.gtr,
  );
  addPerSource(
    LegendMetric.cns,
    config.hasCnsData,
    state.showCns,
    l10n.diveLog_legend_label_cns,
    ProfileMetricColors.cns,
  );
  addPerSource(
    LegendMetric.otu,
    config.hasOtuData,
    state.showOtu,
    l10n.diveLog_legend_label_otu,
    ProfileMetricColors.otu,
  );

  // Gas analysis
  addPerSource(
    LegendMetric.ppO2,
    config.hasPpO2Data,
    state.showPpO2,
    l10n.diveLog_legend_label_ppO2,
    ProfileMetricColors.ppO2,
  );
  addPerSource(
    LegendMetric.ppN2,
    config.hasPpN2Data,
    state.showPpN2,
    l10n.diveLog_legend_label_ppN2,
    ProfileMetricColors.ppN2,
  );
  addPerSource(
    LegendMetric.ppHe,
    config.hasPpHeData,
    state.showPpHe,
    l10n.diveLog_legend_label_ppHe,
    ProfileMetricColors.ppHe,
  );
  add(
    config.hasO2CellMvData,
    state.showO2CellMv,
    l10n.diveLog_legend_label_o2Cells,
    o2CellColor(0),
  );
  addPerSource(
    LegendMetric.mod,
    config.hasModData,
    state.showMod,
    l10n.diveLog_legend_label_mod,
    ProfileMetricColors.mod,
  );
  addPerSource(
    LegendMetric.density,
    config.hasDensityData,
    state.showDensity,
    l10n.diveLog_legend_label_gasDensity,
    ProfileMetricColors.density,
  );

  // Other
  addPerSource(
    LegendMetric.gf,
    config.hasGfData,
    state.showGf,
    l10n.diveLog_legend_label_gfPercent,
    ProfileMetricColors.gf,
  );
  addPerSource(
    LegendMetric.surfaceGf,
    config.hasSurfaceGfData,
    state.showSurfaceGf,
    l10n.diveLog_legend_label_surfaceGf,
    ProfileMetricColors.surfaceGf,
  );
  addPerSource(
    LegendMetric.meanDepth,
    config.hasMeanDepthData,
    state.showMeanDepth,
    l10n.diveLog_legend_label_meanDepth,
    ProfileMetricColors.meanDepth,
  );

  return entries;
}

DiveTank? _tankById(List<DiveTank>? tanks, String tankId) {
  if (tanks == null) return null;
  for (final tank in tanks) {
    if (tank.id == tankId) return tank;
  }
  return null;
}
