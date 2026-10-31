import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/range_gas_consumption.dart';
import 'package:submersion/features/dive_log/domain/services/range_profile_stats.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Panel showing statistics for a selected range of the dive profile.
///
/// Displays depth, rate, temperature, gas consumption (SAC and RMV, from the
/// transmitter pressure series), and heart rate metrics within the selected
/// time range using a Wrap-based grid.
class RangeStatsPanel extends ConsumerWidget {
  /// The dive ID for scoping the range selection provider
  final String diveId;

  /// The dive profile data
  final List<DiveProfilePoint> profile;

  /// Unit formatter for displaying values
  final UnitFormatter units;

  /// The dive's tanks (for SAC calculation)
  final List<DiveTank> tanks;

  /// Whether the dive was on a rebreather, whose SAC reads the reference
  /// cylinder alone (see `referencePressureDrop`).
  final bool isRebreather;

  /// Callback when range is cleared/closed
  final VoidCallback? onClose;

  /// Most stats placed side by side in one row.
  ///
  /// The grid always has at least [_minColumns] columns, and adds more up to
  /// this cap while each stat still gets [_minChipWidth]. The default keeps
  /// the detail page's fixed four-column grid; the fullscreen strip raises
  /// it so a wide screen shows the stats in one or two rows (#1577).
  final int maxColumns;

  static const int _minColumns = 4;
  static const double _minChipWidth = 120;
  static const double _chipSpacing = 8;

  const RangeStatsPanel({
    super.key,
    required this.diveId,
    required this.profile,
    required this.units,
    required this.tanks,
    this.isRebreather = false,
    this.onClose,
    this.maxColumns = _minColumns,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeState = ref.watch(rangeSelectionProvider(diveId));

    if (!rangeState.isEnabled || !rangeState.hasSelection) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final stats = rangeProfileStats(
      profile: profile,
      startTimestamp: rangeState.startTimestamp!,
      endTimestamp: rangeState.endTimestamp!,
    );
    final gas = _gasConsumption(ref, rangeState);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.timeline,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveLog_rangeStats_title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${RangeSelectionState.formatTimestamp(rangeState.startTimestamp!)} - ${RangeSelectionState.formatTimestamp(rangeState.endTimestamp!)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    ref
                        .read(rangeSelectionProvider(diveId).notifier)
                        .disableRangeMode();
                    onClose?.call();
                  },
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: context.l10n.diveLog_rangeStats_tooltip_close,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats grid
            _buildStatsGrid(context, ref, stats, gas),
          ],
        ),
      ),
    );
  }

  /// Columns for a grid [width] wide: as many [_minChipWidth] stats as fit,
  /// clamped to [_minColumns]..[maxColumns].
  int _columnCountFor(double width) {
    final fitting = ((width + _chipSpacing) / (_minChipWidth + _chipSpacing))
        .floor();
    return fitting.clamp(_minColumns, math.max(_minColumns, maxColumns));
  }

  /// SAC and RMV over the selection, from the pressure series of the
  /// source the chart draws, the same one [profile] comes from.
  ///
  /// The duration is what the pressure series cover of the range, and the
  /// depth is [profile]'s plotted line over that time, not the selection's
  /// Avg Depth (#3973). The line lets a range holding no sample of a sparse
  /// profile still have a depth; there is none off the end of it.
  RangeGasConsumption _gasConsumption(
    WidgetRef ref,
    RangeSelectionState rangeState,
  ) {
    final pressures = ref
        .watch(activeSourceTankPressuresProvider(diveId))
        .value;
    if (pressures == null || pressures.isEmpty) {
      return (sac: null, rmv: null);
    }
    return rangeGasConsumption(
      tanks: tanks,
      tankPressures: pressures,
      startTimestamp: rangeState.startTimestamp!,
      endTimestamp: rangeState.endTimestamp!,
      profile: profile,
      model: ref.watch(gasModelProvider),
      isRebreather: isRebreather,
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    WidgetRef ref,
    RangeProfileStats stats,
    RangeGasConsumption gas,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    // The lanes the diver's preference asks for, as the dive summary shows
    // them: RMV-only falls back to SAC when no cylinder has a volume.
    final display = ref.watch(gasConsumptionDisplayProvider);
    final sac = gas.sac;
    final rmv = display.showsRmv ? gas.rmv : null;
    final showSac = sac != null && (display.showsSac || rmv == null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCountFor(constraints.maxWidth);
        final chipWidth =
            (constraints.maxWidth - _chipSpacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _chipSpacing,
          runSpacing: _chipSpacing,
          children: [
            // Row 1: Elapsed | Depth Delta | Min Depth | Max Depth
            _buildStatChip(
              context,
              context.l10n.diveLog_rangeStats_label_elapsed,
              _formatElapsed(stats.elapsedSeconds),
              Icons.timer_outlined,
              colorScheme.primary,
              chipWidth,
            ),
            _buildStatChip(
              context,
              context.l10n.diveLog_rangeStats_label_depthDelta,
              _formatSignedDepth(stats.depthDelta),
              Icons.swap_vert,
              colorScheme.primary,
              chipWidth,
            ),
            _buildStatChip(
              context,
              context.l10n.diveLog_rangeStats_label_minDepth,
              units.formatDepth(stats.minDepth),
              Icons.arrow_upward,
              colorScheme.primary,
              chipWidth,
            ),
            _buildStatChip(
              context,
              context.l10n.diveLog_rangeStats_label_maxDepth,
              units.formatDepth(stats.maxDepth),
              Icons.arrow_downward,
              colorScheme.primary,
              chipWidth,
            ),
            // Row 2: Avg Depth | Avg Vert Speed | Max Descent | Max Ascent
            _buildStatChip(
              context,
              context.l10n.diveLog_rangeStats_label_avgDepth,
              units.formatDepth(stats.avgDepth),
              Icons.straighten,
              colorScheme.primary,
              chipWidth,
            ),
            _buildStatChip(
              context,
              context.l10n.diveLog_rangeStats_label_avgVertSpeed,
              _formatSignedRate(stats.avgVerticalSpeed),
              Icons.speed,
              colorScheme.secondary,
              chipWidth,
            ),
            _buildStatChip(
              context,
              context.l10n.diveLog_rangeStats_label_maxDescent,
              _formatRate(stats.maxDescentRate),
              Icons.trending_down,
              Colors.orange,
              chipWidth,
            ),
            _buildStatChip(
              context,
              context.l10n.diveLog_rangeStats_label_maxAscent,
              _formatRate(stats.maxAscentRate),
              Icons.trending_up,
              Colors.orange,
              chipWidth,
            ),
            // Conditional: Temp | Temp (flows into same row)
            if (stats.hasTemperature) ...[
              _buildStatChip(
                context,
                context.l10n.diveLog_rangeStats_label_minTemp,
                units.formatTemperature(stats.minTemp!),
                Icons.thermostat,
                colorScheme.tertiary,
                chipWidth,
              ),
              _buildStatChip(
                context,
                context.l10n.diveLog_rangeStats_label_maxTemp,
                units.formatTemperature(stats.maxTemp!),
                Icons.thermostat,
                colorScheme.tertiary,
                chipWidth,
              ),
            ],
            // Conditional: SAC | RMV
            if (showSac)
              _buildStatChip(
                context,
                context.l10n.diveLog_detail_label_sac,
                units.formatSac(sac),
                Icons.air,
                Colors.orange,
                chipWidth,
              ),
            if (rmv != null)
              _buildStatChip(
                context,
                context.l10n.diveLog_detail_label_rmv,
                units.formatRmv(rmv),
                Icons.air,
                Colors.orange,
                chipWidth,
              ),
            // Conditional: Heart rate
            if (stats.hasHeartRate) ...[
              _buildStatChip(
                context,
                context.l10n.diveLog_rangeStats_label_minHR,
                '${stats.minHR} bpm',
                Icons.favorite,
                Colors.red,
                chipWidth,
              ),
              _buildStatChip(
                context,
                context.l10n.diveLog_rangeStats_label_maxHR,
                '${stats.maxHR} bpm',
                Icons.favorite,
                Colors.red,
                chipWidth,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    double chipWidth,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: chipWidth,
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatElapsed(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatSignedDepth(double? delta) {
    if (delta == null) return units.formatDepth(null);
    final converted = units.convertDepth(delta);
    final sign = converted > 0 ? '+' : '';
    return '$sign${converted.toStringAsFixed(1)}${units.depthSymbol}';
  }

  String _formatRate(double? rate) {
    if (rate == null) return units.formatDepthRate(null);
    final converted = units.convertDepth(rate);
    return '${converted.toStringAsFixed(1)} ${units.depthRateSymbol}';
  }

  String _formatSignedRate(double? rate) {
    if (rate == null) return units.formatDepthRate(null);
    final converted = units.convertDepth(rate);
    final sign = converted > 0 ? '+' : '';
    return '$sign${converted.toStringAsFixed(1)} ${units.depthRateSymbol}';
  }
}
