import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
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
///
/// Both tiers render as chips, matching Spotted and Expected above them. A
/// rich reef site returns dozens of records, and one full-width row each ran
/// to thousands of pixels inside the card (issue #1036).
class NearbySpeciesTier extends ConsumerStatefulWidget {
  final String siteId;
  final GeoPoint location;

  /// Must match the water type the enclosing page passes to [ReefSection]:
  /// both widgets then share one snapshot family entry and one fetch.
  final WaterType? waterType;

  const NearbySpeciesTier({
    super.key,
    required this.siteId,
    required this.location,
    this.waterType,
  });

  @override
  ConsumerState<NearbySpeciesTier> createState() => _NearbySpeciesTierState();
}

class _NearbySpeciesTierState extends ConsumerState<NearbySpeciesTier> {
  /// Enough chips to fill a few rows on a phone, which covers the records
  /// worth acting on without burying the sections below.
  static const int _collapsedLimit = 12;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final part = ref
        .watch(
          reefSnapshotProvider(
            ReefSnapshotRequest(
              location: widget.location,
              fetchHealth: widget.waterType != WaterType.fresh,
            ),
          ),
        )
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

    return _buildTier(context, part.value!, {for (final s in catalog) s.id: s});
  }

  Widget _buildTier(
    BuildContext context,
    NearbySpecies species,
    Map<String, Species> byId,
  ) {
    final theme = Theme.of(context);

    // Built before the header so the count reflects what actually renders: a
    // matched record whose species has since left the catalog draws nothing.
    final chips = <Widget>[
      for (final match in species.matched)
        if (byId[match.speciesId] case final Species s)
          _matchedChip(context, s),
      for (final name in species.unmatchedNames) _unmatchedChip(context, name),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    final hidden = chips.length - _collapsedLimit;
    final visible = _expanded ? chips : chips.take(_collapsedLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.reef_species_recordedNearby,
                style: theme.textTheme.labelLarge,
              ),
            ),
            Text(
              '${chips.length}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: visible),
        if (hidden > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? context.l10n.reef_species_showFewer
                    : context.l10n.reef_species_showAll(chips.length),
              ),
            ),
          ),
      ],
    );
  }

  /// The whole chip is the add button.
  ///
  /// Chip's delete slot would also give a trailing tap target, but it builds
  /// its own semantics node holding the tooltip alone: a screen reader then
  /// announces "add to expected species" with no way to tell which species it
  /// applies to. ActionChip yields one node carrying both the name and the
  /// action, and the handler is named for what it does.
  Widget _matchedChip(BuildContext context, Species species) {
    final theme = Theme.of(context);
    final name = species.localizedCommonName(context.l10n);

    return ActionChip(
      avatar: ExcludeSemantics(
        child: Icon(
          iconForSpeciesCategory(species.category),
          size: 16,
          color: colorForSpeciesCategory(species.category, theme.brightness),
        ),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: theme.textTheme.bodySmall),
          const SizedBox(width: 4),
          // Decorative: the tooltip already names the action for assistive
          // tech, and a second node would say it twice.
          const ExcludeSemantics(
            child: Icon(Icons.add_circle_outline, size: 14),
          ),
        ],
      ),
      tooltip: context.l10n.reef_species_addToExpected,
      onPressed: () => ref
          .read(siteExpectedSpeciesNotifierProvider(widget.siteId).notifier)
          .addSpecies(species.id),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _unmatchedChip(BuildContext context, String scientificName) {
    final theme = Theme.of(context);

    return Chip(
      avatar: const ExcludeSemantics(child: Icon(Icons.help_outline, size: 16)),
      label: Text(scientificName, style: theme.textTheme.bodySmall),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
