import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Table widget displaying high and low tide times.
///
/// Shows a list of upcoming (and optionally past) tide extremes with:
/// - High/low tide indicator
/// - Time of the extreme
/// - Height at the extreme
/// - Duration from now (for future tides)
///
/// Usage:
/// ```dart
/// TideTimesTable(
///   extremes: tideExtremes,
///   now: DateTime.now(),
/// )
/// ```
class TideTimesTable extends StatelessWidget {
  /// List of tide extremes to display.
  final List<TideExtreme> extremes;

  /// Reference time for calculating "time from now".
  /// Defaults to DateTime.now() if not provided.
  final DateTime? now;

  /// Whether to show past extremes (before [now]).
  final bool showPast;

  /// Maximum number of extremes to show.
  final int? maxItems;

  /// Whether to use a compact display style.
  final bool compact;

  /// Depth unit preference for height display. Defaults to meters.
  final DepthUnit depthUnit;

  /// Time format preference (12h or 24h). Defaults to 24-hour if not specified.
  final TimeFormat timeFormat;

  const TideTimesTable({
    super.key,
    required this.extremes,
    this.now,
    this.showPast = true,
    this.maxItems,
    this.compact = false,
    this.depthUnit = DepthUnit.meters,
    this.timeFormat = TimeFormat.twentyFourHour,
  });

  @override
  Widget build(BuildContext context) {
    final reference = now ?? DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Filter and sort extremes
    var displayExtremes = List<TideExtreme>.from(extremes);

    if (!showPast) {
      displayExtremes = displayExtremes
          .where(
            (e) =>
                e.time.isAfter(reference.subtract(const Duration(minutes: 30))),
          )
          .toList();
    }

    displayExtremes.sort((a, b) => a.time.compareTo(b.time));

    if (maxItems != null && displayExtremes.length > maxItems!) {
      displayExtremes = displayExtremes.take(maxItems!).toList();
    }

    if (displayExtremes.isEmpty) {
      return _buildEmptyState(context);
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: compact ? 18 : 20,
                  color: colorScheme.primary,
                ),
                SizedBox(width: compact ? 8 : 12),
                Text(
                  context.l10n.tides_label_tideTimes,
                  style:
                      (compact ? textTheme.titleSmall : textTheme.titleMedium)
                          ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...displayExtremes.map(
            (extreme) => _buildExtremeRow(context, extreme, reference),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.waves,
                size: 48,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.tides_noDataAvailable,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtremeRow(
    BuildContext context,
    TideExtreme extreme,
    DateTime reference,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isPast = extreme.time.isBefore(reference);
    final duration = extreme.durationFrom(reference);

    // Format time using user preference
    final timeFormatter = DateFormat(timeFormat.pattern);
    final dateFormat = DateFormat('EEE, MMM d');
    final isToday = _isSameDay(extreme.time, reference);
    final isTomorrow = _isSameDay(
      extreme.time,
      reference.add(const Duration(days: 1)),
    );

    String dateLabel;
    if (isToday) {
      dateLabel = context.l10n.tides_label_today;
    } else if (isTomorrow) {
      dateLabel = context.l10n.tides_label_tomorrow;
    } else {
      dateLabel = dateFormat.format(extreme.time.toLocal());
    }

    // Colors based on type
    final isHigh = extreme.type == TideExtremeType.high;
    final typeColor = isHigh ? Colors.red.shade600 : Colors.blue.shade600;

    final heightDisplay =
        '${DepthUnit.meters.convert(extreme.heightMeters, depthUnit).toStringAsFixed(2)}${depthUnit.symbol}';
    final tideTypeLabel = isHigh
        ? context.l10n.tides_label_highTide
        : context.l10n.tides_label_lowTide;
    final timeLabel = timeFormatter.format(extreme.time.toLocal());
    final durationLabel = isPast
        ? context.l10n.tides_label_ago(_formatDuration(duration))
        : context.l10n.tides_label_fromNow(_formatDuration(duration));

    return Semantics(
      label:
          '$tideTypeLabel, $dateLabel at $timeLabel, $heightDisplay, $durationLabel',
      child: Container(
        decoration: BoxDecoration(
          color: isPast
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 12,
          ),
          child: Row(
            children: [
              // Type indicator
              ExcludeSemantics(
                child: Container(
                  width: compact ? 36 : 44,
                  height: compact ? 36 : 44,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: isPast ? 0.1 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isHigh ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPast
                        ? typeColor.withValues(alpha: 0.5)
                        : typeColor,
                    size: compact ? 18 : 22,
                  ),
                ),
              ),
              SizedBox(width: compact ? 12 : 16),

              // Time and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeFormatter.format(extreme.time.toLocal()),
                      style:
                          (compact
                                  ? textTheme.titleMedium
                                  : textTheme.titleLarge)
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isPast
                                    ? colorScheme.onSurfaceVariant
                                    : null,
                              ),
                    ),
                    Text(
                      dateLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Height
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${DepthUnit.meters.convert(extreme.heightMeters, depthUnit).toStringAsFixed(2)}${depthUnit.symbol}',
                    style:
                        (compact ? textTheme.titleSmall : textTheme.titleMedium)
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isPast
                                  ? colorScheme.onSurfaceVariant
                                  : typeColor,
                            ),
                  ),
                  Text(
                    extreme.type.shortName,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              if (!compact) ...[
                const SizedBox(width: 16),

                // Duration from now
                SizedBox(
                  width: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatDuration(duration),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isPast
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.primary,
                        ),
                      ),
                      Text(
                        isPast
                            ? context.l10n.tides_label_agoSuffix
                            : context.l10n.tides_label_fromNowSuffix,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDuration(Duration duration) {
    final absMinutes = duration.inMinutes.abs();
    final absHours = duration.inHours.abs();

    if (absMinutes < 60) {
      return '${absMinutes}m';
    } else if (absHours < 24) {
      final remainingMinutes = absMinutes % 60;
      if (remainingMinutes == 0) {
        return '${absHours}h';
      }
      return '${absHours}h ${remainingMinutes}m';
    } else {
      final days = absHours ~/ 24;
      final remainingHours = absHours % 24;
      if (remainingHours == 0) {
        return '${days}d';
      }
      return '${days}d ${remainingHours}h';
    }
  }
}

/// Compact inline widget showing next high and low tide times.
class NextTideTimes extends StatelessWidget {
  /// List of tide extremes (should include future tides).
  final List<TideExtreme> extremes;

  /// Reference time for finding "next" tides.
  final DateTime? now;

  /// Depth unit preference for height display. Defaults to meters.
  final DepthUnit depthUnit;

  /// Time format preference (12h or 24h). Defaults to 24-hour if not specified.
  final TimeFormat timeFormat;

  const NextTideTimes({
    super.key,
    required this.extremes,
    this.now,
    this.depthUnit = DepthUnit.meters,
    this.timeFormat = TimeFormat.twentyFourHour,
  });

  @override
  Widget build(BuildContext context) {
    final reference = now ?? DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Find next high and low
    final futureExtremes =
        extremes.where((e) => e.time.isAfter(reference)).toList()
          ..sort((a, b) => a.time.compareTo(b.time));

    final nextHigh = futureExtremes.cast<TideExtreme?>().firstWhere(
      (e) => e!.type == TideExtremeType.high,
      orElse: () => null,
    );
    final nextLow = futureExtremes.cast<TideExtreme?>().firstWhere(
      (e) => e!.type == TideExtremeType.low,
      orElse: () => null,
    );

    final timeFormatter = DateFormat(timeFormat.pattern);

    return Row(
      children: [
        // Next high
        if (nextHigh != null) ...[
          Icon(Icons.arrow_upward, size: 14, color: Colors.red.shade600),
          const SizedBox(width: 4),
          Text(
            timeFormatter.format(nextHigh.time.toLocal()),
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(
            ' (${DepthUnit.meters.convert(nextHigh.heightMeters, depthUnit).toStringAsFixed(1)}${depthUnit.symbol})',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        if (nextHigh != null && nextLow != null) ...[
          const SizedBox(width: 12),
          Container(width: 1, height: 12, color: colorScheme.outlineVariant),
          const SizedBox(width: 12),
        ],

        // Next low
        if (nextLow != null) ...[
          Icon(Icons.arrow_downward, size: 14, color: Colors.blue.shade600),
          const SizedBox(width: 4),
          Text(
            timeFormatter.format(nextLow.time.toLocal()),
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(
            ' (${DepthUnit.meters.convert(nextLow.heightMeters, depthUnit).toStringAsFixed(1)}${depthUnit.symbol})',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
