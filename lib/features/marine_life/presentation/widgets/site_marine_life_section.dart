import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
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
            const SizedBox(height: 16),
            _buildExpectedSection(context, ref, expectedAsync),
            if (location != null) ...[
              const SizedBox(height: 16),
              // Shown only, as on the species map: a species opens its
              // page, and adding one is the unlocked card's (plan 7).
              NearbySpeciesTier(
                siteId: siteId,
                location: location!,
                onSpeciesTap: (id) => context.push('/species/$id'),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
        Row(
          children: [
            Icon(
              Icons.visibility,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.marineLife_siteSection_spottedHere,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
            return _buildSpeciesChips(
              context,
              spotted
                  .map(
                    (s) => _SpeciesChipData(
                      id: s.speciesId,
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
              showCount: true,
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
        Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.marineLife_siteSection_expectedSpecies,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
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
            return _buildSpeciesChips(
              context,
              expected
                  .map(
                    (s) => _SpeciesChipData(
                      id: s.speciesId,
                      name: localizedSpeciesName(
                        context.l10n,
                        s.speciesId,
                        s.speciesName,
                      ),
                      category: s.category,
                    ),
                  )
                  .toList(),
              showCount: false,
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

  Widget _buildSpeciesChips(
    BuildContext context,
    List<_SpeciesChipData> species, {
    required bool showCount,
  }) {
    // Group by category
    final grouped = <SpeciesCategory, List<_SpeciesChipData>>{};
    for (final s in species) {
      grouped.putIfAbsent(s.category, () => []).add(s);
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key.localizedName(context.l10n),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: entry.value.map((s) {
                  final chipLabel = showCount && s.count != null
                      ? context.l10n
                            .marineLife_siteSection_spottedCountSemantics(
                              s.name,
                              s.count!,
                            )
                      : s.name;
                  return Semantics(
                    label: chipLabel,
                    child: Chip(
                      avatar: ExcludeSemantics(
                        child: Icon(
                          iconForSpeciesCategory(s.category),
                          size: 16,
                          color: _getCategoryColor(s.category),
                        ),
                      ),
                      label: Text(
                        showCount && s.count != null
                            ? '${s.name} (${s.count})'
                            : s.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(SpeciesCategory category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Colors.blue;
      case SpeciesCategory.shark:
        return Colors.blueGrey;
      case SpeciesCategory.ray:
        return Colors.indigo;
      case SpeciesCategory.mammal:
        return Colors.teal;
      case SpeciesCategory.turtle:
        return Colors.green;
      case SpeciesCategory.invertebrate:
        return Colors.orange;
      case SpeciesCategory.coral:
        return Colors.pink;
      case SpeciesCategory.plant:
        return Colors.lightGreen;
      case SpeciesCategory.other:
        return Colors.grey;
    }
  }
}

class _SpeciesChipData {
  final String id;
  final String name;
  final SpeciesCategory category;
  final int? count;

  _SpeciesChipData({
    required this.id,
    required this.name,
    required this.category,
    this.count,
  });
}
