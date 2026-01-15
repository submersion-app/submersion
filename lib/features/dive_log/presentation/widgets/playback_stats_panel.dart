import 'package:flutter/material.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../data/services/profile_analysis_service.dart';
import '../../domain/entities/dive.dart';

/// Panel showing real-time dive statistics at the current playback position.
///
/// Displays interpolated values for depth, temperature, pressure, heart rate,
/// NDL/ceiling, and ppO2 based on the current timestamp.
class PlaybackStatsPanel extends StatelessWidget {
  /// The dive profile data
  final List<DiveProfilePoint> profile;

  /// Current playback timestamp in seconds
  final int currentTimestamp;

  /// Profile analysis data (for deco status, ppO2, etc.)
  final ProfileAnalysis? analysis;

  /// Unit formatter for displaying values
  final UnitFormatter units;

  const PlaybackStatsPanel({
    super.key,
    required this.profile,
    required this.currentTimestamp,
    required this.units,
    this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    if (profile.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find the profile point at or closest to the current timestamp
    final pointData = _getDataAtTimestamp(currentTimestamp);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Live Stats',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: colorScheme.primary),
              ),
              const Spacer(),
              Text(
                _formatTimestamp(currentTimestamp),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats grid
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _StatItem(
                label: 'Depth',
                value: units.formatDepth(pointData.depth),
                icon: Icons.arrow_downward,
                color: colorScheme.primary,
              ),
              if (pointData.temperature != null)
                _StatItem(
                  label: 'Temp',
                  value: units.formatTemperature(pointData.temperature!),
                  icon: Icons.thermostat,
                  color: colorScheme.tertiary,
                ),
              if (pointData.pressure != null)
                _StatItem(
                  label: 'Pressure',
                  value: '${pointData.pressure!.toStringAsFixed(0)} bar',
                  icon: Icons.speed,
                  color: Colors.orange,
                ),
              if (pointData.heartRate != null)
                _StatItem(
                  label: 'Heart Rate',
                  value: '${pointData.heartRate} bpm',
                  icon: Icons.favorite,
                  color: Colors.red,
                ),
              if (pointData.ndl != null)
                _StatItem(
                  label: pointData.ndl! < 0 ? 'DECO' : 'NDL',
                  value: pointData.ndl! < 0
                      ? _formatCeiling(pointData.ceiling)
                      : _formatNdl(pointData.ndl!),
                  icon: pointData.ndl! < 0 ? Icons.warning : Icons.timer,
                  color: pointData.ndl! < 0 ? Colors.red : Colors.green,
                ),
              if (pointData.ppO2 != null)
                _StatItem(
                  label: 'ppO₂',
                  value: '${pointData.ppO2!.toStringAsFixed(2)} bar',
                  icon: Icons.air,
                  color: _getPpO2Color(pointData.ppO2!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get interpolated data at the given timestamp
  _PlaybackPointData _getDataAtTimestamp(int timestamp) {
    if (profile.isEmpty) {
      return const _PlaybackPointData(depth: 0);
    }

    // Find the surrounding profile points
    DiveProfilePoint? before;
    DiveProfilePoint? after;

    for (final point in profile) {
      if (point.timestamp <= timestamp) {
        before = point;
      }
      if (point.timestamp >= timestamp && after == null) {
        after = point;
        break;
      }
    }

    // If we're before the first point or after the last
    before ??= profile.first;
    after ??= profile.last;

    // If timestamps match, use exact point
    if (before.timestamp == timestamp) {
      return _pointToData(before, _getAnalysisIndex(before.timestamp));
    }
    if (after.timestamp == timestamp) {
      return _pointToData(after, _getAnalysisIndex(after.timestamp));
    }

    // Interpolate between points
    final t =
        (timestamp - before.timestamp) / (after.timestamp - before.timestamp);

    return _PlaybackPointData(
      depth: _lerp(before.depth, after.depth, t),
      temperature: before.temperature != null && after.temperature != null
          ? _lerp(before.temperature!, after.temperature!, t)
          : before.temperature ?? after.temperature,
      pressure: before.pressure != null && after.pressure != null
          ? _lerp(before.pressure!, after.pressure!, t)
          : before.pressure ?? after.pressure,
      heartRate: before.heartRate ?? after.heartRate,
      ndl: _getNdlAtTimestamp(timestamp),
      ceiling: _getCeilingAtTimestamp(timestamp),
      ppO2: _getPpO2AtTimestamp(timestamp),
    );
  }

  _PlaybackPointData _pointToData(DiveProfilePoint point, int? analysisIndex) {
    return _PlaybackPointData(
      depth: point.depth,
      temperature: point.temperature,
      pressure: point.pressure,
      heartRate: point.heartRate,
      ndl: analysisIndex != null && analysis?.ndlCurve != null
          ? analysis!.ndlCurve[analysisIndex]
          : null,
      ceiling: analysisIndex != null && analysis?.ceilingCurve != null
          ? analysis!.ceilingCurve[analysisIndex]
          : null,
      ppO2: analysisIndex != null && analysis?.ppO2Curve != null
          ? analysis!.ppO2Curve[analysisIndex]
          : null,
    );
  }

  int? _getAnalysisIndex(int timestamp) {
    for (int i = 0; i < profile.length; i++) {
      if (profile[i].timestamp == timestamp) {
        return i;
      }
    }
    return null;
  }

  int? _getNdlAtTimestamp(int timestamp) {
    final ndlCurve = analysis?.ndlCurve;
    if (ndlCurve == null || ndlCurve.isEmpty) return null;

    final index = _findClosestIndex(timestamp);
    if (index != null && index < ndlCurve.length) {
      return ndlCurve[index];
    }
    return null;
  }

  double? _getCeilingAtTimestamp(int timestamp) {
    final ceilingCurve = analysis?.ceilingCurve;
    if (ceilingCurve == null || ceilingCurve.isEmpty) return null;

    final index = _findClosestIndex(timestamp);
    if (index != null && index < ceilingCurve.length) {
      return ceilingCurve[index];
    }
    return null;
  }

  double? _getPpO2AtTimestamp(int timestamp) {
    final ppO2Curve = analysis?.ppO2Curve;
    if (ppO2Curve == null || ppO2Curve.isEmpty) return null;

    final index = _findClosestIndex(timestamp);
    if (index != null && index < ppO2Curve.length) {
      return ppO2Curve[index];
    }
    return null;
  }

  int? _findClosestIndex(int timestamp) {
    if (profile.isEmpty) return null;

    int closestIndex = 0;
    int closestDiff = (profile[0].timestamp - timestamp).abs();

    for (int i = 1; i < profile.length; i++) {
      final diff = (profile[i].timestamp - timestamp).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  String _formatTimestamp(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatNdl(int seconds) {
    if (seconds > 9999) return '∞';
    final minutes = seconds ~/ 60;
    return '${minutes}min';
  }

  String _formatCeiling(double? ceiling) {
    if (ceiling == null) return '-';
    return '${ceiling.toStringAsFixed(0)}m';
  }

  Color _getPpO2Color(double ppO2) {
    if (ppO2 > 1.6) return Colors.red;
    if (ppO2 > 1.4) return Colors.orange;
    if (ppO2 < 0.16) return Colors.blue;
    return Colors.green;
  }
}

/// Internal data class for interpolated values
class _PlaybackPointData {
  final double depth;
  final double? temperature;
  final double? pressure;
  final int? heartRate;
  final int? ndl;
  final double? ceiling;
  final double? ppO2;

  const _PlaybackPointData({
    required this.depth,
    this.temperature,
    this.pressure,
    this.heartRate,
    this.ndl,
    this.ceiling,
    this.ppO2,
  });
}

/// Single stat item widget
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
