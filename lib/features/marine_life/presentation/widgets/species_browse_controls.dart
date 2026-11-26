import 'package:flutter/material.dart';

import 'package:submersion/features/marine_life/domain/species_grouping.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The label of a grouping in the Group by menu.
String groupByLabel(AppLocalizations l10n, SpeciesGroupBy by) => switch (by) {
  SpeciesGroupBy.none => l10n.marineLife_speciesPage_groupBy_none,
  SpeciesGroupBy.category => l10n.marineLife_speciesPage_groupBy_category,
  SpeciesGroupBy.firstSeen => l10n.marineLife_speciesPage_groupBy_firstSeen,
  SpeciesGroupBy.trip => l10n.marineLife_speciesPage_groupBy_trip,
  SpeciesGroupBy.site => l10n.marineLife_speciesPage_groupBy_site,
};

/// The row above the Species cards (issue #5027): what is shown, the Group
/// by menu and the cards or list switch.
class SpeciesBrowseControls extends StatelessWidget {
  const SpeciesBrowseControls({
    super.key,
    required this.summary,
    required this.groupBy,
    required this.grid,
    required this.onGroupBy,
    required this.onGrid,
  });

  /// The count line, e.g. "42 species · 310 sightings".
  final String summary;
  final SpeciesGroupBy groupBy;
  final bool grid;
  final ValueChanged<SpeciesGroupBy> onGroupBy;
  final ValueChanged<bool> onGrid;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          PopupMenuButton<SpeciesGroupBy>(
            key: const ValueKey('species_group_by_menu'),
            tooltip: l10n.marineLife_speciesPage_groupByTooltip,
            onSelected: onGroupBy,
            itemBuilder: (context) => [
              for (final by in SpeciesGroupBy.values)
                CheckedPopupMenuItem(
                  value: by,
                  checked: by == groupBy,
                  child: Text(groupByLabel(l10n, by)),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspaces_outline, size: 18),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      groupByLabel(l10n, groupBy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('species_view_toggle'),
            tooltip: grid
                ? l10n.marineLife_speciesPage_showList
                : l10n.marineLife_speciesPage_showCards,
            icon: Icon(grid ? Icons.view_list_outlined : Icons.grid_view),
            onPressed: () => onGrid(!grid),
          ),
        ],
      ),
    );
  }
}
