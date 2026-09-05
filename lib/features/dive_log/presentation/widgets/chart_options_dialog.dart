import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/legend_candidates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_cell_readout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';

/// Persistent dialog for chart toggle options.
///
/// Uses [Consumer] to watch [profileLegendProvider] so checkbox states
/// update live without closing the dialog. Dismissed by tapping outside
/// (the transparent barrier).
class ChartOptionsDialog extends StatelessWidget {
  final ProfileLegendConfig config;
  final Offset anchorOffset;
  final Size anchorSize;

  const ChartOptionsDialog({
    super.key,
    required this.config,
    required this.anchorOffset,
    required this.anchorSize,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    const edgePadding = 8.0;
    const dialogMaxWidth = 280.0;

    // Position below the button
    final top = anchorOffset.dy + anchorSize.height + 4;

    // Try to align the right edge of the dialog with the right edge of the
    // button, but clamp so the dialog never overflows the screen edges.
    final desiredRight = screenSize.width - anchorOffset.dx - anchorSize.width;
    final maxRight = screenSize.width - dialogMaxWidth - edgePadding;
    final right = desiredRight.clamp(edgePadding, maxRight);

    return Stack(
      children: [
        Positioned(
          top: top,
          right: right,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogMaxWidth,
                maxHeight: screenSize.height - top - edgePadding - bottomInset,
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final legendState = ref.watch(profileLegendProvider);
                  final legendNotifier = ref.read(
                    profileLegendProvider.notifier,
                  );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildSections(
                        context,
                        legendState: legendState,
                        legendNotifier: legendNotifier,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSections(
    BuildContext context, {
    required ProfileLegendState legendState,
    required ProfileLegend legendNotifier,
  }) {
    final sections = <Widget>[];

    // Overlays section
    final overlayItems = <Widget>[
      if (config.hasTemperatureData)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_temp,
          color: Theme.of(context).colorScheme.tertiary,
          isEnabled: legendState.showTemperature,
          onTap: legendNotifier.toggleTemperature,
        ),
      if (config.hasPressureData && !config.hasMultiTankPressure)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_pressure,
          color: ProfileMetricColors.pressure,
          isEnabled: legendState.showPressure,
          onTap: legendNotifier.togglePressure,
        ),
      if (config.hasEvents)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_events,
          color: ProfileMetricColors.events,
          isEnabled: legendState.showEvents,
          onTap: legendNotifier.toggleEvents,
        ),
      if (config.hasHeartRateData)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_heartRate,
          color: ProfileMetricColors.heartRate,
          isEnabled: legendState.showHeartRate,
          onTap: legendNotifier.toggleHeartRate,
        ),
      if (config.hasSacCurve)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_sacRate,
          color: ProfileMetricColors.sac,
          isEnabled: legendState.showSac,
          onTap: legendNotifier.toggleSac,
        ),
      if (config.hasAscentRates)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ascentRate,
          color: ProfileMetricColors.ascentRateColors,
          isEnabled: legendState.showAscentRateColors,
          onTap: legendNotifier.toggleAscentRateColors,
        ),
      if (config.hasAscentRates)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ascentRateLine,
          color: ProfileMetricColors.ascentRateLine,
          isEnabled: legendState.showAscentRateLine,
          onTap: legendNotifier.toggleAscentRateLine,
        ),
      if (config.hasGasData)
        buildGasToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_showGas,
          isEnabled: legendState.showGas,
          onTap: legendNotifier.toggleGas,
        ),
    ];
    if (overlayItems.isNotEmpty) {
      sections.add(
        buildOptionsSection(
          context,
          key: 'overlays',
          title: context.l10n.diveLog_chartSection_overlays,
          legendState: legendState,
          legendNotifier: legendNotifier,
          children: overlayItems,
        ),
      );
    }

    // Markers section
    final markerItems = <Widget>[
      if (config.hasMaxDepthMarker)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_maxDepth,
          color: ProfileMetricColors.maxDepth,
          isEnabled: legendState.showMaxDepthMarker,
          onTap: legendNotifier.toggleMaxDepthMarker,
        ),
      if (config.hasPressureMarkers)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_pressureThresholds,
          color: ProfileMetricColors.pressureMarkers,
          isEnabled: legendState.showPressureMarkers,
          onTap: legendNotifier.togglePressureMarkers,
        ),
      if (config.hasGasSwitches)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_gasSwitches,
          color: GasColors.nitrox,
          isEnabled: legendState.showGasSwitchMarkers,
          onTap: legendNotifier.toggleGasSwitchMarkers,
        ),
      if (config.hasPhotoMarkers)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_photoMarkers,
          // Photo markers are painted in the theme's primary colour.
          color: Theme.of(context).colorScheme.primary,
          isEnabled: legendState.showPhotoMarkers,
          onTap: legendNotifier.togglePhotoMarkers,
        ),
    ];
    if (markerItems.isNotEmpty) {
      sections.add(
        buildOptionsSection(
          context,
          key: 'markers',
          title: context.l10n.diveLog_chartSection_markers,
          legendState: legendState,
          legendNotifier: legendNotifier,
          children: markerItems,
        ),
      );
    }

    // Tanks section (for gas-switch dives without multi-tank pressure traces).
    // Same checkbox rows as every other section: unchecking a cylinder hides
    // its gas-switch markers on the chart.
    if (config.hasTankListSection && config.tanks != null) {
      final sortedTanks = [...config.tanks!]
        ..sort((a, b) => a.order.compareTo(b.order));
      final tankItems = <Widget>[];

      for (var i = 0; i < sortedTanks.length; i++) {
        final tank = sortedTanks[i];
        final color = GasColors.forGasMix(tank.gasMix);
        final label = tankLegendLabel(context, tank, fallbackIndex: i + 1);

        tankItems.add(
          buildToggleItem(
            context,
            label: label,
            color: color,
            isEnabled: legendState.showTankPressure[tank.id] ?? true,
            onTap: () => legendNotifier.toggleTankPressure(tank.id),
            sourceColor: config.tankSourceColors?[tank.id],
          ),
        );
      }

      if (tankItems.isNotEmpty) {
        sections.add(
          buildOptionsSection(
            context,
            key: 'tanks',
            title: context.l10n.diveLog_detail_section_cylinders,
            legendState: legendState,
            legendNotifier: legendNotifier,
            children: tankItems,
          ),
        );
      }
    }

    // Tank Pressures section
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      final sortedTankIds = sortTankIdsByOrder(
        config.tankPressures!.keys,
        config.tanks,
      );
      final tankItems = <Widget>[];
      for (var i = 0; i < sortedTankIds.length; i++) {
        final tankId = sortedTankIds[i];
        final tank = _getTankById(tankId);
        final color = tank != null
            ? GasColors.forGasMix(tank.gasMix)
            : tankFallbackColor(i);
        final baseLabel = tank != null
            ? tankLegendLabel(context, tank, fallbackIndex: i + 1)
            : context.l10n.diveLog_tank_title(i + 1);
        final label = config.estimatedTankIds.contains(tankId)
            ? '$baseLabel ${context.l10n.diveLog_pressure_estimatedSuffix}'
            : baseLabel;

        tankItems.add(
          buildToggleItem(
            context,
            label: label,
            color: color,
            isEnabled: legendState.showTankPressure[tankId] ?? true,
            onTap: () => legendNotifier.toggleTankPressure(tankId),
            sourceColor: config.tankSourceColors?[tankId],
          ),
        );
      }
      if (tankItems.isNotEmpty) {
        sections.add(
          buildOptionsSection(
            context,
            key: 'tankPressures',
            title: context.l10n.diveLog_chartSection_tankPressures,
            legendState: legendState,
            legendNotifier: legendNotifier,
            children: tankItems,
          ),
        );
      }
    }

    // Decompression section
    final decoItems = <Widget>[
      if (config.hasDecoStopCurve)
        buildToggleWithSource(
          context,
          label: context.l10n.diveLog_legend_label_decoStops,
          color: ProfileMetricColors.decoStops,
          isEnabled: legendState.showDecoStops,
          onTap: legendNotifier.toggleDecoStops,
          currentSource: legendState.decoStopSource,
          onSourceChanged: legendNotifier.setDecoStopSource,
          segments: sourceSegments(context),
        ),
      if (config.hasCeilingCurve)
        // No source toggle: the ceiling line always shows the exact, continuous
        // calculated curve. Every import stores only the computer's stepped stop
        // depth, so a "computer" ceiling would duplicate the deco-stop band
        // (issue #755). The Computer/Calculated comparison lives on the deco
        // stops above.
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ceiling,
          color: ProfileMetricColors.ceiling,
          isEnabled: legendState.showCeiling,
          onTap: legendNotifier.toggleCeiling,
        ),
      if (config.hasNdlData)
        buildToggleWithSource(
          context,
          label: context.l10n.diveLog_legend_label_ndl,
          color: ProfileMetricColors.ndl,
          isEnabled: legendState.showNdl,
          onTap: legendNotifier.toggleNdl,
          currentSource: legendState.ndlSource,
          onSourceChanged: legendNotifier.setNdlSource,
          segments: sourceSegments(context),
        ),
      if (config.hasTtsData)
        buildToggleWithSource(
          context,
          label: context.l10n.diveLog_legend_label_tts,
          color: ProfileMetricColors.tts,
          isEnabled: legendState.showTts,
          onTap: legendNotifier.toggleTts,
          currentSource: legendState.ttsSource,
          onSourceChanged: legendNotifier.setTtsSource,
          segments: sourceSegments(context),
        ),
      if (config.hasGtrData)
        buildToggleWithSource(
          context,
          label: context.l10n.diveLog_legend_label_gtr,
          color: ProfileMetricColors.gtr,
          isEnabled: legendState.showGtr,
          onTap: legendNotifier.toggleGtr,
          currentSource: legendState.gtrSource,
          onSourceChanged: legendNotifier.setGtrSource,
          segments: sourceSegments(context),
        ),
      if (config.hasCnsData)
        buildToggleWithSource(
          context,
          label: context.l10n.diveLog_legend_label_cns,
          color: ProfileMetricColors.cns,
          isEnabled: legendState.showCns,
          onTap: legendNotifier.toggleCns,
          currentSource: legendState.cnsSource,
          onSourceChanged: legendNotifier.setCnsSource,
          segments: sourceSegments(context),
        ),
      if (config.hasOtuData)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_otu,
          color: ProfileMetricColors.otu,
          isEnabled: legendState.showOtu,
          onTap: legendNotifier.toggleOtu,
        ),
    ];
    if (decoItems.isNotEmpty) {
      sections.add(
        buildOptionsSection(
          context,
          key: 'decompression',
          title: context.l10n.diveLog_chartSection_decompression,
          legendState: legendState,
          legendNotifier: legendNotifier,
          children: decoItems,
        ),
      );
    }

    // Gas Analysis section
    final gasItems = <Widget>[
      if (config.hasPpO2Data)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ppO2,
          color: ProfileMetricColors.ppO2,
          isEnabled: legendState.showPpO2,
          onTap: legendNotifier.togglePpO2,
        ),
      if (config.hasPpN2Data)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ppN2,
          color: ProfileMetricColors.ppN2,
          isEnabled: legendState.showPpN2,
          onTap: legendNotifier.togglePpN2,
        ),
      if (config.hasPpHeData)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ppHe,
          color: ProfileMetricColors.ppHe,
          isEnabled: legendState.showPpHe,
          onTap: legendNotifier.togglePpHe,
        ),
      if (config.hasO2CellMvData)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_o2Cells,
          // Cell 1's colour, so the swatch belongs to the same set as the lines.
          color: o2CellColor(0),
          isEnabled: legendState.showO2CellMv,
          onTap: legendNotifier.toggleO2CellMv,
        ),
      if (config.hasModData)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_mod,
          color: ProfileMetricColors.mod,
          isEnabled: legendState.showMod,
          onTap: legendNotifier.toggleMod,
        ),
      if (config.hasDensityData)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_gasDensity,
          color: ProfileMetricColors.density,
          isEnabled: legendState.showDensity,
          onTap: legendNotifier.toggleDensity,
        ),
    ];
    if (gasItems.isNotEmpty) {
      sections.add(
        buildOptionsSection(
          context,
          key: 'gasAnalysis',
          title: context.l10n.diveLog_chartSection_gasAnalysis,
          legendState: legendState,
          legendNotifier: legendNotifier,
          children: gasItems,
        ),
      );
    }

    // Other section
    final otherItems = <Widget>[
      if (config.hasGfData)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_gfPercent,
          color: ProfileMetricColors.gf,
          isEnabled: legendState.showGf,
          onTap: legendNotifier.toggleGf,
        ),
      if (config.hasSurfaceGfData)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_surfaceGf,
          color: ProfileMetricColors.surfaceGf,
          isEnabled: legendState.showSurfaceGf,
          onTap: legendNotifier.toggleSurfaceGf,
        ),
      if (config.hasMeanDepthData)
        buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_meanDepth,
          color: ProfileMetricColors.meanDepth,
          isEnabled: legendState.showMeanDepth,
          onTap: legendNotifier.toggleMeanDepth,
        ),
    ];
    if (otherItems.isNotEmpty) {
      sections.add(
        buildOptionsSection(
          context,
          key: 'other',
          title: context.l10n.diveLog_chartSection_other,
          legendState: legendState,
          legendNotifier: legendNotifier,
          children: otherItems,
        ),
      );
    }

    // Display section: rendering behaviour rather than series visibility, so
    // it is always present and its items carry no series colour.
    sections.add(
      buildOptionsSection(
        context,
        key: 'display',
        title: context.l10n.diveLog_chartSection_display,
        legendState: legendState,
        legendNotifier: legendNotifier,
        children: [
          buildBehaviorItem(
            context,
            label: context.l10n.diveLog_chartOption_metricsFollowViewport,
            isEnabled: legendState.metricsFollowViewport,
            onTap: legendNotifier.toggleMetricsFollowViewport,
          ),
        ],
      ),
    );

    return sections;
  }

  /// Get tank by ID
  DiveTank? _getTankById(String tankId) {
    final tanks = config.tanks;
    if (tanks == null) return null;
    for (final tank in tanks) {
      if (tank.id == tankId) return tank;
    }
    return null;
  }
}
