import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';

/// Compact indicator showing current tide state.
///
/// Displays:
/// - Current tide direction (rising/falling) or slack status
/// - Current water height
/// - Time until next extreme (high or low)
///
/// Usage:
/// ```dart
/// CurrentTideIndicator(
///   status: tideStatus,
/// )
/// ```
class CurrentTideIndicator extends StatelessWidget {
  /// The current tide status to display.
  final TideStatus status;

  /// Whether to show a compact version (no next extreme info).
  final bool compact;

  /// Depth unit preference for height display. Defaults to meters.
  final DepthUnit depthUnit;

  const CurrentTideIndicator({
    super.key,
    required this.status,
    this.compact = false,
    this.depthUnit = DepthUnit.meters,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final currentHeightStr = DepthUnit.meters
        .convert(status.currentHeight, depthUnit)
        .toStringAsFixed(2);
    final nextExtremeLabel = status.nextExtreme != null
        ? ', ${status.nextExtreme!.type == TideExtremeType.high ? 'high' : 'low'} tide in ${_formatDuration(status.timeToNextExtreme!)}'
        : '';
    final semanticLabel =
        '${status.state.displayName} tide, $currentHeightStr${depthUnit.symbol}$nextExtremeLabel';

    return Semantics(
      label: semanticLabel,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Row(
            children: [
              // Tide state icon
              ExcludeSemantics(
                child: Container(
                  width: compact ? 40 : 48,
                  height: compact ? 40 : 48,
                  decoration: BoxDecoration(
                    color: _getStateColor(status.state).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStateIcon(status.state),
                    color: _getStateColor(status.state),
                    size: compact ? 24 : 28,
                  ),
                ),
              ),
              SizedBox(width: compact ? 12 : 16),

              // State info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      status.state.displayName,
                      style:
                          (compact
                                  ? textTheme.titleSmall
                                  : textTheme.titleMedium)
                              ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Current: $currentHeightStr${depthUnit.symbol}',
                      style:
                          (compact ? textTheme.bodySmall : textTheme.bodyMedium)
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    if (status.rateOfChange != null && !compact)
                      Text(
                        '${status.rateOfChange! > 0 ? '+' : ''}${DepthUnit.meters.convert(status.rateOfChange!, depthUnit).toStringAsFixed(2)}${depthUnit.symbol}/hr',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),

              // Next extreme info
              if (!compact && status.nextExtreme != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      status.nextExtreme!.type == TideExtremeType.high
                          ? 'High in'
                          : 'Low in',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _formatDuration(status.timeToNextExtreme!),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: status.nextExtreme!.type == TideExtremeType.high
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      '${DepthUnit.meters.convert(status.nextExtreme!.heightMeters, depthUnit).toStringAsFixed(2)}${depthUnit.symbol}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStateIcon(TideState state) {
    switch (state) {
      case TideState.rising:
        return Icons.trending_up;
      case TideState.falling:
        return Icons.trending_down;
      case TideState.slackHigh:
        return Icons.expand_less;
      case TideState.slackLow:
        return Icons.expand_more;
    }
  }

  Color _getStateColor(TideState state) {
    switch (state) {
      case TideState.rising:
        return Colors.green.shade600;
      case TideState.falling:
        return Colors.orange.shade600;
      case TideState.slackHigh:
        return Colors.red.shade600;
      case TideState.slackLow:
        return Colors.blue.shade600;
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// A simpler tide state badge for inline display.
class TideStateBadge extends StatelessWidget {
  final TideState state;

  const TideStateBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tide state: ${state.displayName}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStateColor(state).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                _getStateIcon(state),
                size: 16,
                color: _getStateColor(state),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              state.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _getStateColor(state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStateIcon(TideState state) {
    switch (state) {
      case TideState.rising:
        return Icons.trending_up;
      case TideState.falling:
        return Icons.trending_down;
      case TideState.slackHigh:
        return Icons.expand_less;
      case TideState.slackLow:
        return Icons.expand_more;
    }
  }

  Color _getStateColor(TideState state) {
    switch (state) {
      case TideState.rising:
        return Colors.green.shade600;
      case TideState.falling:
        return Colors.orange.shade600;
      case TideState.slackHigh:
        return Colors.red.shade600;
      case TideState.slackLow:
        return Colors.blue.shade600;
    }
  }
}
