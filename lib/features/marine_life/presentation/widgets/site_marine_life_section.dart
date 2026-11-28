import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/site_species_chip_groups.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_tier_header.dart';
import 'package:submersion/features/reef/presentation/widgets/nearby_species_tier.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// The marine life at a dive site, shown only: the site page's Marine life
/// card, whose pencil edits the expected species in a sitting (issue #4527,
/// phase 2), the one way to change them.
class SiteMarineLifeSection extends ConsumerWidget {
  final String siteId;

  /// When present, a "Recorded nearby" tier is shown from online sources.
  final GeoPoint? location;

  /// The expected species to show in place of those stored: a sitting's,
  /// once the diver has changed them (issue #4527).
  final List<SiteSpeciesEntry>? species;

  const SiteMarineLifeSection({
    super.key,
    required this.siteId,
    this.location,
    this.species,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spottedAsync = ref.watch(siteSpottedSpeciesProvider(siteId));
    final held = species;
    final expectedAsync = held != null
        ? AsyncValue.data(held)
        : ref.watch(siteExpectedSpeciesProvider(siteId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildSpottedSection(context, ref, spottedAsync),
            _sectionDivider,
            _buildExpectedSection(context, ref, expectedAsync),
            if (location != null)
              // Shown only, as on the species map: a species opens its
              // page, and adding one is the unlocked card's (plan 7). The
              // divider comes with the tier's header, since the tier alone
              // knows whether it draws anything.
              NearbySpeciesTier(
                siteId: siteId,
                location: location!,
                onSpeciesTap: (id) => context.push('/species/$id'),
                headerBuilder: (context, count) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionDivider,
                    SpeciesTierHeader(
                      icon: Icons.travel_explore,
                      title: context.l10n.reef_species_recordedNearby,
                      count: count,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// What separates one section of the card from the next.
  static const Widget _sectionDivider = Divider(height: 32);

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // The pencil, while the page is unlocked (issue #4527).
    return RecordCardHeader(
      title: context.l10n.marineLife_siteSection_title,
      leading: Icon(Icons.water, size: 20, color: colorScheme.primary),
    );
  }

  Widget _buildSpottedSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SiteSpeciesSummary>> spottedAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpeciesTierHeader(
          icon: Icons.visibility,
          title: context.l10n.marineLife_siteSection_spottedHere,
          count: spottedAsync.value?.length,
        ),
        const SizedBox(height: 8),
        spottedAsync.when(
          data: (spotted) {
            if (spotted.isEmpty) {
              return Text(
                context.l10n.marineLife_siteSection_noSpotted,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              );
            }
            return SiteSpeciesChipGroups(
              // Another site opens collapsed.
              key: ValueKey(('spotted', siteId)),
              species: spotted
                  .map(
                    (s) => SiteSpeciesChipData(
                      name: localizedSpeciesName(
                        context.l10n,
                        s.speciesId,
                        s.speciesName,
                      ),
                      category: s.category,
                      count: s.sightingCount,
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const SizedBox(
            height: 32,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, stack) => Text(
            context.l10n.marineLife_siteSection_errorLoadingSightings,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildExpectedSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SiteSpeciesEntry>> expectedAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpeciesTierHeader(
          icon: Icons.auto_awesome,
          title: context.l10n.marineLife_siteSection_expectedSpecies,
          count: expectedAsync.value?.length,
        ),
        const SizedBox(height: 8),
        expectedAsync.when(
          data: (expected) {
            if (expected.isEmpty) {
              return Text(
                context.l10n.marineLife_siteSection_noExpected,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              );
            }
            return SiteSpeciesChipGroups(
              key: ValueKey(('expected', siteId)),
              species: expected
                  .map(
                    (s) => SiteSpeciesChipData(
                      name: localizedSpeciesName(
                        context.l10n,
                        s.speciesId,
                        s.speciesName,
                      ),
                      category: s.category,
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const SizedBox(
            height: 32,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, stack) => Text(
            context.l10n.marineLife_siteSection_errorLoadingExpected,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
          ),
        ),
      ],
    );
  }
}
