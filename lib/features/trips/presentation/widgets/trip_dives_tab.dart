import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Dives tab: every dive on the trip in time order, each opening its
/// dive (#2845 put it on every trip; it was the liveaboard layout's).
class TripDivesTab extends ConsumerWidget {
  final String tripId;

  const TripDivesTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divesAsync = ref.watch(divesForTripProvider(tripId));
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final theme = Theme.of(context);

    return divesAsync.when(
      data: (dives) {
        if (dives.isEmpty) {
          return Center(child: Text(context.l10n.trips_detail_dives_empty));
        }
        // Entry-time order, as the story and the dive list order them.
        final sortedDives = List.of(
          dives,
        )..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDives.length,
          itemBuilder: (context, index) {
            final dive = sortedDives[index];
            return InkWell(
              onTap: () => context.push('/dives/${dive.id}'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#${dive.diveNumber ?? '-'}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dive.site?.name ??
                                context.l10n.trips_detail_dives_unknownSite,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            units.formatMonthDay(dive.dateTime),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (dive.maxDepth != null)
                          Text(
                            units.formatDepth(dive.maxDepth),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        // Runtime with a bottom-time fallback, matching the
                        // trip totals so these rows add up to the figure the
                        // Overview tab reports (issue #889).
                        if ((dive.runtime ?? dive.bottomTime) != null)
                          Text(
                            context.l10n.diveLog_sources_minutes(
                              (dive.runtime ?? dive.bottomTime)!.inMinutes,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) =>
          Center(child: Text(context.l10n.trips_detail_dives_errorLoading)),
    );
  }
}
