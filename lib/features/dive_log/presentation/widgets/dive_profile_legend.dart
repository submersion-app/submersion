import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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
                  _MoreOptionsButton(config: config, legendState: legendState),
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

/// Button that shows badge with active secondary toggle count and opens popover
class _MoreOptionsButton extends ConsumerWidget {
  final ProfileLegendConfig config;
  final ProfileLegendState legendState;

  const _MoreOptionsButton({required this.config, required this.legendState});

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

    return IconButton(
      onPressed: () => _showMoreOptions(context),
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

  void _showMoreOptions(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final buttonOffset = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => _ChartOptionsDialog(
        config: config,
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
  final Offset anchorOffset;
  final Size anchorSize;

  const _ChartOptionsDialog({
    required this.config,
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
      if (config.hasHeartRateData)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_heartRate,
          color: Colors.red,
          isEnabled: legendState.showHeartRate,
          onTap: legendNotifier.toggleHeartRate,
        ),
      if (config.hasSacCurve)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_sacRate,
          color: Colors.teal,
          isEnabled: legendState.showSac,
          onTap: legendNotifier.toggleSac,
        ),
      if (config.hasAscentRates)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ascentRate,
          color: Colors.lime.shade700,
          isEnabled: legendState.showAscentRateColors,
          onTap: legendNotifier.toggleAscentRateColors,
        ),
    ];
    if (overlayItems.isNotEmpty) {
      sections.add(
        _buildSection(
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
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_maxDepth,
          color: Colors.red,
          isEnabled: legendState.showMaxDepthMarker,
          onTap: legendNotifier.toggleMaxDepthMarker,
        ),
      if (config.hasPressureMarkers)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_pressureThresholds,
          color: Colors.orange,
          isEnabled: legendState.showPressureMarkers,
          onTap: legendNotifier.togglePressureMarkers,
        ),
      if (config.hasGasSwitches)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_gasSwitches,
          color: GasColors.nitrox,
          isEnabled: legendState.showGasSwitchMarkers,
          onTap: legendNotifier.toggleGasSwitchMarkers,
        ),
    ];
    if (markerItems.isNotEmpty) {
      sections.add(
        _buildSection(
          context,
          key: 'markers',
          title: context.l10n.diveLog_chartSection_markers,
          legendState: legendState,
          legendNotifier: legendNotifier,
          children: markerItems,
        ),
      );
    }

    // Tank Pressures section
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      final sortedTankIds = _sortedTankIds(config.tankPressures!.keys);
      final tankItems = <Widget>[];
      for (var i = 0; i < sortedTankIds.length; i++) {
        final tankId = sortedTankIds[i];
        final tank = _getTankById(tankId);
        final color = tank != null
            ? GasColors.forGasMix(tank.gasMix)
            : _getTankColor(i);
        final label = tank?.name ?? context.l10n.diveLog_tank_title(i + 1);

        tankItems.add(
          _buildToggleItem(
            context,
            label: label,
            color: color,
            isEnabled: legendState.showTankPressure[tankId] ?? true,
            onTap: () => legendNotifier.toggleTankPressure(tankId),
          ),
        );
      }
      if (tankItems.isNotEmpty) {
        sections.add(
          _buildSection(
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
      if (config.hasCeilingCurve)
        _buildToggleWithSource(
          context,
          label: context.l10n.diveLog_legend_label_ceiling,
          color: const Color(0xFFD32F2F),
          isEnabled: legendState.showCeiling,
          onTap: legendNotifier.toggleCeiling,
          currentSource: legendState.ceilingSource,
          onSourceChanged: legendNotifier.setCeilingSource,
        ),
      if (config.hasNdlData)
        _buildToggleWithSource(
          context,
          label: context.l10n.diveLog_legend_label_ndl,
          color: Colors.lightGreen.shade700,
          isEnabled: legendState.showNdl,
          onTap: legendNotifier.toggleNdl,
          currentSource: legendState.ndlSource,
          onSourceChanged: legendNotifier.setNdlSource,
        ),
      if (config.hasTtsData)
        _buildToggleWithSource(
          context,
          label: context.l10n.diveLog_legend_label_tts,
          color: const Color(0xFFAD1457),
          isEnabled: legendState.showTts,
          onTap: legendNotifier.toggleTts,
          currentSource: legendState.ttsSource,
          onSourceChanged: legendNotifier.setTtsSource,
        ),
      if (config.hasCnsData)
        _buildToggleWithSource(
          context,
          label: context.l10n.diveLog_legend_label_cns,
          color: const Color(0xFFE65100),
          isEnabled: legendState.showCns,
          onTap: legendNotifier.toggleCns,
          currentSource: legendState.cnsSource,
          onSourceChanged: legendNotifier.setCnsSource,
        ),
      if (config.hasOtuData)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_otu,
          color: const Color(0xFF6D4C41),
          isEnabled: legendState.showOtu,
          onTap: legendNotifier.toggleOtu,
        ),
    ];
    if (decoItems.isNotEmpty) {
      sections.add(
        _buildSection(
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
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ppO2,
          color: const Color(0xFF00ACC1),
          isEnabled: legendState.showPpO2,
          onTap: legendNotifier.togglePpO2,
        ),
      if (config.hasPpN2Data)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ppN2,
          color: Colors.indigo,
          isEnabled: legendState.showPpN2,
          onTap: legendNotifier.togglePpN2,
        ),
      if (config.hasPpHeData)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_ppHe,
          color: Colors.pink.shade300,
          isEnabled: legendState.showPpHe,
          onTap: legendNotifier.togglePpHe,
        ),
      if (config.hasModData)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_mod,
          color: Colors.deepOrange,
          isEnabled: legendState.showMod,
          onTap: legendNotifier.toggleMod,
        ),
      if (config.hasDensityData)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_gasDensity,
          color: Colors.brown,
          isEnabled: legendState.showDensity,
          onTap: legendNotifier.toggleDensity,
        ),
    ];
    if (gasItems.isNotEmpty) {
      sections.add(
        _buildSection(
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
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_gfPercent,
          color: Colors.deepPurple,
          isEnabled: legendState.showGf,
          onTap: legendNotifier.toggleGf,
        ),
      if (config.hasSurfaceGfData)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_surfaceGf,
          color: Colors.purple.shade300,
          isEnabled: legendState.showSurfaceGf,
          onTap: legendNotifier.toggleSurfaceGf,
        ),
      if (config.hasMeanDepthData)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_meanDepth,
          color: Colors.blueGrey,
          isEnabled: legendState.showMeanDepth,
          onTap: legendNotifier.toggleMeanDepth,
        ),
    ];
    if (otherItems.isNotEmpty) {
      sections.add(
        _buildSection(
          context,
          key: 'other',
          title: context.l10n.diveLog_chartSection_other,
          legendState: legendState,
          legendNotifier: legendNotifier,
          children: otherItems,
        ),
      );
    }

    return sections;
  }

  Widget _buildSection(
    BuildContext context, {
    required String key,
    required String title,
    required ProfileLegendState legendState,
    required ProfileLegend legendNotifier,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey(key),
        title: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        initiallyExpanded: legendState.sectionExpanded[key] ?? false,
        onExpansionChanged: (expanded) =>
            legendNotifier.setSectionExpanded(key, expanded),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: EdgeInsets.zero,
        dense: true,
        children: children,
      ),
    );
  }

  Widget _buildToggleWithSource(
    BuildContext context, {
    required String label,
    required Color color,
    required bool isEnabled,
    required VoidCallback onTap,
    required MetricDataSource currentSource,
    required ValueChanged<MetricDataSource> onSourceChanged,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
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
            Expanded(child: Text(label)),
            GestureDetector(
              onTap: () {}, // absorb tap to prevent parent InkWell from firing
              child: SizedBox(
                height: 28,
                child: SegmentedButton<MetricDataSource>(
                  segments: [
                    ButtonSegment(
                      value: MetricDataSource.computer,
                      label: Text(
                        context.l10n.diveLog_legend_source_dc,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    ButtonSegment(
                      value: MetricDataSource.calculated,
                      label: Text(
                        context.l10n.diveLog_legend_source_calc,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                  selected: {currentSource},
                  onSelectionChanged: (selected) =>
                      onSourceChanged(selected.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
