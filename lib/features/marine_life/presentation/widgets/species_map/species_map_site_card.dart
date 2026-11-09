import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_card_frame.dart';
import 'package:submersion/features/reef/presentation/widgets/nearby_species_tier.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The places view's card for one site: what the diver logged there, what
/// the site expects that they have not logged, and (with the public layer
/// on) what GBIF records nearby.
class SpeciesMapSiteCard extends ConsumerWidget {
  final SiteSpeciesPin pin;
  final VoidCallback onClose;

  const SpeciesMapSiteCard({
    super.key,
    required this.pin,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final catalogAsync = ref.watch(allSpeciesProvider);
    final catalog = {
      for (final s in catalogAsync.value ?? const <Species>[]) s.id: s,
    };
    final loggedAsync = ref.watch(speciesMapLoggedAtSiteProvider(pin.siteId));
    // The chips need both reads: the counts, and the catalog that names them.
    final failed = loggedAsync.hasError || catalogAsync.hasError;
    final loading = !loggedAsync.hasValue || !catalogAsync.hasValue;
    final logged = loggedAsync.value ?? const <LoggedSpeciesAtSite>[];
    final loggedIds = {for (final l in logged) l.speciesId};
    final expected = [
      for (final entry
          in ref.watch(siteExpectedSpeciesProvider(pin.siteId)).value ??
              const <SiteSpeciesEntry>[])
        if (!loggedIds.contains(entry.speciesId)) entry,
    ];
    final publicOn = ref.watch(speciesMapPublicLayerProvider);
    void openSpecies(String id) => context.push('/species/$id');

    return SpeciesMapCardFrame(
      title: pin.siteName,
      subtitle: l10n.speciesMap_card_speciesCount(pin.speciesCount),
      openTooltip: l10n.speciesMap_card_openSite,
      onOpenTitle: () => context.push('/sites/${pin.siteId}'),
      onClose: onClose,
      children: [
        Text(
          l10n.speciesMap_card_loggedHere,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        // While loading, a spinner: the pin already says species were
        // logged here, so "nothing logged" would contradict it.
        if (failed)
          Text(l10n.speciesMap_error_loading)
        else if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (logged.isEmpty)
          Text(l10n.speciesMap_card_nothingLogged)
        else
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final item in logged)
                if (catalog[item.speciesId] case final Species species)
                  _SpeciesChip(
                    species: species,
                    label:
                        '${species.localizedCommonName(l10n)} '
                        '×${item.sightingCount}',
                    onTap: () => openSpecies(species.id),
                  ),
            ],
          ),
        if (expected.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.speciesMap_card_expectedNotLogged,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final entry in expected)
                _ExpectedChip(
                  label:
                      catalog[entry.speciesId]?.localizedCommonName(l10n) ??
                      entry.speciesName,
                  onTap: () => openSpecies(entry.speciesId),
                ),
            ],
          ),
        ],
        if (publicOn) ...[
          const SizedBox(height: 12),
          NearbySpeciesTier(
            siteId: pin.siteId,
            location: GeoPoint(pin.latitude, pin.longitude),
            onSpeciesTap: openSpecies,
          ),
        ],
      ],
    );
  }
}

class _SpeciesChip extends StatelessWidget {
  final Species species;
  final String label;
  final VoidCallback onTap;

  const _SpeciesChip({
    required this.species,
    required this.label,
    required this.onTap,
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
      onPressed: onTap,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

/// Outlined with a hollow dot, matching the hollow expected pins.
class _ExpectedChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExpectedChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: ExcludeSemantics(
        child: Icon(
          Icons.radio_button_unchecked,
          size: 14,
          color: theme.colorScheme.primary,
        ),
      ),
      label: Text(label, style: theme.textTheme.bodySmall),
      onPressed: onTap,
      backgroundColor: theme.colorScheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
