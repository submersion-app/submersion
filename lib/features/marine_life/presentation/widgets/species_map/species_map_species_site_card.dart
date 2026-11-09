import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/domain/entities/species_sighting_record.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_card_frame.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Species mode's card for one pin: the diver's sightings of the picked
/// species at that site, or that the site expects it.
///
/// Reuses the detail page's sightings read ([speciesSightingsProvider]),
/// narrowed to the site, so the two can never disagree.
class SpeciesMapSpeciesSiteCard extends ConsumerWidget {
  final SpeciesSitePin pin;
  final String speciesId;
  final VoidCallback onClose;

  const SpeciesMapSpeciesSiteCard({
    super.key,
    required this.pin,
    required this.speciesId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final records = pin.kind == SpeciesPinKind.logged
        ? [
            for (final record
                in ref.watch(speciesSightingsProvider(speciesId)).value ??
                    const <SpeciesSightingRecord>[])
              if (record.siteId == pin.siteId) record,
          ]
        : const <SpeciesSightingRecord>[];

    return SpeciesMapCardFrame(
      title: pin.siteName,
      subtitle: pin.kind == SpeciesPinKind.logged
          ? l10n.marineLife_speciesPage_sightingsCount(pin.sightingCount)
          : null,
      openTooltip: l10n.speciesMap_card_openSite,
      onOpenTitle: () => context.push('/sites/${pin.siteId}'),
      onClose: onClose,
      children: [
        if (pin.kind == SpeciesPinKind.expected)
          Text(l10n.speciesMap_card_expectedPin)
        else
          for (final record in records)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.scuba_diving),
              title: Text(
                // Placeholder order, not sentence order.
                l10n.speciesMap_card_sightingRow(
                  units.formatDate(record.diveDateTime),
                  record.diveNumber?.toString() ?? '-',
                  record.count,
                ),
              ),
              onTap: () => context.push('/dives/${record.diveId}'),
            ),
      ],
    );
  }
}
