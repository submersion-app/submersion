import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Horizontal row of category filter chips: "All" plus one chip per
/// [SpeciesCategory]. Tapping the selected category clears it back to All.
///
/// Shared by the catalog manager and the Species page so the two filter rows
/// cannot drift apart.
class SpeciesCategoryChips extends StatelessWidget {
  final SpeciesCategory? selected;
  final ValueChanged<SpeciesCategory?> onSelected;

  const SpeciesCategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text(l10n.marineLife_speciesManage_allFilter),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...SpeciesCategory.values.map(
            (category) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(
                label: Text(category.localizedName(l10n)),
                selected: selected == category,
                onSelected: (_) =>
                    onSelected(selected == category ? null : category),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
