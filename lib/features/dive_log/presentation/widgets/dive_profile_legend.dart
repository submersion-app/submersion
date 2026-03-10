import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';

/// Configuration for what data is available in the chart.
/// This determines which toggles appear in the legend.
class ProfileLegendConfig {
  final bool hasTemperatureData;
  final bool hasPressureData;
  final bool hasHeartRateData;
  final bool hasSacCurve;
  final bool hasCeilingCurve;
  final bool hasAscentRates;
  final bool hasEvents;
  final bool hasMaxDepthMarker;
  final bool hasPressureMarkers;
  final bool hasGasSwitches;
  final bool hasMultiTankPressure;
  final List<DiveTank>? tanks;
  final Map<String, List<TankPressurePoint>>? tankPressures;

  // Advanced decompression/gas data availability
  final bool hasNdlData;
  final bool hasPpO2Data;
  final bool hasPpN2Data;
  final bool hasPpHeData;
  final bool hasModData;
  final bool hasDensityData;
  final bool hasGfData;
  final bool hasSurfaceGfData;
  final bool hasMeanDepthData;
  final bool hasTtsData;
  final bool hasCnsData;
  final bool hasOtuData;

  const ProfileLegendConfig({
    this.hasTemperatureData = false,
    this.hasPressureData = false,
    this.hasHeartRateData = false,
    this.hasSacCurve = false,
    this.hasCeilingCurve = false,
    this.hasAscentRates = false,
    this.hasEvents = false,
    this.hasMaxDepthMarker = false,
    this.hasPressureMarkers = false,
    this.hasGasSwitches = false,
    this.hasMultiTankPressure = false,
    this.tanks,
    this.tankPressures,
    this.hasNdlData = false,
    this.hasPpO2Data = false,
    this.hasPpN2Data = false,
    this.hasPpHeData = false,
    this.hasModData = false,
    this.hasDensityData = false,
    this.hasGfData = false,
    this.hasSurfaceGfData = false,
    this.hasMeanDepthData = false,
    this.hasTtsData = false,
    this.hasCnsData = false,
    this.hasOtuData = false,
  });

  /// Whether any secondary toggles should be shown
  bool get hasSecondaryToggles =>
      hasCeilingCurve ||
      hasHeartRateData ||
      hasSacCurve ||
      hasAscentRates ||
      hasMaxDepthMarker ||
      hasPressureMarkers ||
      hasGasSwitches ||
      hasMultiTankPressure ||
      hasNdlData ||
      hasPpO2Data ||
      hasPpN2Data ||
      hasPpHeData ||
      hasModData ||
      hasDensityData ||
      hasGfData ||
      hasSurfaceGfData ||
      hasMeanDepthData ||
      hasTtsData ||
      hasCnsData ||
      hasOtuData;
}

/// Legend widget for the dive profile chart.
///
/// Displays primary toggles inline and secondary toggles in a popover menu.
/// Also includes zoom controls.
class DiveProfileLegend extends ConsumerWidget {
  final ProfileLegendConfig config;
  final double zoomLevel;
  final double minZoom;
  final double maxZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final double leftPadding;

  const DiveProfileLegend({
    super.key,
    required this.config,
    required this.zoomLevel,
    this.minZoom = 1.0,
    this.maxZoom = 10.0,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    this.leftPadding = 0.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legendState = ref.watch(profileLegendProvider);
    final legendNotifier = ref.read(profileLegendProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    // Initialize tank pressures if needed
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        legendNotifier.initializeTankPressures(
          config.tankPressures!.keys.toList(),
        );
      });
    }

    return Padding(
      padding: EdgeInsets.only(left: leftPadding, bottom: 8),
      child: Row(
        children: [
          // Primary toggles + options button flowing together
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Depth legend (always shown, not a toggle)
                _buildLegendItem(
                  context,
                  color: AppColors.chartDepth,
                  label: context.l10n.diveLog_legend_label_depth,
                ),
                // Temperature toggle (primary)
                if (config.hasTemperatureData)
                  _buildMetricToggle(
                    context,
                    color: colorScheme.tertiary,
                    label: context.l10n.diveLog_legend_label_temp,
                    isEnabled: legendState.showTemperature,
                    onTap: legendNotifier.toggleTemperature,
                  ),
                // Pressure toggle (primary) - only if single tank
                if (config.hasPressureData && !config.hasMultiTankPressure)
                  _buildMetricToggle(
                    context,
                    color: Colors.orange,
                    label: context.l10n.diveLog_legend_label_pressure,
                    isEnabled: legendState.showPressure,
                    onTap: legendNotifier.togglePressure,
                  ),
                // Events toggle (primary)
                if (config.hasEvents)
                  _buildMetricToggle(
                    context,
                    color: Colors.amber,
                    label: context.l10n.diveLog_legend_label_events,
                    isEnabled: legendState.showEvents,
                    onTap: legendNotifier.toggleEvents,
                  ),
                // "More" button flows right after the last toggle
                if (config.hasSecondaryToggles)
                  _MoreOptionsButton(
                    config: config,
                    legendState: legendState,
                    legendNotifier: legendNotifier,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Zoom controls
          _ZoomControls(
            zoomLevel: zoomLevel,
            minZoom: minZoom,
            maxZoom: maxZoom,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onResetZoom: onResetZoom,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context, {
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _buildMetricToggle(
    BuildContext context, {
    required Color color,
    required String label,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return Semantics(
      toggled: isEnabled,
      label: '$label ${isEnabled ? 'enabled' : 'disabled'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
                size: 14,
                color: isEnabled
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Container(
                width: 10,
                height: 3,
                decoration: BoxDecoration(
                  color: isEnabled ? color : color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isEnabled
                      ? null
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds a source-aware label for metrics that can come from a dive computer
/// or app calculation.
///
/// When the user prefers [MetricDataSource.computer]:
///   - Returns `'$baseName (DC)'` when computer data was used.
///   - Returns `'$baseName (Calc*)'` when it fell back to calculated.
/// When the user chose [MetricDataSource.calculated], returns the base name
/// unchanged (no indicator needed).
String _sourceLabel(
  String baseName,
  MetricDataSource preferred,
  MetricDataSource actual,
) {
  if (preferred == MetricDataSource.computer) {
    if (actual == MetricDataSource.computer) {
      return '$baseName (DC)';
    }
    // Wanted computer but fell back to calculated
    return '$baseName (Calc*)';
  }
  // User chose calculated -- no indicator needed
  return baseName;
}

/// Button that shows badge with active secondary toggle count and opens popover
class _MoreOptionsButton extends ConsumerWidget {
  final ProfileLegendConfig config;
  final ProfileLegendState legendState;
  final ProfileLegend legendNotifier;

  const _MoreOptionsButton({
    required this.config,
    required this.legendState,
    required this.legendNotifier,
  });

  int get _activeSecondaryCount {
    var count = 0;
    if (config.hasHeartRateData && legendState.showHeartRate) count++;
    if (config.hasSacCurve && legendState.showSac) count++;
    if (config.hasAscentRates && legendState.showAscentRateColors) count++;
    if (config.hasMaxDepthMarker && legendState.showMaxDepthMarker) count++;
    if (config.hasPressureMarkers && legendState.showPressureMarkers) count++;
    if (config.hasGasSwitches && legendState.showGasSwitchMarkers) count++;

    // Advanced deco/gas toggles
    if (config.hasCeilingCurve && legendState.showCeiling) count++;
    if (config.hasNdlData && legendState.showNdl) count++;
    if (config.hasPpO2Data && legendState.showPpO2) count++;
    if (config.hasPpN2Data && legendState.showPpN2) count++;
    if (config.hasPpHeData && legendState.showPpHe) count++;
    if (config.hasModData && legendState.showMod) count++;
    if (config.hasDensityData && legendState.showDensity) count++;
    if (config.hasGfData && legendState.showGf) count++;
    if (config.hasSurfaceGfData && legendState.showSurfaceGf) count++;
    if (config.hasMeanDepthData && legendState.showMeanDepth) count++;
    if (config.hasTtsData && legendState.showTts) count++;
    if (config.hasCnsData && legendState.showCns) count++;
    if (config.hasOtuData && legendState.showOtu) count++;

    // Count active tank pressure toggles
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      for (final tankId in config.tankPressures!.keys) {
        if (legendState.showTankPressure[tankId] ?? true) count++;
      }
    }

    return count;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeCount = _activeSecondaryCount;
    final sourceInfo = ref.watch(metricSourceInfoProvider);

    return IconButton(
      onPressed: () => _showMoreOptions(context, sourceInfo),
      icon: Badge(
        isLabelVisible: activeCount > 0,
        label: Text(
          activeCount.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        child: const Icon(Icons.tune, size: 18),
      ),
      tooltip: context.l10n.diveLog_profile_tooltip_moreOptions,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      style: IconButton.styleFrom(
        foregroundColor: activeCount > 0
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _showMoreOptions(BuildContext context, MetricSourceInfo? sourceInfo) {
    final renderBox = context.findRenderObject() as RenderBox;
    final buttonOffset = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => _ChartOptionsDialog(
        config: config,
        legendNotifier: legendNotifier,
        anchorOffset: buttonOffset,
        anchorSize: buttonSize,
      ),
    );
  }
}

/// Persistent dialog for chart toggle options.
///
/// Uses [Consumer] to watch [profileLegendProvider] so checkbox states
/// update live without closing the dialog. Dismissed by tapping outside
/// (the transparent barrier).
class _ChartOptionsDialog extends StatelessWidget {
  final ProfileLegendConfig config;
  final ProfileLegend legendNotifier;
  final Offset anchorOffset;
  final Size anchorSize;

  const _ChartOptionsDialog({
    required this.config,
    required this.legendNotifier,
    required this.anchorOffset,
    required this.anchorSize,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
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
                maxHeight: screenSize.height - top - 32,
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final legendState = ref.watch(profileLegendProvider);
                  final sourceInfo = ref.watch(metricSourceInfoProvider);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildItems(context, legendState, sourceInfo),
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

  List<Widget> _buildItems(
    BuildContext context,
    ProfileLegendState legendState,
    MetricSourceInfo? sourceInfo,
  ) {
    final items = <Widget>[];

    // Heart Rate
    if (config.hasHeartRateData) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_heartRate,
          color: Colors.red,
          isEnabled: legendState.showHeartRate,
          onTap: legendNotifier.toggleHeartRate,
        ),
      );
    }

    // SAC Rate
    if (config.hasSacCurve) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_sacRate,
          color: Colors.teal,
          isEnabled: legendState.showSac,
          onTap: legendNotifier.toggleSac,
        ),
      );
    }

    // Ascent Rate Colors
    if (config.hasAscentRates) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ascentRate,
          color: Colors.lime.shade700,
          isEnabled: legendState.showAscentRateColors,
          onTap: legendNotifier.toggleAscentRateColors,
        ),
      );
    }

    // Divider before markers section
    if ((config.hasMaxDepthMarker ||
            config.hasPressureMarkers ||
            config.hasGasSwitches) &&
        items.isNotEmpty) {
      items.add(const Divider(height: 1));
    }

    // Max Depth Marker
    if (config.hasMaxDepthMarker) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_maxDepth,
          color: Colors.red,
          isEnabled: legendState.showMaxDepthMarker,
          onTap: legendNotifier.toggleMaxDepthMarker,
        ),
      );
    }

    // Pressure Threshold Markers
    if (config.hasPressureMarkers) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_pressureThresholds,
          color: Colors.orange,
          isEnabled: legendState.showPressureMarkers,
          onTap: legendNotifier.togglePressureMarkers,
        ),
      );
    }

    // Gas Switches
    if (config.hasGasSwitches) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_gasSwitches,
          color: GasColors.nitrox,
          isEnabled: legendState.showGasSwitchMarkers,
          onTap: legendNotifier.toggleGasSwitchMarkers,
        ),
      );
    }

    // Multi-tank pressure toggles
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      if (items.isNotEmpty) {
        items.add(const Divider(height: 1));
      }

      final sortedTankIds = _sortedTankIds(config.tankPressures!.keys);
      for (var i = 0; i < sortedTankIds.length; i++) {
        final tankId = sortedTankIds[i];
        final tank = _getTankById(tankId);
        final color = tank != null
            ? GasColors.forGasMix(tank.gasMix)
            : _getTankColor(i);
        final label = tank?.name ?? context.l10n.diveLog_tank_title(i + 1);

        items.add(
          _buildToggleItem(
            context,
            label: label,
            color: color,
            isEnabled: legendState.showTankPressure[tankId] ?? true,
            onTap: () => legendNotifier.toggleTankPressure(tankId),
          ),
        );
      }
    }

    // Advanced decompression/gas section
    final hasAdvancedOptions =
        config.hasCeilingCurve ||
        config.hasNdlData ||
        config.hasPpO2Data ||
        config.hasPpN2Data ||
        config.hasPpHeData ||
        config.hasModData ||
        config.hasDensityData ||
        config.hasGfData ||
        config.hasSurfaceGfData ||
        config.hasMeanDepthData ||
        config.hasTtsData ||
        config.hasCnsData ||
        config.hasOtuData;

    if (hasAdvancedOptions && items.isNotEmpty) {
      items.add(const Divider(height: 1));
    }

    // Ceiling toggle + source selector
    if (config.hasCeilingCurve) {
      items.add(
        _buildToggleItem(
          context,
          label: _sourceLabel(
            context.l10n.diveLog_legend_label_ceiling,
            legendState.ceilingSource,
            sourceInfo?.ceilingActual ?? MetricDataSource.calculated,
          ),
          color: const Color(0xFFD32F2F), // Red 700
          isEnabled: legendState.showCeiling,
          onTap: legendNotifier.toggleCeiling,
        ),
      );
      items.add(
        _buildSourceSelector(
          context,
          currentSource: legendState.ceilingSource,
          onCycle: legendNotifier.cycleCeilingSource,
        ),
      );
    }

    // NDL
    if (config.hasNdlData) {
      items.add(
        _buildToggleItem(
          context,
          label: _sourceLabel(
            context.l10n.diveLog_legend_label_ndl,
            legendState.ndlSource,
            sourceInfo?.ndlActual ?? MetricDataSource.calculated,
          ),
          color: Colors.lightGreen.shade700,
          isEnabled: legendState.showNdl,
          onTap: legendNotifier.toggleNdl,
        ),
      );
      items.add(
        _buildSourceSelector(
          context,
          currentSource: legendState.ndlSource,
          onCycle: legendNotifier.cycleNdlSource,
        ),
      );
    }

    // ppO2
    if (config.hasPpO2Data) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ppO2,
          color: const Color(0xFF00ACC1),
          isEnabled: legendState.showPpO2,
          onTap: legendNotifier.togglePpO2,
        ),
      );
    }

    // ppN2
    if (config.hasPpN2Data) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ppN2,
          color: Colors.indigo,
          isEnabled: legendState.showPpN2,
          onTap: legendNotifier.togglePpN2,
        ),
      );
    }

    // ppHe
    if (config.hasPpHeData) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ppHe,
          color: Colors.pink.shade300,
          isEnabled: legendState.showPpHe,
          onTap: legendNotifier.togglePpHe,
        ),
      );
    }

    // MOD
    if (config.hasModData) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_mod,
          color: Colors.deepOrange,
          isEnabled: legendState.showMod,
          onTap: legendNotifier.toggleMod,
        ),
      );
    }

    // Density
    if (config.hasDensityData) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_gasDensity,
          color: Colors.brown,
          isEnabled: legendState.showDensity,
          onTap: legendNotifier.toggleDensity,
        ),
      );
    }

    // GF%
    if (config.hasGfData) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_gfPercent,
          color: Colors.deepPurple,
          isEnabled: legendState.showGf,
          onTap: legendNotifier.toggleGf,
        ),
      );
    }

    // Surface GF
    if (config.hasSurfaceGfData) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_surfaceGf,
          color: Colors.purple.shade300,
          isEnabled: legendState.showSurfaceGf,
          onTap: legendNotifier.toggleSurfaceGf,
        ),
      );
    }

    // Mean Depth
    if (config.hasMeanDepthData) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_meanDepth,
          color: Colors.blueGrey,
          isEnabled: legendState.showMeanDepth,
          onTap: legendNotifier.toggleMeanDepth,
        ),
      );
    }

    // TTS
    if (config.hasTtsData) {
      items.add(
        _buildToggleItem(
          context,
          label: _sourceLabel(
            context.l10n.diveLog_legend_label_tts,
            legendState.ttsSource,
            sourceInfo?.ttsActual ?? MetricDataSource.calculated,
          ),
          color: const Color(0xFFAD1457),
          isEnabled: legendState.showTts,
          onTap: legendNotifier.toggleTts,
        ),
      );
      items.add(
        _buildSourceSelector(
          context,
          currentSource: legendState.ttsSource,
          onCycle: legendNotifier.cycleTtsSource,
        ),
      );
    }

    // CNS%
    if (config.hasCnsData) {
      items.add(
        _buildToggleItem(
          context,
          label: _sourceLabel(
            context.l10n.diveLog_legend_label_cns,
            legendState.cnsSource,
            sourceInfo?.cnsActual ?? MetricDataSource.calculated,
          ),
          color: const Color(0xFFE65100),
          isEnabled: legendState.showCns,
          onTap: legendNotifier.toggleCns,
        ),
      );
      items.add(
        _buildSourceSelector(
          context,
          currentSource: legendState.cnsSource,
          onCycle: legendNotifier.cycleCnsSource,
        ),
      );
    }

    // OTU
    if (config.hasOtuData) {
      items.add(
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_otu,
          color: const Color(0xFF6D4C41),
          isEnabled: legendState.showOtu,
          onTap: legendNotifier.toggleOtu,
        ),
      );
    }

    return items;
  }

  Widget _buildToggleItem(
    BuildContext context, {
    required String label,
    required Color color,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: isEnabled
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Container(
              width: 16,
              height: 4,
              decoration: BoxDecoration(
                color: isEnabled ? color : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector(
    BuildContext context, {
    required MetricDataSource currentSource,
    required VoidCallback onCycle,
    String? metricName,
  }) {
    return InkWell(
      onTap: onCycle,
      child: Padding(
        padding: EdgeInsets.only(
          left: metricName != null ? 16 : 44,
          right: 16,
          top: 4,
          bottom: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              metricName != null ? '$metricName Source: ' : 'Source: ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                currentSource == MetricDataSource.computer ? 'DC' : 'Calc',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sort tank IDs by tank order
  List<String> _sortedTankIds(Iterable<String> tankIds) {
    final ids = tankIds.toList();
    ids.sort((a, b) {
      final orderA = _getTankById(a)?.order ?? 999;
      final orderB = _getTankById(b)?.order ?? 999;
      return orderA.compareTo(orderB);
    });
    return ids;
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

  /// Get color for tank by index (fallback when no gas mix info)
  Color _getTankColor(int index) {
    const colors = [
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.cyan,
      Colors.purple,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }
}

/// Zoom controls widget
class _ZoomControls extends StatelessWidget {
  final double zoomLevel;
  final double minZoom;
  final double maxZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;

  const _ZoomControls({
    required this.zoomLevel,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isZoomed = zoomLevel > 1.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zoom out button
        IconButton(
          onPressed: zoomLevel > minZoom ? onZoomOut : null,
          icon: const Icon(Icons.remove),
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: context.l10n.diveLog_profile_tooltip_zoomOut,
        ),
        // Zoom level indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${zoomLevel.toStringAsFixed(1)}x',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: isZoomed
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        // Zoom in button
        IconButton(
          onPressed: zoomLevel < maxZoom ? onZoomIn : null,
          icon: const Icon(Icons.add),
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: context.l10n.diveLog_profile_tooltip_zoomIn,
        ),
        // Reset zoom / fit button
        if (isZoomed)
          IconButton(
            onPressed: onResetZoom,
            icon: const Icon(Icons.fit_screen),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: context.l10n.diveLog_profile_tooltip_resetZoom,
          ),
      ],
    );
  }
}
