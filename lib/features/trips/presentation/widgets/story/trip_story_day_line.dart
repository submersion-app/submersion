import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_subtitle.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One day of a trip as a line on the Trip page: its number, its date, what
/// kind of day it was, the sites dived and the area they are in, and what was
/// dived. Tapping it opens that day.
///
/// A surface day is drawn muted and shows no dive figures, so the dived days
/// stand out when the list is scanned. Today carries its chip, and a day
/// ahead is marked Planned: its dives are plans, and must not read as dived.
///
/// Where the line is narrow for its text (a phone at a large text size), the
/// figures and the chip move under the date instead of squeezing it.
class TripStoryDayLine extends ConsumerWidget {
  const TripStoryDayLine({super.key, required this.day, required this.onTap});

  final TripStoryDay day;
  final VoidCallback onTap;

  static Key keyFor(int dayNumber) => Key('trip-day-line-$dayNumber');

  /// Below this many points of width per unit of text scale, the line stacks.
  static const double _roomyWidth = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final date = units.formatWeekdayMonthDay(day.date);
    final parts = tripDaySubtitleParts(context, day);
    // A location already holds a "·" ("Marsa Alam · Red Sea, Egypt"), so two
    // of them are kept apart with a semicolon instead.
    final siteLocations = day.siteLocations;
    final locations = siteLocations.join('; ');
    // Said with commas: a screen reader reads the "·" out as a word.
    final spokenLocations = siteLocations
        .map((location) => location.replaceAll(' · ', ', '))
        .join('; ');
    final quiet = day.isSurface || day.isPlannedRest;
    final maxDepth = day.maxDepth;
    final hasDives = day.dives.isNotEmpty;
    final diveCount = hasDives
        ? l10n.diveLog_listPage_tripGroupDiveCount(day.diveCount)
        : null;
    final depth = hasDives && maxDepth != null
        ? units.formatDepth(maxDepth)
        : null;
    final chip = switch (day.kind) {
      TripStoryDayKind.today => const TodayChip(),
      TripStoryDayKind.future => Chip(
        label: Text(l10n.trips_story_planned),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      TripStoryDayKind.past => null,
    };
    // Everything the line shows, said: the figures and the chip included.
    final spoken = [
      date,
      ...parts,
      if (spokenLocations.isNotEmpty) spokenLocations,
      ?diveCount,
      if (depth != null) l10n.trips_story_dayTile_deepest(depth),
      if (day.kind == TripStoryDayKind.today) l10n.trips_story_today,
      if (day.kind == TripStoryDayKind.future) l10n.trips_story_planned,
    ].join(', ');

    final badge = Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: quiet ? scheme.surfaceContainerHighest : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.dayNumber}',
        style: theme.textTheme.labelLarge?.copyWith(
          color: quiet ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    final dateStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: quiet ? scheme.onSurfaceVariant : null,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Semantics(
      key: keyFor(day.dayNumber),
      container: true,
      button: true,
      label: spoken,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              final scale = scaler.scale(1);
              final roomy = constraints.maxWidth / scale >= _roomyWidth;
              return Row(
                crossAxisAlignment: roomy
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  // A fixed-size box given an alignment would fill the row's
                  // height; unbound, the badge keeps to its number.
                  UnconstrainedBox(child: badge),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (roomy)
                          Text(
                            date,
                            style: dateStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          // The date is read in full, wrapping if it must,
                          // and the chip takes the next line when the two
                          // do not fit.
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(date, style: dateStyle),
                              ?chip,
                            ],
                          ),
                        // Every site is read in full, wrapping as it must:
                        // a day of three dives would otherwise lose two.
                        if (parts.isNotEmpty)
                          Text(parts.join(' · '), style: subtitleStyle),
                        if (locations.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sized with the text beside it, so the pin
                              // keeps to its first line at any text size.
                              Padding(
                                padding: EdgeInsets.only(
                                  top: scaler.scale(1),
                                  right: 4,
                                ),
                                child: Icon(
                                  Icons.place_outlined,
                                  size: scaler.scale(14),
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              Expanded(
                                child: Text(locations, style: subtitleStyle),
                              ),
                            ],
                          ),
                        if (!roomy && diveCount != null)
                          Text(
                            [diveCount, ?depth].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (roomy && chip != null) ...[
                    const SizedBox(width: 8),
                    chip,
                  ],
                  if (roomy && diveCount != null) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(diveCount, style: theme.textTheme.labelLarge),
                        if (depth != null) Text(depth, style: subtitleStyle),
                      ],
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
