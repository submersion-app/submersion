import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_summary_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/close_dive_search.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown under the Dive Log Summary title while the dive list is filtered
/// (issue #1078), so the filtered totals below it are never read as lifetime
/// ones: "Filtered: summarizing 34 of 812 dives", plus a Clear Filters button
/// that clears the list's filter the same way the list's own button does.
///
/// Both counts come from the statistics queries, so they count exactly the
/// dives the cards below summarize: logged dives inside the statistics scope
/// (DiveStatsScope drops dives excluded from statistics and planned dives).
/// They can therefore read lower than the list's "34 of 812 dives" subtitle,
/// which counts every dive; do not swap in the list's count, or the banner
/// would misstate what the summary covers.
class DiveSummaryFilterBanner extends ConsumerWidget {
  const DiveSummaryFilterBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // `.value`, not `valueOrNull`: a filter edit reloads the scoped totals,
    // and `.value` keeps the previous counts until the new query lands, the
    // way the cards below do, instead of blanking on every keystroke.
    final shown = ref.watch(diveListScopedStatisticsProvider).value;
    final total = ref.watch(diveStatisticsProvider).value;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.filter_list,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              shown == null || total == null
                  ? ''
                  : context.l10n.diveLog_summary_filteredBanner(
                      shown.totalDives,
                      total.totalDives,
                    ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            // Through closeDiveSearch, not a bare state reset: it also drops
            // search text still waiting on its debounce, and offers Undo.
            onPressed: () => closeDiveSearch(context, ref, collapse: false),
            child: Text(context.l10n.diveLog_emptyFiltered_clearFilters),
          ),
        ],
      ),
    );
  }
}
