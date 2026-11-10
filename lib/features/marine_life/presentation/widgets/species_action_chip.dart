import 'package:flutter/material.dart';

import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';

/// A compact chip naming one species beside its category icon, the whole
/// chip one tap target (one semantics node holding the name and the action).
///
/// The species map's site card and the reef tier's read-only mode both
/// open the species with it.
class SpeciesActionChip extends StatelessWidget {
  final Species species;
  final String label;
  final VoidCallback onPressed;

  const SpeciesActionChip({
    super.key,
    required this.species,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: ExcludeSemantics(
        child: Icon(
          iconForSpeciesCategory(species.category),
          size: 16,
          color: colorForSpeciesCategory(species.category, theme.brightness),
        ),
      ),
      label: Text(label, style: theme.textTheme.bodySmall),
      onPressed: onPressed,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
