import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The species tagged on a photo, as a wrapping row of chips over the
/// viewer's dark overlay. Tapping a chip opens the species. Renders nothing
/// when the photo has no tags.
class MediaSpeciesChipsRow extends ConsumerWidget {
  final String mediaId;

  const MediaSpeciesChipsRow({super.key, required this.mediaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chips = ref.watch(mediaTagChipsProvider(mediaId)).value ?? const [];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: l10n.media_species_chipsLabel,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final chip in chips)
              ActionChip(
                avatar: ExcludeSemantics(
                  child: Icon(iconForSpeciesCategory(chip.category), size: 16),
                ),
                label: Text(
                  localizedSpeciesName(l10n, chip.speciesId, chip.storedName),
                ),
                onPressed: () => context.push('/species/${chip.speciesId}'),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
