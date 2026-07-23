import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fixed-extent sliver delegate for one day's sticky header. Mounted pinned
/// inside a SliverMainAxisGroup, so it stays at the top of its day chapter
/// until the next day's header pushes it out.
class TripStoryDayHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double extent = 52;

  final TripStoryDay day;

  const TripStoryDayHeaderDelegate({required this.day});

  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return TripStoryDayHeader(day: day);
  }

  // TripStoryDay is Equatable, so this compares day content, not identity.
  @override
  bool shouldRebuild(TripStoryDayHeaderDelegate oldDelegate) =>
      oldDelegate.day != day;
}

/// Two compact lines - "Day 3 - Wed, Jul 8" plus the day-type/port/sites
/// subtitle - on an opaque surface so day cards scroll underneath cleanly.
class TripStoryDayHeader extends StatelessWidget {
  final TripStoryDay day;

  const TripStoryDayHeader({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itinerary = day.itineraryDay;
    final subtitleParts = <String>[
      if (itinerary != null) itinerary.dayType.localizedName(context),
      if (itinerary?.portName != null) itinerary!.portName!,
      ...day.siteNames,
    ];

    return Material(
      color: theme.colorScheme.surface,
      child: SizedBox(
        height: TripStoryDayHeaderDelegate.extent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.l10n.trips_story_dayLabel(day.dayNumber)}'
                      ' - ${DateFormat.MMMEd().format(day.date)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitleParts.isNotEmpty)
                      Text(
                        subtitleParts.join(' - '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (day.kind == TripStoryDayKind.future)
                Chip(
                  label: Text(context.l10n.trips_story_planned),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
