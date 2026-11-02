import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A species' category, in the colour the catalog gives it.
class SpeciesCatalogIcon extends StatelessWidget {
  const SpeciesCatalogIcon(this.category, {super.key});

  final SpeciesCategory category;

  @override
  Widget build(BuildContext context) => Icon(
    iconForSpeciesCategory(category),
    color: switch (category) {
      SpeciesCategory.fish => Colors.blue,
      SpeciesCategory.shark => Colors.blueGrey,
      SpeciesCategory.ray => Colors.indigo,
      SpeciesCategory.mammal => Colors.teal,
      SpeciesCategory.turtle => Colors.green,
      SpeciesCategory.invertebrate => Colors.orange,
      SpeciesCategory.coral => Colors.pink,
      SpeciesCategory.plant => Colors.lightGreen,
      SpeciesCategory.other => Colors.grey,
    },
  );
}

/// A catalog species' row: its name in the diver's language, and its
/// scientific name or category.
class SpeciesCatalogTile extends StatelessWidget {
  const SpeciesCatalogTile({
    super.key,
    required this.species,
    required this.onTap,
    this.leading,
    this.trailing,
  });

  final Species species;
  final VoidCallback onTap;

  /// Defaults to the [SpeciesCatalogIcon].
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: leading ?? SpeciesCatalogIcon(species.category),
    title: Text(species.localizedCommonName(context.l10n)),
    subtitle: species.scientificName != null
        ? Text(
            species.scientificName!,
            style: const TextStyle(fontStyle: FontStyle.italic),
          )
        : Text(species.category.localizedName(context.l10n)),
    trailing: trailing,
    onTap: onTap,
  );
}
