import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/seen_species_filter.dart';
import 'package:submersion/features/marine_life/domain/species_grouping.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
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

/// The label of a sort order in the sort menu.
String sortLabel(AppLocalizations l10n, SeenSpeciesSort sort) => switch (sort) {
  SeenSpeciesSort.mostDives => l10n.marineLife_speciesPage_sort_mostDives,
  SeenSpeciesSort.recentlySeen => l10n.marineLife_speciesPage_sort_recentlySeen,
  SeenSpeciesSort.firstSeen => l10n.marineLife_speciesPage_sort_firstSeen,
  SeenSpeciesSort.name => l10n.marineLife_speciesPage_sort_name,
};

/// The one quiet row above the Species cards (issue #5027): what is shown,
/// the species without a photo, sort, Group by and the cards or list
/// switch. A category chosen from a shelf's See all shows under it as a
/// chip that clears it.
class SpeciesBrowseControls extends StatelessWidget {
  const SpeciesBrowseControls({
    super.key,
    required this.summary,
    required this.groupBy,
    required this.grid,
    required this.sort,
    required this.withoutPhoto,
    required this.noPhotoFilterOn,
    required this.onGroupBy,
    required this.onGrid,
    required this.onSort,
    required this.onNoPhotoFilter,
    this.category,
    this.onClearCategory,
  });

  /// The count line, e.g. "42 species · 310 sightings".
  final String summary;
  final SpeciesGroupBy groupBy;
  final bool grid;
  final SeenSpeciesSort sort;

  /// Species on the whole life list with no picture; no chip at zero
  /// unless its filter is on, so it can always be turned off.
  final int withoutPhoto;
  final bool noPhotoFilterOn;
  final ValueChanged<SpeciesGroupBy> onGroupBy;
  final ValueChanged<bool> onGrid;
  final ValueChanged<SeenSpeciesSort> onSort;
  final ValueChanged<bool> onNoPhotoFilter;
  final SpeciesCategory? category;
  final VoidCallback? onClearCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final category = this.category;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (withoutPhoto > 0 || noPhotoFilterOn)
                FilterChip(
                  key: const ValueKey('species_no_photo_chip'),
                  tooltip: l10n.marineLife_speciesPage_withoutPhoto(
                    withoutPhoto,
                  ),
                  avatar: const Icon(Icons.hide_image_outlined, size: 16),
                  label: Text('$withoutPhoto'),
                  visualDensity: VisualDensity.compact,
                  // The checkmark would be drawn over the icon; the
                  // selected colour says the filter is on.
                  showCheckmark: false,
                  selected: noPhotoFilterOn,
                  onSelected: onNoPhotoFilter,
                ),
              PopupMenuButton<SeenSpeciesSort>(
                key: const ValueKey('species_sort_menu'),
                icon: const Icon(Icons.sort),
                tooltip: l10n.marineLife_speciesPage_sortTooltip,
                onSelected: onSort,
                itemBuilder: (context) => [
                  for (final s in SeenSpeciesSort.values)
                    CheckedPopupMenuItem(
                      value: s,
                      checked: s == sort,
                      child: Text(sortLabel(l10n, s)),
                    ),
                ],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          groupByLabel(l10n, groupBy),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 20),
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
          if (category != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InputChip(
                key: const ValueKey('species_category_filter'),
                label: Text(category.localizedName(l10n)),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: onClearCategory,
              ),
            ),
        ],
      ),
    );
  }
}
