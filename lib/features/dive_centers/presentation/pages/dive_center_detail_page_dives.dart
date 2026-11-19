part of 'dive_center_detail_page.dart';

class _DivesSection extends ConsumerWidget {
  final String centerId;

  const _DivesSection({required this.centerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final diveCountAsync = ref.watch(diveCenterDiveCountProvider(centerId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: diveCountAsync.when(
        data: (diveCount) {
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              button: true,
              label: context.l10n.diveCenters_accessibility_viewDives,
              child: InkWell(
                onTap: diveCount > 0
                    ? () {
                        // Set the filter to this dive center and navigate to dive list
                        openDiveList(
                          context,
                          ref,
                          DiveFilterState(diveCenterId: centerId),
                        );
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.scuba_diving,
                          color: colorScheme.onPrimaryContainer,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.diveCenters_detail_divesWithCenter,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              diveCount == 0
                                  ? context
                                        .l10n
                                        .diveCenters_detail_noDivesLogged
                                  : context.l10n.diveCenters_detail_divesLogged(
                                      diveCount,
                                    ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (diveCount > 0)
                        ExcludeSemantics(
                          child: Icon(
                            Icons.chevron_right,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.scuba_diving,
                    color: colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: SizedBox(
                    height: 20,
                    width: 100,
                    child: LinearProgressIndicator(),
                  ),
                ),
              ],
            ),
          ),
        ),
        error: (e, st) => const SizedBox.shrink(),
      ),
    );
  }
}

/// "Permanently closed" under a closed center's name (#3379).
