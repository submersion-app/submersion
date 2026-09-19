import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Card listing the newest dives shared with a buddy, capped at five, with a
/// "view all" link that hands the buddy's full dive-id set to the dive list
/// filter (#982: the year is shown alongside the date since the list
/// routinely spans several years, unlike a bare "Mar 28").
///
/// Split out of [BuddyDetailPage] to keep that file under the project's
/// 800-line guideline.
class BuddySharedDivesSection extends ConsumerWidget {
  final String buddyId;

  const BuddySharedDivesSection({super.key, required this.buddyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diveIdsAsync = ref.watch(diveIdsForBuddyProvider(buddyId));
    final divesAsync = ref.watch(divesForBuddyProvider(buddyId));
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.buddies_section_sharedDives,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                diveIdsAsync.when(
                  data: (ids) => TextButton(
                    onPressed: ids.isEmpty
                        ? null
                        : () {
                            // Set filter to show only shared dives with this buddy
                            ref.read(diveFilterProvider.notifier).state =
                                DiveFilterState(diveIds: ids, buddyId: buddyId);
                            // Navigate to dive list
                            context.go('/dives');
                          },
                    child: Text(
                      context.l10n.buddies_action_viewAll(ids.length),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            divesAsync.when(
              data: (dives) {
                if (dives.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(context.l10n.buddies_detail_noDivesTogether),
                    ),
                  );
                }
                // Show first 5 dives with same format as trip detail page
                final displayDives = dives.take(5).toList();
                return Column(
                  children: displayDives.map((dive) {
                    return Semantics(
                      button: true,
                      label:
                          'View dive ${dive.diveNumber ?? ''} at ${dive.site?.name ?? 'Unknown Site'}',
                      child: InkWell(
                        onTap: () => context.push('/dives/${dive.id}'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              // Dive number badge
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
                              // Dive details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dive.site?.name ?? 'Unknown Site',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      units.formatDate(dive.dateTime),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              // Stats
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (dive.maxDepth != null)
                                    Text(
                                      units.formatDepth(dive.maxDepth),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  if (dive.bottomTime != null)
                                    Text(
                                      '${dive.bottomTime!.inMinutes}min',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.chevron_right,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
              error: (e, st) =>
                  Text(context.l10n.buddies_error_unableToLoadDives),
            ),
          ],
        ),
      ),
    );
  }
}
