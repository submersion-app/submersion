import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';

/// Two-line compact card tile for the trip list.
///
/// Line 1: Trip name (expanded) | Date range (secondary text) | Chevron
/// Line 2: Dive count with scuba icon | Total bottom time with timer icon
class CompactTripListTile extends StatelessWidget {
  final TripWithStats tripWithStats;
  final bool isSelected;
  final VoidCallback? onTap;

  const CompactTripListTile({
    super.key,
    required this.tripWithStats,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trip = tripWithStats.trip;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cardColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : null;
    final secondaryTextColor = colorScheme.onSurfaceVariant;
    final dateFormat = DateFormat.yMMMd();
    final dateRangeStr =
        '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      color: cardColor,
      child: Semantics(
        button: true,
        label: '${trip.name}, $dateRangeStr',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: trip name, date range, chevron
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trip.name,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateRangeStr,
                      style: textTheme.bodySmall?.copyWith(
                        color: secondaryTextColor,
                      ),
                    ),
                    ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right,
                        color: secondaryTextColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                // Line 2: dive count and bottom time
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.scuba_diving,
                      size: 13,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${tripWithStats.diveCount}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    if (tripWithStats.totalBottomTime > 0) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.timer, size: 13, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        tripWithStats.formattedBottomTime,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
