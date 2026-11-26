import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/marine_life/domain/entities/species_sighting_record.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every dive that saw a species as a dot on a line across the years
/// (issue #5027); a dot opens its dive. The axis runs from the first year
/// to the end of the last, so a single year still spreads its dives out.
class SpeciesSightingsTimeline extends ConsumerWidget {
  const SpeciesSightingsTimeline({super.key, required this.records});

  final List<SpeciesSightingRecord> records;

  static const _dot = 10.0;

  /// The room a year label needs.
  static const _labelWidth = 40.0;

  /// The years to label across [width]: the first, the last, and every
  /// year of a step that keeps labels from overlapping.
  static List<int> _labelYears(int first, int last, double width) {
    final fit = (width / _labelWidth).floor().clamp(2, 1000);
    final step = ((last - first + 1) / fit).ceil().clamp(1, 1000);
    return [
      for (var year = first; year <= last; year++)
        if (year == last || ((year - first) % step == 0 && last - year >= step))
          year,
    ];
  }

  static const _hit = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (records.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    // Dive times are wall clocks flagged UTC: lay them out on that clock.
    final years = records.map((r) => r.diveDateTime.year);
    final first = years.reduce((a, b) => a < b ? a : b);
    final last = years.reduce((a, b) => a > b ? a : b);
    final start = DateTime.utc(first).millisecondsSinceEpoch;
    final end = DateTime.utc(last + 1).millisecondsSinceEpoch;
    // One dot per day: dives on the same day would sit on one another.
    final days = <DateTime>{};
    final dots = [
      for (final r in records)
        if (days.add(
          DateTime.utc(
            r.diveDateTime.year,
            r.diveDateTime.month,
            r.diveDateTime.day,
          ),
        ))
          r,
    ];
    double at(DateTime d) =>
        (DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch - start) /
        (end - start);
    return Padding(
      key: const ValueKey('species_timeline'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.marineLife_speciesDetail_timelineTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth - _hit;
                final labels = _labelYears(first, last, width);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: _hit / 2,
                      right: _hit / 2,
                      top: _hit / 2,
                      child: Container(
                        height: 2,
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    for (final year in labels)
                      Positioned(
                        left: _hit / 2 + at(DateTime.utc(year)) * width,
                        top: _hit,
                        child: Text(
                          '$year',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    for (final record in dots)
                      Positioned(
                        left: at(record.diveDateTime) * width,
                        top: 0,
                        child: Semantics(
                          button: true,
                          label: l10n.marineLife_speciesDetail_timelineDive(
                            units.formatDate(record.diveDateTime),
                          ),
                          child: InkResponse(
                            key: ValueKey('timeline_dot_${record.diveId}'),
                            radius: _hit / 2,
                            onTap: () =>
                                context.push('/dives/${record.diveId}'),
                            child: SizedBox.square(
                              dimension: _hit,
                              child: Center(
                                child: Container(
                                  width: _dot,
                                  height: _dot,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.surface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
