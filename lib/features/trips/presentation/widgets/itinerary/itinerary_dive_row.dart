import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A compact dive row shown under an itinerary day.
class ItineraryDiveRow extends StatelessWidget {
  final Dive dive;
  final UnitFormatter units;

  const ItineraryDiveRow({super.key, required this.dive, required this.units});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat.Hm();

    return InkWell(
      onTap: () => context.push('/dives/${dive.id}'),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(
              '#${dive.diveNumber ?? '-'}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dive.site?.name ?? '-',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              timeFormat.format(dive.dateTime),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (dive.maxDepth != null) ...[
              const SizedBox(width: 8),
              Text(
                units.formatDepth(dive.maxDepth),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
