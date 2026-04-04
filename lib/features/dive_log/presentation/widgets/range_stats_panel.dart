import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Panel showing statistics for a selected range of the dive profile.
///
/// Displays depth, rate, temperature, gas consumption, and heart rate
/// metrics within the selected time range using a Wrap-based grid.
class RangeStatsPanel extends ConsumerWidget {
  /// The dive ID for scoping the range selection provider
  final String diveId;

  /// The dive profile data
  final List<DiveProfilePoint> profile;

  /// Unit formatter for displaying values
  final UnitFormatter units;

  /// The dive's tanks (for SAC calculation)
  final List<DiveTank> tanks;

  /// SAC unit preference from settings
  final SacUnit sacUnit;

  /// Callback when range is cleared/closed
  final VoidCallback? onClose;

  const RangeStatsPanel({
    super.key,
    required this.diveId,
    required this.profile,
    required this.units,
    required this.tanks,
    required this.sacUnit,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeState = ref.watch(rangeSelectionProvider(diveId));

    if (!rangeState.isEnabled || !rangeState.hasSelection) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final stats = _calculateRangeStats(rangeState, tanks);

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
            _buildStatsGrid(context, stats),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, _RangeStats stats) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chipWidth =
            (constraints.maxWidth - 24) / 4; // 3 gaps x 8px spacing
        return Wrap(
          spacing: 8,
          runSpacing: 8,
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
            // Conditional: Temp | Temp | Gas | SAC (flows into same row)
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

  String _formatSignedDepth(double delta) {
    final converted = units.convertDepth(delta);
    final sign = converted > 0 ? '+' : '';
    return '$sign${converted.toStringAsFixed(1)}${units.depthSymbol}';
  }

  String _formatRate(double rate) {
    final converted = units.convertDepth(rate);
    return '${converted.toStringAsFixed(1)} ${units.depthSymbol}/min';
  }

  String _formatSignedRate(double rate) {
    final converted = units.convertDepth(rate);
    final sign = converted > 0 ? '+' : '';
    return '$sign${converted.toStringAsFixed(1)} ${units.depthSymbol}/min';
  }

  _RangeStats _calculateRangeStats(
    RangeSelectionState rangeState,
    List<DiveTank> tanks,
  ) {
    final rangePoints = profile
        .where(
          (p) =>
              p.timestamp >= rangeState.startTimestamp! &&
              p.timestamp <= rangeState.endTimestamp!,
        )
        .toList();

    if (rangePoints.isEmpty) {
      return const _RangeStats(
        elapsedSeconds: 0,
        depthDelta: 0,
        minDepth: 0,
        maxDepth: 0,
        avgDepth: 0,
        maxDescentRate: 0,
        maxAscentRate: 0,
        avgVerticalSpeed: 0,
      );
    }

    // Elapsed time
    final elapsedSeconds =
        rangePoints.last.timestamp - rangePoints.first.timestamp;

    // Depth stats (needed even for zero-duration to populate min/max/avg)
    final depths = rangePoints.map((p) => p.depth).toList();
    final minDepth = depths.reduce(math.min);
    final maxDepth = depths.reduce(math.max);
    final avgDepth = depths.reduce((a, b) => a + b) / depths.length;

    // Depth delta (signed: positive = deeper)
    final depthDelta = rangePoints.last.depth - rangePoints.first.depth;

    // Guard: zero-duration range has no meaningful rates
    if (elapsedSeconds <= 0) {
      return _RangeStats(
        elapsedSeconds: 0,
        depthDelta: depthDelta,
        minDepth: minDepth,
        maxDepth: maxDepth,
        avgDepth: avgDepth,
        maxDescentRate: 0,
        maxAscentRate: 0,
        avgVerticalSpeed: 0,
      );
    }

    final elapsedMinutes = elapsedSeconds / 60.0;

    // Average vertical speed (m/min, signed)
    final avgVerticalSpeed = depthDelta / elapsedMinutes;

    // Max descent and ascent rates from consecutive point pairs
    double maxDescentRate = 0;
    double maxAscentRate = 0;
    for (int i = 0; i < rangePoints.length - 1; i++) {
      final dt = rangePoints[i + 1].timestamp - rangePoints[i].timestamp;
      if (dt <= 0) continue;
      final dd = rangePoints[i + 1].depth - rangePoints[i].depth;
      final rate = dd / (dt / 60.0); // m/min
      if (rate > 0 && rate > maxDescentRate) {
        maxDescentRate = rate;
      } else if (rate < 0 && rate.abs() > maxAscentRate) {
        maxAscentRate = rate.abs();
      }
    }

    // Temperature stats
    final temps = rangePoints
        .where((p) => p.temperature != null)
        .map((p) => p.temperature!)
        .toList();
    double? minTemp, maxTemp;
    if (temps.isNotEmpty) {
      minTemp = temps.reduce(math.min);
      maxTemp = temps.reduce(math.max);
    }

    // Heart rate stats
    final heartRates = rangePoints
        .where((p) => p.heartRate != null)
        .map((p) => p.heartRate!)
        .toList();
    int? minHR, maxHR;
    if (heartRates.isNotEmpty) {
      minHR = heartRates.reduce(math.min);
      maxHR = heartRates.reduce(math.max);
    }

    return _RangeStats(
      elapsedSeconds: elapsedSeconds,
      depthDelta: depthDelta,
      minDepth: minDepth,
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      maxDescentRate: maxDescentRate,
      maxAscentRate: maxAscentRate,
      avgVerticalSpeed: avgVerticalSpeed,
      minTemp: minTemp,
      maxTemp: maxTemp,
      minHR: minHR,
      maxHR: maxHR,
    );
  }
}

/// Internal class to hold range statistics
class _RangeStats {
  final int elapsedSeconds;
  final double depthDelta;
  final double minDepth;
  final double maxDepth;
  final double avgDepth;
  final double maxDescentRate;
  final double maxAscentRate;
  final double avgVerticalSpeed;
  final double? minTemp;
  final double? maxTemp;
  final int? minHR;
  final int? maxHR;

  const _RangeStats({
    required this.elapsedSeconds,
    required this.depthDelta,
    required this.minDepth,
    required this.maxDepth,
    required this.avgDepth,
    required this.maxDescentRate,
    required this.maxAscentRate,
    required this.avgVerticalSpeed,
    this.minTemp,
    this.maxTemp,
    this.minHR,
    this.maxHR,
  });

  bool get hasTemperature => minTemp != null;
  bool get hasHeartRate => minHR != null;
}
