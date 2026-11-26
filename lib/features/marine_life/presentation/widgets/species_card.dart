import 'package:flutter/material.dart';

import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/domain/species_rarity.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_picture_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The label of a rarity badge.
String rarityLabel(AppLocalizations l10n, SpeciesRarity rarity) =>
    switch (rarity) {
      SpeciesRarity.newSpecies => l10n.marineLife_rarity_new,
      SpeciesRarity.seenOnce => l10n.marineLife_rarity_seenOnce,
      SpeciesRarity.notSeenLately => l10n.marineLife_rarity_notSeenLately,
      SpeciesRarity.mastered => l10n.marineLife_rarity_mastered,
    };

/// One species on the Species page grid (issue #5027): its picture filling
/// the top, a rarity badge over it, the name and the dive count below.
class SpeciesCard extends StatelessWidget {
  const SpeciesCard({
    super.key,
    required this.entry,
    required this.picture,
    this.rarity,
    this.firstSeenHere = false,
    this.onTap,
  });

  final SeenSpecies entry;
  final SpeciesPicture picture;
  final SpeciesRarity? rarity;

  /// Whether the group it shows in is where the species was first seen.
  final bool firstSeenHere;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rarity = this.rarity;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SpeciesPictureView(
                    picture: picture,
                    category: entry.species.category,
                  ),
                  if (rarity != null)
                    PositionedDirectional(
                      top: 6,
                      start: 6,
                      child: _Badge(label: rarityLabel(l10n, rarity)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.species.localizedCommonName(l10n),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Text(
                      firstSeenHere
                          ? l10n.marineLife_speciesPage_firstSeenHere
                          : l10n.marineLife_speciesPage_divesCount(
                              entry.diveCount,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: firstSeenHere
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
