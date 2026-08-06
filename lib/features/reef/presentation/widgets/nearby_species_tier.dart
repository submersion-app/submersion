import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Species recorded near a dive site, shown beneath Spotted and Expected.
///
/// Records matching the catalog render with a common name, icon and colour and
/// can be added to the Expected list in one tap. Unmatched records are the
/// regional long tail and show scientific names only.
class NearbySpeciesTier extends ConsumerWidget {
  final String siteId;
  final GeoPoint location;

  const NearbySpeciesTier({
    super.key,
    required this.siteId,
    required this.location,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final part = ref
        .watch(reefSnapshotProvider(location))
        .maybeWhen(
          data: (snapshot) => snapshot.species,
          orElse: () => const ReefPart<NearbySpecies>.unavailable(),
        );

    if (part.status != ReefDataStatus.ok || part.value!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sourced from the species provider rather than the bundled asset. A
    // FutureBuilder would build a new Future on every rebuild and drop back to
    // its empty state for a frame, and the provider additionally reflects
    // user-created and user-edited species.
    final catalog = ref
        .watch(allSpeciesProvider)
        .maybeWhen(data: (species) => species, orElse: () => const <Species>[]);
    if (catalog.isEmpty) return const SizedBox.shrink();

    return _buildTier(context, ref, part.value!, {
      for (final s in catalog) s.id: s,
    });
  }

  Widget _buildTier(
    BuildContext context,
    WidgetRef ref,
    NearbySpecies species,
    Map<String, Species> byId,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.reef_species_recordedNearby,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        for (final match in species.matched)
          if (byId[match.speciesId] case final Species s)
            ListTile(
              dense: true,
              leading: Icon(
                iconForSpeciesCategory(s.category),
                color: colorForSpeciesCategory(s.category, theme.brightness),
              ),
              title: Text(s.commonName),
              subtitle: s.scientificName == null
                  ? null
                  : Text(s.scientificName!),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: context.l10n.reef_species_addToExpected,
                onPressed: () => ref
                    .read(siteExpectedSpeciesNotifierProvider(siteId).notifier)
                    .addSpecies(s.id),
              ),
            ),
        for (final name in species.unmatchedNames)
          ListTile(
            dense: true,
            leading: const Icon(Icons.help_outline),
            title: Text(name, style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}
