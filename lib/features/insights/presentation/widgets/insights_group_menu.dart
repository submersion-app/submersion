import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/insights/presentation/insights_saved_group.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/saved_query_problem_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Finds the selector in tests.
const kInsightsGroupMenuKey = ValueKey('insights-group-menu');

/// Switches Insights between All dives and the diver's saved dive queries
/// (#3479). A group is a saved query: nothing here is Insights' own, so
/// groups sync, and are renamed and reordered, with every other saved query.
class InsightsGroupMenu extends ConsumerWidget {
  const InsightsGroupMenu({
    super.key,
    required this.filter,
    required this.active,
    required this.loads,
  });

  final DiveFilterState filter;

  /// The saved query [filter] is, if any.
  final SavedQueryLoad? active;
  final List<SavedQueryLoad> loads;

  void _setFilter(WidgetRef ref, DiveFilterState next) =>
      ref.read(insightsFilterProvider.notifier).state = next;

  void _pick(BuildContext context, WidgetRef ref, SavedQueryLoad load) {
    if (!load.isApplicable) {
      showSavedQueryProblem(context, load);
      return;
    }
    // The whole group, as the Refine panel's chips apply one: the axes clear.
    _setFilter(ref, DiveFilterState(query: load.node));
  }

  void _save(BuildContext context, WidgetRef ref) {
    final node = insightsFilterQuery(filter);
    if (node == null) return;
    ref.read(diveSearchSaverProvider)(context, ref, node);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final filtered = filter.hasActiveFilters;
    final label = !filtered
        ? l10n.insights_filterBar_allDives
        : active?.saved.name ?? l10n.insights_filterBar_customFilter;

    return PopupMenuButton<VoidCallback>(
      key: kInsightsGroupMenuKey,
      tooltip: l10n.insights_filterBar_chooseGroup,
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        _item(
          label: l10n.insights_filterBar_allDives,
          selected: !filtered,
          onTap: () => _setFilter(ref, const DiveFilterState()),
        ),
        for (final load in loads)
          _item(
            label: load.saved.name,
            selected: identical(load, active),
            icon: _problemIcon(load, theme),
            onTap: () => _pick(context, ref, load),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<VoidCallback>(
          // Shown even with nothing to save, so a diver with no groups yet
          // can tell that they exist.
          enabled: filtered && active == null,
          value: () => _save(context, ref),
          child: Text(l10n.insights_filterBar_saveCurrent),
        ),
        if (loads.isNotEmpty)
          PopupMenuItem<VoidCallback>(
            value: () => context.push('/saved-queries'),
            child: Text(l10n.insights_filterBar_manageSaved),
          ),
      ],
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 4, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<VoidCallback> _item({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Widget? icon,
  }) => PopupMenuItem<VoidCallback>(
    value: onTap,
    child: Row(
      children: [
        SizedBox(
          width: 32,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: selected ? const Icon(Icons.check, size: 18) : icon,
          ),
        ),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );

  /// The same marks as the Refine panel's chips: a deleted reference still
  /// applies, flagged; anything else cannot apply and explains itself.
  Widget? _problemIcon(SavedQueryLoad load, ThemeData theme) =>
      switch (load.problem) {
        null => null,
        SavedQueryProblem.unresolvedRef => Icon(
          Icons.warning_amber,
          size: 18,
          color: theme.colorScheme.tertiary,
        ),
        _ => Icon(
          Icons.error_outline,
          size: 18,
          color: theme.colorScheme.error,
        ),
      };
}
