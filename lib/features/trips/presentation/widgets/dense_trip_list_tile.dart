import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Single-row flat tile for the trip list (maximum density).
///
/// Row: Trip name (expanded) | Abbreviated date range (~100px) | Dive count (~40px) | Chevron
class DenseTripListTile extends StatelessWidget {
  final TripWithStats tripWithStats;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showSharedBadge;

  const DenseTripListTile({
    super.key,
    required this.tripWithStats,
    this.isSelected = false,
    this.onTap,
    this.showSharedBadge = false,
  });

  /// Formats a date as "MMM d", adding the year if it is not the current year.
  String _formatAbbreviated(DateTime date) {
    final now = DateTime.now();
    if (date.year != now.year) {
      return DateFormat('MMM d, yyyy').format(date);
    }
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final trip = tripWithStats.trip;
    final colorScheme = Theme.of(context).colorScheme;
    final rowColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : null;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    final startStr = _formatAbbreviated(trip.startDate);
    final endStr = _formatAbbreviated(trip.endDate);
    final dateRangeStr = '$startStr - $endStr';

    return Semantics(
      button: true,
      label: '${trip.name}, $dateRangeStr',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Trip name (expanded)
                Expanded(
                  child: Text(
                    trip.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showSharedBadge) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message:
                        context.l10n.accessibility_label_sharedWithAllProfiles,
                    child: Icon(
                      Icons.people_outline,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // Abbreviated date range (~100px)
                SizedBox(
                  width: 100,
                  child: Text(
                    dateRangeStr,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                // Dive count (~40px)
                SizedBox(
                  width: 40,
                  child: Text(
                    '${tripWithStats.diveCount}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                    textAlign: TextAlign.right,
                  ),
                ),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: secondaryTextColor,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
