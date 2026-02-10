import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';

/// Panel showing statistics for a selected range of the dive profile.
///
/// Displays min, max, and average values for depth, temperature,
/// pressure, and heart rate within the selected time range.
class RangeStatsPanel extends ConsumerWidget {
  /// The dive ID for scoping the range selection provider
  final String diveId;

  /// The dive profile data
  final List<DiveProfilePoint> profile;

  /// Unit formatter for displaying values
  final UnitFormatter units;

  /// Callback when range is cleared/closed
  final VoidCallback? onClose;

  const RangeStatsPanel({
    super.key,
    required this.diveId,
    required this.profile,
    required this.units,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeState = ref.watch(rangeSelectionProvider(diveId));

    if (!rangeState.isEnabled || !rangeState.hasSelection) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final stats = _calculateRangeStats(rangeState);

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
                  'Range Analysis',
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
                Text(
                  rangeState.formattedDuration,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    ref
                        .read(rangeSelectionProvider(diveId).notifier)
                        .disableRangeMode();
                    onClose?.call();
                  },
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Close range analysis',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats table
            _buildStatsTable(context, stats),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTable(BuildContext context, _RangeStats stats) {
    final colorScheme = Theme.of(context).colorScheme;
    final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.bold,
    );

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
      },
      children: [
        // Header row
        TableRow(
          children: [
            const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Min',
                style: headerStyle,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Max',
                style: headerStyle,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Avg',
                style: headerStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        // Depth row
        _buildStatRow(
          context,
          'Depth',
          units.formatDepth(stats.minDepth),
          units.formatDepth(stats.maxDepth),
          units.formatDepth(stats.avgDepth),
          Icons.arrow_downward,
          colorScheme.primary,
        ),
        // Temperature row (if available)
        if (stats.hasTemperature)
          _buildStatRow(
            context,
            'Temp',
            units.formatTemperature(stats.minTemp!),
            units.formatTemperature(stats.maxTemp!),
            units.formatTemperature(stats.avgTemp!),
            Icons.thermostat,
            colorScheme.tertiary,
          ),
        // Pressure row (if available)
        if (stats.hasPressure)
          _buildStatRow(
            context,
            'Pressure',
            '${stats.minPressure!.toStringAsFixed(0)} bar',
            '${stats.maxPressure!.toStringAsFixed(0)} bar',
            '${stats.avgPressure!.toStringAsFixed(0)} bar',
            Icons.speed,
            Colors.orange,
          ),
        // Heart rate row (if available)
        if (stats.hasHeartRate)
          _buildStatRow(
            context,
            'Heart Rate',
            '${stats.minHR} bpm',
            '${stats.maxHR} bpm',
            '${stats.avgHR!.toStringAsFixed(0)} bpm',
            Icons.favorite,
            Colors.red,
          ),
      ],
    );
  }

  TableRow _buildStatRow(
    BuildContext context,
    String label,
    String minValue,
    String maxValue,
    String avgValue,
    IconData icon,
    Color color,
  ) {
    final valueStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFeatures: [const FontFeature.tabularFigures()],
    );

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(minValue, style: valueStyle, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(maxValue, style: valueStyle, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(avgValue, style: valueStyle, textAlign: TextAlign.center),
        ),
      ],
    );
  }

  _RangeStats _calculateRangeStats(RangeSelectionState rangeState) {
    final rangePoints = profile
        .where(
          (p) =>
              p.timestamp >= rangeState.startTimestamp! &&
              p.timestamp <= rangeState.endTimestamp!,
        )
        .toList();

    if (rangePoints.isEmpty) {
      return const _RangeStats(minDepth: 0, maxDepth: 0, avgDepth: 0);
    }

    // Depth stats
    final depths = rangePoints.map((p) => p.depth).toList();
    final minDepth = depths.reduce(math.min);
    final maxDepth = depths.reduce(math.max);
    final avgDepth = depths.reduce((a, b) => a + b) / depths.length;

    // Temperature stats
    final temps = rangePoints
        .where((p) => p.temperature != null)
        .map((p) => p.temperature!)
        .toList();
    double? minTemp, maxTemp, avgTemp;
    if (temps.isNotEmpty) {
      minTemp = temps.reduce(math.min);
      maxTemp = temps.reduce(math.max);
      avgTemp = temps.reduce((a, b) => a + b) / temps.length;
    }

    // Pressure stats
    final pressures = rangePoints
        .where((p) => p.pressure != null)
        .map((p) => p.pressure!)
        .toList();
    double? minPressure, maxPressure, avgPressure;
    if (pressures.isNotEmpty) {
      minPressure = pressures.reduce(math.min);
      maxPressure = pressures.reduce(math.max);
      avgPressure = pressures.reduce((a, b) => a + b) / pressures.length;
    }

    // Heart rate stats
    final heartRates = rangePoints
        .where((p) => p.heartRate != null)
        .map((p) => p.heartRate!)
        .toList();
    int? minHR, maxHR;
    double? avgHR;
    if (heartRates.isNotEmpty) {
      minHR = heartRates.reduce(math.min);
      maxHR = heartRates.reduce(math.max);
      avgHR = heartRates.reduce((a, b) => a + b) / heartRates.length;
    }

    return _RangeStats(
      minDepth: minDepth,
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      minTemp: minTemp,
      maxTemp: maxTemp,
      avgTemp: avgTemp,
      minPressure: minPressure,
      maxPressure: maxPressure,
      avgPressure: avgPressure,
      minHR: minHR,
      maxHR: maxHR,
      avgHR: avgHR,
    );
  }
}

/// Internal class to hold range statistics
class _RangeStats {
  final double minDepth;
  final double maxDepth;
  final double avgDepth;
  final double? minTemp;
  final double? maxTemp;
  final double? avgTemp;
  final double? minPressure;
  final double? maxPressure;
  final double? avgPressure;
  final int? minHR;
  final int? maxHR;
  final double? avgHR;

  const _RangeStats({
    required this.minDepth,
    required this.maxDepth,
    required this.avgDepth,
    this.minTemp,
    this.maxTemp,
    this.avgTemp,
    this.minPressure,
    this.maxPressure,
    this.avgPressure,
    this.minHR,
    this.maxHR,
    this.avgHR,
  });

  bool get hasTemperature => minTemp != null;
  bool get hasPressure => minPressure != null;
  bool get hasHeartRate => minHR != null;
}
