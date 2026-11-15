import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_subtitle.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One day of a trip as a line on the Trip page: its number, its date, what
/// kind of day it was and where, and what was dived. Tapping it opens that
/// day.
///
/// A surface day is drawn muted and shows no dive figures, so the dived days
/// stand out when the list is scanned.
class TripStoryDayLine extends ConsumerWidget {
  const TripStoryDayLine({super.key, required this.day, required this.onTap});

  final TripStoryDay day;
  final VoidCallback onTap;

  static Key keyFor(int dayNumber) => Key('trip-day-line-$dayNumber');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final date = units.formatWeekdayMonthDay(day.date);
    final parts = tripDaySubtitleParts(context, day);
    final quiet = day.isSurface || day.isPlannedRest;
    final maxDepth = day.maxDepth;

    return Semantics(
      key: keyFor(day.dayNumber),
      container: true,
      button: true,
      label: [date, ...parts].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: quiet
                      ? scheme.surfaceContainerHighest
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.dayNumber}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: quiet
                        ? scheme.onSurfaceVariant
                        : scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      date,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: quiet ? scheme.onSurfaceVariant : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (parts.isNotEmpty)
                      Text(
                        parts.join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (day.kind == TripStoryDayKind.today) ...[
                const SizedBox(width: 8),
                const TodayChip(),
              ],
              if (day.dives.isNotEmpty) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.diveLog_listPage_tripGroupDiveCount(day.diveCount),
                      style: theme.textTheme.labelLarge,
                    ),
                    if (maxDepth != null)
                      Text(
                        units.formatDepth(maxDepth),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
