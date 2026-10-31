import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';
import 'package:submersion/features/insights/domain/logbook_dive_counts.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What Overview shows when no dive is in scope, naming the reason.
///
/// The first-dive prompt is for a logbook with no dives. A filter is only the
/// reason when some dive counts: with every dive excluded, clearing it would
/// change nothing, so the exclusion is named instead (issue #3963). Dives that
/// count, with no filter to hide them, mean the statistics have yet to catch
/// up with a write, so nothing is claimed until they do.
class InsightsOverviewEmptyState extends StatelessWidget {
  final LogbookDiveCounts counts;
  final bool filtered;

  const InsightsOverviewEmptyState({
    super.key,
    required this.counts,
    required this.filtered,
  });

  @override
  Widget build(BuildContext context) {
    if (counts.logged == 0) return const _NoDivesLogged();
    if (counts.allExcluded) return const _AllDivesExcluded();
    if (filtered) return const _NoFilterMatch();
    return const Center(child: CircularProgressIndicator());
  }
}

/// Names how many dives the diver excluded, so the statistics dive count and
/// the logbook dive count differing is self-explaining (#526). Nothing when
/// none are excluded.
class ExcludedDivesFootnote extends ConsumerWidget {
  const ExcludedDivesFootnote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(excludedDiveCountProvider)
        .maybeWhen(
          data: (count) => count == 0
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      key: const Key('insights-excluded-footnote'),
                      context.l10n.insights_excludedDivesFootnote(count),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
          orElse: () => const SizedBox.shrink(),
        );
  }
}

/// Scrolls rather than overflows: the text can wrap in a short pane.
class _EmptyLayout extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _EmptyLayout({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _NoDivesLogged extends StatelessWidget {
  const _NoDivesLogged();

  @override
  Widget build(BuildContext context) {
    return _EmptyLayout(
      icon: Icons.waves,
      title: context.l10n.diveLog_empty_title,
      subtitle: context.l10n.diveLog_empty_subtitle,
      children: [
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => showAddDiveBottomSheet(
            context: context,
            onLogManually: () => context.push('/dives/new'),
            onPlanDive: () => context.push(
              '/dives/new',
              extra: const DivePrefill(isPlanned: true),
            ),
          ),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.diveLog_empty_logFirstDive),
        ),
      ],
    );
  }
}

class _NoFilterMatch extends ConsumerWidget {
  const _NoFilterMatch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EmptyLayout(
      icon: Icons.filter_list_off,
      title: context.l10n.diveLog_emptyFiltered_title,
      subtitle: context.l10n.diveLog_emptyFiltered_subtitle,
      children: [
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => ref.read(insightsFilterProvider.notifier).state =
              const DiveFilterState(),
          icon: const Icon(Icons.clear_all),
          label: Text(context.l10n.diveLog_emptyFiltered_clearFilters),
        ),
        const ExcludedDivesFootnote(),
      ],
    );
  }
}

class _AllDivesExcluded extends StatelessWidget {
  const _AllDivesExcluded();

  @override
  Widget build(BuildContext context) {
    return _EmptyLayout(
      icon: Icons.bar_chart,
      title: context.l10n.insights_empty_allExcluded_title,
      subtitle: context.l10n.insights_empty_allExcluded_subtitle,
      children: const [ExcludedDivesFootnote()],
    );
  }
}
