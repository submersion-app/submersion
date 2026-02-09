import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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
  });

  /// Whether any secondary toggles should be shown
  bool get hasSecondaryToggles =>
      hasHeartRateData ||
      hasSacCurve ||
      hasAscentRates ||
      hasEvents ||
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
      hasTtsData;
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

  const DiveProfileLegend({
    super.key,
    required this.config,
    required this.zoomLevel,
    this.minZoom = 1.0,
    this.maxZoom = 10.0,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legendState = ref.watch(profileLegendProvider);
    final legendNotifier = ref.read(profileLegendProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    // Initialize pressure visibility if pressure data is available
    if (config.hasPressureData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        legendNotifier.enablePressureIfAvailable();
      });
    }

    // Initialize tank pressures if needed
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        legendNotifier.initializeTankPressures(
          config.tankPressures!.keys.toList(),
        );
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Primary toggles
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Depth legend (always shown, not a toggle)
                _buildLegendItem(
                  context,
                  color: AppColors.chartDepth,
                  label: 'Depth',
                ),
                // Temperature toggle (primary)
                if (config.hasTemperatureData)
                  _buildMetricToggle(
                    context,
                    color: colorScheme.tertiary,
                    label: 'Temp',
                    isEnabled: legendState.showTemperature,
                    onTap: legendNotifier.toggleTemperature,
                  ),
                // Pressure toggle (primary) - only if single tank
                if (config.hasPressureData && !config.hasMultiTankPressure)
                  _buildMetricToggle(
                    context,
                    color: Colors.orange,
                    label: 'Pressure',
                    isEnabled: legendState.showPressure,
                    onTap: legendNotifier.togglePressure,
                  ),
                // Ceiling toggle (primary)
                if (config.hasCeilingCurve)
                  _buildMetricToggle(
                    context,
                    color: const Color(0xFFD32F2F), // Red 700
                    label: 'Ceiling',
                    isEnabled: legendState.showCeiling,
                    onTap: legendNotifier.toggleCeiling,
                  ),
              ],
            ),
          ),
          // "More" button for secondary toggles
          if (config.hasSecondaryToggles)
            _MoreOptionsButton(
              config: config,
              legendState: legendState,
              legendNotifier: legendNotifier,
            ),
          const SizedBox(width: 8),
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
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: isEnabled
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Container(
              width: 12,
              height: 3,
              decoration: BoxDecoration(
                color: isEnabled ? color : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isEnabled
                    ? null
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Button that shows badge with active secondary toggle count and opens popover
class _MoreOptionsButton extends StatelessWidget {
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
    if (config.hasEvents && legendState.showEvents) count++;
    if (config.hasMaxDepthMarker && legendState.showMaxDepthMarker) count++;
    if (config.hasPressureMarkers && legendState.showPressureMarkers) count++;
    if (config.hasGasSwitches && legendState.showGasSwitchMarkers) count++;

    // Advanced deco/gas toggles
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

    // Count active tank pressure toggles
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      for (final tankId in config.tankPressures!.keys) {
        if (legendState.showTankPressure[tankId] ?? true) count++;
      }
    }

    return count;
  }

  @override
  Widget build(BuildContext context) {
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
        child: const Icon(Icons.tune, size: 20),
      ),
      tooltip: 'More chart options',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      style: IconButton.styleFrom(
        foregroundColor: activeCount > 0
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx - 160, // Position to the left of button
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height + 400,
      ),
      items: _buildMenuItems(context, colorScheme),
    );
  }

  List<PopupMenuEntry<void>> _buildMenuItems(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final items = <PopupMenuEntry<void>>[];

    // Heart Rate
    if (config.hasHeartRateData) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'Heart Rate',
          color: Colors.red,
          isEnabled: legendState.showHeartRate,
          onTap: legendNotifier.toggleHeartRate,
        ),
      );
    }

    // SAC Rate
    if (config.hasSacCurve) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'SAC Rate',
          color: Colors.teal,
          isEnabled: legendState.showSac,
          onTap: legendNotifier.toggleSac,
        ),
      );
    }

    // Ascent Rate Colors
    if (config.hasAscentRates) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'Ascent Rate',
          color: Colors.lime.shade700,
          isEnabled: legendState.showAscentRateColors,
          onTap: legendNotifier.toggleAscentRateColors,
        ),
      );
    }

    // Events
    if (config.hasEvents) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'Events',
          color: Colors.amber,
          isEnabled: legendState.showEvents,
          onTap: legendNotifier.toggleEvents,
        ),
      );
    }

    // Divider before markers section
    if ((config.hasMaxDepthMarker ||
            config.hasPressureMarkers ||
            config.hasGasSwitches) &&
        items.isNotEmpty) {
      items.add(const PopupMenuDivider());
    }

    // Max Depth Marker
    if (config.hasMaxDepthMarker) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'Max Depth',
          color: Colors.red,
          isEnabled: legendState.showMaxDepthMarker,
          onTap: legendNotifier.toggleMaxDepthMarker,
        ),
      );
    }

    // Pressure Threshold Markers
    if (config.hasPressureMarkers) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'Pressure Thresholds',
          color: Colors.orange,
          isEnabled: legendState.showPressureMarkers,
          onTap: legendNotifier.togglePressureMarkers,
        ),
      );
    }

    // Gas Switches
    if (config.hasGasSwitches) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'Gas Switches',
          color: GasColors.nitrox,
          isEnabled: legendState.showGasSwitchMarkers,
          onTap: legendNotifier.toggleGasSwitchMarkers,
        ),
      );
    }

    // Multi-tank pressure toggles
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      if (items.isNotEmpty) {
        items.add(const PopupMenuDivider());
      }

      final sortedTankIds = _sortedTankIds(config.tankPressures!.keys);
      for (var i = 0; i < sortedTankIds.length; i++) {
        final tankId = sortedTankIds[i];
        final tank = _getTankById(tankId);
        final color = tank != null
            ? GasColors.forGasMix(tank.gasMix)
            : _getTankColor(i);
        final label = tank?.name ?? 'Tank ${i + 1}';

        items.add(
          _buildToggleMenuItem(
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
        config.hasNdlData ||
        config.hasPpO2Data ||
        config.hasPpN2Data ||
        config.hasPpHeData ||
        config.hasModData ||
        config.hasDensityData ||
        config.hasGfData ||
        config.hasSurfaceGfData ||
        config.hasMeanDepthData ||
        config.hasTtsData;

    if (hasAdvancedOptions && items.isNotEmpty) {
      items.add(const PopupMenuDivider());
    }

    // NDL
    if (config.hasNdlData) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'NDL',
          color: Colors.lightGreen.shade700,
          isEnabled: legendState.showNdl,
          onTap: legendNotifier.toggleNdl,
        ),
      );
    }

    // ppO2
    if (config.hasPpO2Data) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'ppO2',
          color: const Color(0xFF00ACC1), // Cyan 600
          isEnabled: legendState.showPpO2,
          onTap: legendNotifier.togglePpO2,
        ),
      );
    }

    // ppN2
    if (config.hasPpN2Data) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'ppN2',
          color: Colors.indigo,
          isEnabled: legendState.showPpN2,
          onTap: legendNotifier.togglePpN2,
        ),
      );
    }

    // ppHe
    if (config.hasPpHeData) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'ppHe',
          color: Colors.pink.shade300,
          isEnabled: legendState.showPpHe,
          onTap: legendNotifier.togglePpHe,
        ),
      );
    }

    // MOD
    if (config.hasModData) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'MOD',
          color: Colors.deepOrange,
          isEnabled: legendState.showMod,
          onTap: legendNotifier.toggleMod,
        ),
      );
    }

    // Density
    if (config.hasDensityData) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'Gas Density',
          color: Colors.brown,
          isEnabled: legendState.showDensity,
          onTap: legendNotifier.toggleDensity,
        ),
      );
    }

    // GF%
    if (config.hasGfData) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'GF%',
          color: Colors.deepPurple,
          isEnabled: legendState.showGf,
          onTap: legendNotifier.toggleGf,
        ),
      );
    }

    // Surface GF
    if (config.hasSurfaceGfData) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'Surface GF',
          color: Colors.purple.shade300,
          isEnabled: legendState.showSurfaceGf,
          onTap: legendNotifier.toggleSurfaceGf,
        ),
      );
    }

    // Mean Depth
    if (config.hasMeanDepthData) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'Mean Depth',
          color: Colors.blueGrey,
          isEnabled: legendState.showMeanDepth,
          onTap: legendNotifier.toggleMeanDepth,
        ),
      );
    }

    // TTS
    if (config.hasTtsData) {
      items.add(
        _buildToggleMenuItem(
          context,
          label: 'TTS',
          color: const Color(0xFFAD1457), // Pink 800
          isEnabled: legendState.showTts,
          onTap: legendNotifier.toggleTts,
        ),
      );
    }

    return items;
  }

  PopupMenuItem<void> _buildToggleMenuItem(
    BuildContext context, {
    required String label,
    required Color color,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return PopupMenuItem<void>(
      onTap: onTap,
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
          Text(label),
        ],
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
          tooltip: 'Zoom out',
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
          tooltip: 'Zoom in',
        ),
        // Reset zoom / fit button
        if (isZoomed)
          IconButton(
            onPressed: onResetZoom,
            icon: const Icon(Icons.fit_screen),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Reset zoom',
          ),
      ],
    );
  }
}
