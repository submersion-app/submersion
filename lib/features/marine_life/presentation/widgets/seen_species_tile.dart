import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One row of the Species page: a category avatar, the localized name, the
/// scientific name, and the sighting aggregates.
class SeenSpeciesTile extends ConsumerWidget {
  final SeenSpecies entry;
  final VoidCallback? onTap;

  const SeenSpeciesTile({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final species = entry.species;
    final scientific = species.scientificName;
    final hasScientific = scientific != null && scientific.isNotEmpty;
    final counts = [
      l10n.marineLife_speciesPage_sightingsCount(entry.totalSightings),
      l10n.marineLife_speciesPage_divesCount(entry.diveCount),
      l10n.marineLife_speciesPage_lastSeen(units.formatDate(entry.lastSeen)),
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorForSpeciesCategory(
          species.category,
          Theme.of(context).brightness,
        ),
        child: Icon(
          iconForSpeciesCategory(species.category),
          color: Colors.white,
        ),
      ),
      title: Text(species.localizedCommonName(l10n)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasScientific)
            Text(
              scientific,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          Text(counts),
        ],
      ),
      isThreeLine: hasScientific,
      onTap: onTap,
    );
  }
}
